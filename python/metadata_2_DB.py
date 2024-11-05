import pandas as pd
from sqlalchemy import create_engine, text
import requests
import os

# Define the database path
db_name = '../data/TessNetwork_metadata.db'

# Check if the database file exists
if not os.path.isfile(db_name):
    print("Database does not exist. Creating a new one.")
else:
    print("Database already exists.")

# Create the engine regardless, since it will just connect to the existing database
engine = create_engine(f'sqlite:///{db_name}')

# SQL query to drop the table if it exists
drop_table_query = "DROP TABLE IF EXISTS TessNetwork_metadata;"

# SQL query to create the table
create_table_query = '''
CREATE TABLE TessNetwork_metadata (
    name VARCHAR(255),
    latitude DECIMAL(10, 7),
    longitude DECIMAL(10, 7),
    country VARCHAR(255),
    city VARCHAR(255),
    place VARCHAR(255),
    local_timezone VARCHAR(50),
    org_name VARCHAR(255),
    org_web_url VARCHAR(255)
);
'''

# Connect to the database, drop the table, and then create a new one
with engine.connect() as connection:
    # Drop the existing table if it exists
    connection.execute(text(drop_table_query))
    print("Table dropped successfully (if it existed).")
    
    # Create the table
    connection.execute(text(create_table_query))
    print("Table created successfully.")

    # API URL
api_url = "https://api.stars4all.eu/photometers"

# Fetch data from the API
response = requests.get(api_url)
data = response.json()

# Parse data and load it into a list of dictionaries
records = []
for item in data:
    record = {
        "name": item.get("name"),
        "latitude": item.get("latitude"),
        "longitude": item.get("longitude"),
        "country": item.get("country", item.get("info_location", {}).get("country")),
        "city": item.get("city", item.get("info_location", {}).get("town")),
        "place": item.get("place", item.get("info_location", {}).get("place")),
        "local_timezone": item.get("local_timezone", item.get("info_tess", {}).get("local_timezone")),
        "org_name": item.get("info_org", {}).get("name"),
        "org_web_url": item.get("info_org", {}).get("web_url")
    }
    records.append(record)

# Convert to DataFrame
df = pd.DataFrame(records)

# Insert new data into SQLite database
df.to_sql('TessNetwork_metadata', con=engine, if_exists='append', index=False)

print("New data inserted successfully!")