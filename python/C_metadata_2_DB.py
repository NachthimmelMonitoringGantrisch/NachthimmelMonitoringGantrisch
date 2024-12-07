# 1. Import Libraries
import os
import sqlite3
import requests
import pandas as pd
from sqlalchemy import create_engine
from time import sleep

# 2. Define and Create Database Path
db_path = '../../data/'
db_name = os.path.join(db_path, 'TessNetwork_metadata.db')
os.makedirs(db_path, exist_ok=True)

# Create or Recreate Database and Table
if not os.path.exists(db_name):
    with sqlite3.connect(db_name) as conn:
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
else:
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

engine = create_engine(f'sqlite:///{db_name}')

# 3. Fetch API Data for Photometer Metadata with Retry Logic
photometer_api_url = "http://api.stars4all.eu/photometers"

def fetch_photometer_metadata(api_url, max_retries=3, backoff_factor=5):
    """
    Fetches photometer metadata from the API with retry logic.
    If there is no internet, the function will still continue to process but will notify the user.
    """
    for attempt in range(1, max_retries + 1):
        try:
            # Attempt to fetch the photometer data
            response = requests.get(api_url, timeout=10)  # Add a timeout to avoid hanging
            response.raise_for_status()  # Raise an exception for HTTP errors (e.g., 404, 500)
            
            # Parse the response if successful
            data = response.json()
            
            if not isinstance(data, list):
                raise ValueError("Expected API to return a list of photometer data.")

            # Process records
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

        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as e:
            print("Internetverbindung nicht vorhanden, Metadatentabelle ist nicht aktuell.")
            break  # No internet, stop retrying
        except requests.exceptions.RequestException as e:
            print(f"HTTP error: {e}")
            if attempt < max_retries:
                sleep_time = backoff_factor * attempt
                print(f"Retrying in {sleep_time} seconds...")
                sleep(sleep_time)
            else:
                raise RuntimeError("Maximum retries reached. Unable to fetch data.") from e

    # Return an empty DataFrame if no data could be fetched
    return pd.DataFrame(columns=["name", "latitude", "longitude", "country", "city", "place", "local_timezone_name", "local_timezone", "org_name"])

photometer_metadata = fetch_photometer_metadata(photometer_api_url)
print(f"Total rows fetched from API: {len(photometer_metadata)}")

# 4. Fetch and Map Timezones
wikipedia_url = "https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"

def fetch_timezone_data(wikipedia_url):
    try:
        tables = pd.read_html(wikipedia_url, header=[0, 1])  # Fetch all tables with multi-level headers
        for table in tables:
            if ('TZ identifier' in table.columns.get_level_values(1) and 
                'UTC offset ±hh:mm' in table.columns.get_level_values(0)):
                timezone_data = table[[('TZ identifier', 'TZ identifier'), 
                                       ('UTC offset ±hh:mm', 'SDT')]].copy()
                timezone_data.columns = ['timezone', 'utc_offset']
                return timezone_data
    except Exception as e:
        print("Internetverbindung nicht vorhanden, Zeitzonen konnten nicht aktualisiert werden.")
    return pd.DataFrame(columns=['timezone', 'utc_offset'])

timezone_data = fetch_timezone_data(wikipedia_url)

def map_timezones(photometer_df, timezone_df):
    def map_timezone(row):
        if not isinstance(row['local_timezone_name'], str) or not row['local_timezone_name']:
            return None
        if row['local_timezone_name'] in timezone_df['timezone'].values:
            return timezone_df.loc[timezone_df['timezone'] == row['local_timezone_name'], 'utc_offset'].values[0]
        if "UTC" in row['local_timezone_name']:
            try:
                offset = row['local_timezone_name'].replace("UTC", "").replace("+", "+0").replace("-", "-0")
                if len(offset) == 2:
                    offset += ":00"
                return offset
            except Exception:
                return None
        return None

    photometer_df['local_timezone'] = photometer_df.apply(map_timezone, axis=1)
    return photometer_df

photometer_metadata = map_timezones(photometer_metadata, timezone_data)

# 5. Save to SQLite
photometer_metadata.to_sql('TessNetwork_metadata', con=engine, if_exists='replace', index=False)
print(f"Data successfully processed and saved to the database at '{db_name}'.")
