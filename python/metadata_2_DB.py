# 1. Import Libraries
import os
import sqlite3
import requests
import pandas as pd
from sqlalchemy import create_engine

# 2. Define and Create Database Path
db_path = '../data/'
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

# 3. Fetch API Data for Photometer Metadata
photometer_api_url = "http://api.stars4all.eu/photometers"

def fetch_photometer_metadata(api_url):
    response = requests.get(api_url)
    response.raise_for_status()
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

photometer_metadata = fetch_photometer_metadata(photometer_api_url)
print(f"Total rows fetched from API: {len(photometer_metadata)}")

# 4. Map Timezones
wikipedia_url = "https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"

def fetch_timezone_data(wikipedia_url):
    tables = pd.read_html(wikipedia_url, header=[0, 1])  # Fetch all tables with multi-level headers

    for i, table in enumerate(tables):
        if ('TZ identifier' in table.columns.get_level_values(1) and 
            'UTC offset ±hh:mm' in table.columns.get_level_values(0)):
            # Extract the relevant columns
            timezone_data = table[[('TZ identifier', 'TZ identifier'), 
                                   ('UTC offset ±hh:mm', 'SDT')]].copy()
            timezone_data.columns = ['timezone', 'utc_offset']
            
            return timezone_data

    raise ValueError("Expected timezone table not found.")

timezone_data = fetch_timezone_data(wikipedia_url)

def map_timezones(photometer_df, timezone_df):
    def map_timezone(row):
        if not isinstance(row['local_timezone_name'], str) or not row['local_timezone_name']:
            return None  # Skip invalid or missing values
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

column_order = [
    "name", "latitude", "longitude", "country", "city", "place", 
    "local_timezone_name", "local_timezone", "org_name"
]
photometer_metadata = photometer_metadata[column_order]

# 5. Save to SQLite
photometer_metadata.to_sql('TessNetwork_metadata', con=engine, if_exists='replace', index=False)
print(f"Data successfully processed and saved to the database at '{db_name}'.")
