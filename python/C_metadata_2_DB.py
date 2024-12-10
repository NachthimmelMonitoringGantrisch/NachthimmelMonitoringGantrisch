import os
import sqlite3
import requests
import pandas as pd
from sqlalchemy import create_engine
from time import sleep
import pytz

# Define and Create Database Paths
db_path = '../../data/'
main_db_name = os.path.join(db_path, 'TessNetwork_metadata.db')
backup_db_name = os.path.join(db_path, 'Backup_metadata.db')
os.makedirs(db_path, exist_ok=True)

# Create or Recreate Databases and Tables
def initialize_database(db_name):
    with sqlite3.connect(db_name) as conn:
        conn.execute("DROP TABLE IF EXISTS TessNetwork_metadata;")
        conn.execute("""
        CREATE TABLE TessNetwork_metadata (
            name VARCHAR(255),
            latitude DECIMAL(10, 2),
            longitude DECIMAL(10, 2),
            country VARCHAR(255),
            city VARCHAR(255),
            place VARCHAR(255),
            local_timezone_name VARCHAR(50),
            local_timezone VARCHAR(50),
            org_name VARCHAR(255)
        );
        """)

if not os.path.exists(main_db_name):
    initialize_database(main_db_name)

if not os.path.exists(backup_db_name):
    initialize_database(backup_db_name)

main_engine = create_engine(f'sqlite:///{main_db_name}')
backup_engine = create_engine(f'sqlite:///{backup_db_name}')

# 3. Fetch API Data for Photometer Metadata with Retry Logic
photometer_api_url = "http://api.stars4all.eu/photometers"

def fetch_photometer_metadata(api_url, max_retries=3, backoff_factor=5):
    for attempt in range(1, max_retries + 1):
        try:
            response = requests.get(api_url, timeout=10)
            response.raise_for_status()  # Raise error for non-200 responses
            
            data = response.json()
            
            if not isinstance(data, list):
                raise ValueError("Expected API to return a list of photometer data.")
            
            records = []
            for item in data:
                record = {
                    "name": item.get("name", ""),
                    "latitude": round(item.get("info_location", {}).get("latitude", 0), 4) if item.get("info_location", {}).get("latitude") else None,
                    "longitude": round(item.get("info_location", {}).get("longitude", 0), 4) if item.get("info_location", {}).get("longitude") else None,
                    "country": item.get("info_location", {}).get("country", ""),
                    "city": item.get("info_location", {}).get("town", ""),
                    "place": item.get("info_location", {}).get("place", ""),
                    "local_timezone_name": item.get("info_tess", {}).get("local_timezone", ""),
                    "org_name": item.get("info_org", {}).get("name", ""),
                }
                records.append(record)
                
            df = pd.DataFrame(records)
            return df

        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout):
            print("Internet connection not available, using backup metadata.")
            break  
        except requests.exceptions.RequestException as e:
            print(f"API error: {e}")
            break

    return pd.DataFrame(columns=["name", "latitude", "longitude", "country", "city", "place", "local_timezone_name", "local_timezone", "org_name"])

photometer_metadata = fetch_photometer_metadata(photometer_api_url)
print(f"Total rows fetched from API: {len(photometer_metadata)}")

def map_timezones(photometer_df):
    def map_timezone(row):
        local_timezone_name = row.get('local_timezone_name', "")
        if local_timezone_name in pytz.all_timezones:
            return local_timezone_name
        if "UTC" in local_timezone_name:
            try:
                offset = local_timezone_name.replace("UTC", "").replace("+", "+0").replace("-", "-0")
                if len(offset) == 2:
                    offset += ":00"
                return f"Etc/GMT{offset}" if offset.startswith("-") else f"Etc/GMT+{offset}"
            except Exception:
                return None
        return None

    photometer_df['local_timezone'] = photometer_df.apply(map_timezone, axis=1)
    return photometer_df

photometer_metadata = map_timezones(photometer_metadata)

if not photometer_metadata.empty:
    photometer_metadata.to_sql('TessNetwork_metadata', con=main_engine, if_exists='replace', index=False)

photometer_metadata.to_sql('TessNetwork_metadata', con=backup_engine, if_exists='replace', index=False)
print(f"Data successfully saved to the main and backup databases.")
