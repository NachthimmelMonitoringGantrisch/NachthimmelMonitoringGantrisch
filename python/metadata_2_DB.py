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

# SQL query to create the table if it doesn't exist
create_table_query = '''
CREATE TABLE IF NOT EXISTS TessNetwork_metadata (
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

# Connect to the database and execute the create table query
with engine.connect() as connection:
    connection.execute(text(create_table_query))
    connection.execute(text("DELETE FROM TessNetwork_metadata"))
    print("Table checked/created successfully.")


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

# Clear existing data in the table
with engine.connect() as connection:
    connection.execute(text("DELETE FROM TessNetwork_metadata"))

# Insert new data into SQLite database
df.to_sql('TessNetwork_metadata', con=engine, if_exists='append', index=False)

print("Data cleared and new data inserted successfully!")