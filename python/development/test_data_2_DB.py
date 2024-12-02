import os
import re
import pandas as pd
import datetime
from sqlalchemy import create_engine, text

def create_table_for_photometer(engine, photometer_name):
    create_table_query = f'''
    CREATE TABLE IF NOT EXISTS {photometer_name}_data (
        time TIMESTAMP,
        enclosure_temperature DOUBLE PRECISION,
        sky_temperature DOUBLE PRECISION,
        frequency DOUBLE PRECISION,
        msas DOUBLE PRECISION,
        zp DOUBLE PRECISION,
        sequence_number BIGINT,
        sun_alt DOUBLE PRECISION,
        moon_alt DOUBLE PRECISION,
        moon_illumination DOUBLE PRECISION,
        night_id VARCHAR(255),
        astronomical_night BOOLEAN,
        cloud_coverage DOUBLE PRECISION
    );
    '''
    with engine.connect() as connection:
        connection.execute(text(create_table_query))
        print(f"Table {photometer_name}_data ensured in the database.")

def filter_and_process_data(data, photometer_name):
    # Rename columns to match schema
    data.columns = [
        'time',
        'enclosure_temperature',
        'sky_temperature',
        'frequency',
        'msas',
        'zp',
        'sequence_number',
        'sun_alt',
        'moon_alt',
        'moon_illumination'
    ]
    
    # Convert 'time' to datetime and adjust to local timezone
    data['time'] = pd.to_datetime(data['time'], utc=True)
    local_timezone = "Europe/Zurich"
    data['time'] = data['time'].dt.tz_convert(local_timezone).dt.tz_localize(None)
    
    # Add calculated fields
    data['night_id'] = data['time'].apply(lambda x: f"N{x.strftime('%Y%m%d')}")
    data['astronomical_night'] = data['sun_alt'] < -18
    data['cloud_coverage'] = data.apply(
        lambda row: max(0, min(100, 100 - 3 * (row['enclosure_temperature'] - row['sky_temperature']))),
        axis=1
    )
    print(f"Filtered and processed data for {photometer_name}.")
    return data

def add_data_import_entry(engine, photometer_name, month):
    """
    Adds an entry to the data_import_control table after successful import.
    """
    try:
        # Convert month to datetime object and set to the first day of the month
        date_of_data_name = datetime.datetime.strptime(month, "%Y-%m").date().replace(day=1)

        # Current datetime for date_of_import
        date_of_import = datetime.datetime.now().date()

        # Calculate the first day of the next month after date_of_data_name
        next_month = (date_of_data_name.replace(day=1) + datetime.timedelta(days=31)).replace(day=1)

        # Determine if the entry is complete
        complete = 1 if date_of_import >= next_month else 0

        # Log the placeholder values
        print(f"Placeholder values: name={photometer_name}, date_of_data_name={date_of_data_name}, "
              f"date_of_import={date_of_import}, complete={complete}")

        # SQL command to insert into the table
        command = f"""
        INSERT INTO data_import_control (name, date_of_data_name, date_of_import, complete) 
        VALUES (
            :name,
            :date_of_data_name,
            :date_of_import,
            :complete
        );
        """
        # Execute the command with explicit transaction handling
        with engine.connect() as connection:
            transaction = connection.begin()
            try:
                connection.execute(
                    text(command),
                    {
                        "name": photometer_name,
                        "date_of_data_name": date_of_data_name,
                        "date_of_import": date_of_import,
                        "complete": complete
                    }
                )
                transaction.commit()
                print(f"Entry added for {photometer_name} in month {month} to data_import_control.")
            except Exception as e:
                transaction.rollback()
                print(f"Error adding entry to data_import_control for {photometer_name} in month {month}: {e}")

    except Exception as e:
        print(f"Critical error in add_data_import_entry: {e}")

def process_ecsv_files(ecsv_folder, photometer_names, months_list, db_path):
    """
    Processes ECSV files for given photometer names and months, and imports them into the database.
    """
    if not os.path.exists(ecsv_folder):
        raise FileNotFoundError(f"ECSV folder does not exist: {ecsv_folder}")
    
    engine = create_engine(f"sqlite:///{db_path}")
    print(f"Database engine initialized for: {db_path}")
    
    for photometer_name in photometer_names:
        create_table_for_photometer(engine, photometer_name)
        
        for month in months_list:
            file_name = f"{photometer_name}_{month}.ecsv"
            file_path = os.path.join(ecsv_folder, photometer_name, file_name)
            
            if os.path.exists(file_path):
                print(f"Processing file: {file_path}")
                raw_data = pd.read_csv(file_path, comment='#', delimiter=',')
                processed_data = filter_and_process_data(raw_data, photometer_name)
                processed_data.to_sql(f'{photometer_name}_data', engine, if_exists='append', index=False)
                print(f"Imported data from {file_name} successfully.")
                
                # Add entry to data_import_control table
                add_data_import_entry(engine, photometer_name, month)
            else:
                print(f"File {file_name} not found for photometer {photometer_name} in month {month}.")

if __name__ == "__main__":
    # Define relative paths
    base_dir = os.path.dirname(os.path.abspath(__file__))
    ecsv_folder = os.path.join(base_dir, "TESS-IDA-TOOLS", "jupyter", "ECSV")
    db_path = os.path.join(base_dir, "..", "data", "TessNetwork_data.db")
    
    # Define photometers and months
    photometer_names = ['stars926', 'stars928']
    months_list = ["2024-10", "2024-09"]
    
    print(f"ECSV Folder: {ecsv_folder}")
    print(f"Photometer Names: {photometer_names}")
    print(f"Database Path: {db_path}")
    print(f"Months List: {months_list}")
    
    # Process files
    process_ecsv_files(ecsv_folder, photometer_names, months_list, db_path)
