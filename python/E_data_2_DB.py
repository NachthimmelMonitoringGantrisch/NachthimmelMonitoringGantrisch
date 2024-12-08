import os
import re
import pandas as pd
import datetime
from sqlalchemy import create_engine, text
import pytz

def get_timezone_from_ecsv(file_path):
    """
    Reads the timezone information from the meta section of the .ecsv file.
    Extracts the `Local timezone` value.
    """
    with open(file_path, 'r') as f:
        for line in f:
            # Look for the "Local timezone" field in the meta section
            match = re.search(r"Local timezone:\s*([\w/]+)", line)
            if match:
                return match.group(1).strip()
    raise ValueError("Timezone information not found in the meta section of the .ecsv file.")

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

def filter_and_process_data(data, photometer_name, ecsv_file_path):
    """
    Processes data, including dynamic timezone adjustment based on the .ecsv file.
    """

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
    data['time'] = pd.to_datetime(data['time'], utc=True)

    local_timezone = get_timezone_from_ecsv(ecsv_file_path)

    # Adjust times to the extracted local timezone
    if local_timezone not in pytz.all_timezones:
        raise ValueError(f"Invalid timezone: {local_timezone}")
    data['time'] = data['time'].dt.tz_convert(local_timezone).dt.tz_localize(None)

    # Define night start and end times
    night_start_hour = 16  # 16:00
    night_end_hour = 9     # 09:00

    # Assign night ID based on the adjusted night logic
    def calculate_night_id(timestamp):
        if timestamp.hour < night_end_hour:
            # Before 09:00 -> previous night's date
            night_date = (timestamp - pd.Timedelta(days=1)).strftime('%Y%m%d')
        elif timestamp.hour >= night_start_hour:
            # After 16:00 -> current night's date
            night_date = timestamp.strftime('%Y%m%d')
        else:
            # Between 09:00 and 16:00 -> no night ID (daytime data)
            return None
        return f"N{night_date}"

    data['night_id'] = data['time'].apply(calculate_night_id)

    # Filter out daytime data (optional)
    data = data[data['night_id'].notna()]

    # Add astronomical night flag
    data['astronomical_night'] = data['sun_alt'] < -18

    # Calculate cloud coverage
    data['cloud_coverage'] = data.apply(
        lambda row: max(0, min(100, 100 - 3 * (row['enclosure_temperature'] - row['sky_temperature']))),
        axis=1
    )
    print(f"Filtered and processed data for {photometer_name}.")
    return data

def add_data_import_entry(engine, photometer_name, month):
    date_of_data_name = datetime.datetime.strptime(month, "%Y-%m").date().replace(day=1)
    date_of_import = datetime.datetime.now().date()
    next_month = (date_of_data_name.replace(day=1) + datetime.timedelta(days=31)).replace(day=1)
    complete = 1 if date_of_import >= next_month else 0
    command = f"""
    INSERT INTO data_import_control (name, date_of_data_name, date_of_import, complete) 
    VALUES (
        :name,
        :date_of_data_name,
        :date_of_import,
        :complete
    );
    """
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

def delete_incomplete_month_data(engine, photometer_name, month):
    """
    Delete all entries for the specified month in the photometer's data table.
    """
    query = f"""
    DELETE FROM {photometer_name}_data
    WHERE strftime('%Y-%m', time) = :month
    """
    with engine.connect() as connection:
        transaction = connection.begin()
        try:
            connection.execute(text(query), {"month": month})  # Execute deletion
            transaction.commit()
            print(f"Deleted existing data for {photometer_name} in {month}.")
        except Exception as e:
            transaction.rollback()
            print(f"Error deleting data for {photometer_name} in {month}: {e}")

def is_month_incomplete(engine, photometer_name, month):
    """
    Check if a specific month is marked as incomplete (complete = 0) in the data_import_control table.
    """
    query = """
    SELECT complete
    FROM data_import_control
    WHERE name = :photometer_name
    AND strftime('%Y-%m', date_of_data_name) = :month
    LIMIT 1
    """
    with engine.connect() as connection:
        result = connection.execute(text(query), {"photometer_name": photometer_name, "month": month}).fetchone()
        return result is not None and result[0] == 0  # Returns True if incomplete, False otherwise

def process_ecsv_files(ecsv_folder, photometer_names, months_list, db_path):
    if not os.path.exists(ecsv_folder):
        raise FileNotFoundError(f"ECSV folder does not exist: {ecsv_folder}")
    engine = create_engine(f"sqlite:///{db_path}")
    print(f"Database engine initialized for: {db_path}")
    for photometer_name in photometer_names:
        create_table_for_photometer(engine, photometer_name)
        for month in months_list:
            # Check if the month is incomplete before deleting
            if is_month_incomplete(engine, photometer_name, month):
                print(f"Month {month} for photometer {photometer_name} is incomplete. Deleting old data...")
                delete_incomplete_month_data(engine, photometer_name, month)
            else:
                print(f"Month {month} for photometer {photometer_name} is complete. Skipping deletion.")

            # Process and import the new .ecsv file
            file_name = f"{photometer_name}_{month}.ecsv"
            file_path = os.path.join(ecsv_folder, photometer_name, file_name)
            if os.path.exists(file_path):
                print(f"Processing file: {file_path}")
                raw_data = pd.read_csv(file_path, comment='#', delimiter=',')
                processed_data = filter_and_process_data(raw_data, photometer_name, file_path)
                processed_data.to_sql(f'{photometer_name}_data', engine, if_exists='append', index=False)
                print(f"Imported data from {file_name} successfully.")
                add_data_import_entry(engine, photometer_name, month)
            else:
                print(f"File {file_name} not found for photometer {photometer_name} in month {month}.")


