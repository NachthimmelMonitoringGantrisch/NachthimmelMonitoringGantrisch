import os
from sqlalchemy import create_engine, text
from datetime import datetime, timedelta

# Configuration
db_name = os.path.abspath(os.path.join(os.getcwd(), '..', '..', 'data', 'TessNetwork_data.db'))

# Ensure the data folder exists
os.makedirs(os.path.dirname(db_name), exist_ok=True)

# SQLite connection
engine = create_engine(f'sqlite:///{db_name}')

def execute_query(query, params=None):
    """
    Execute a SQL query and return results.
    """
    with engine.connect() as connection:
        result = connection.execute(text(query), params or {})
        return result.fetchall()

def execute_command(command, params=None):
    """
    Execute a SQL command without returning results.
    """
    with engine.connect() as connection:
        connection.execute(text(command), params or {})

def create_table():
    """
    Create the `data_import_control` table if it doesn't already exist.
    """
    command = """
    CREATE TABLE IF NOT EXISTS data_import_control (
        name TEXT NOT NULL,
        date_of_data_name TIMESTAMP NOT NULL,
        date_of_import TIMESTAMP NOT NULL,
        complete BOOLEAN NOT NULL
    );
    """
    execute_command(command)
    print("Table `data_import_control` ensured.")

def generate_month_list(photometer_name, start_date, end_date):
    """
    Generate a list of months between two dates (inclusive) in 'YYYY-MM' format,
    excluding months that are already marked as complete in the `data_import_control` table.
    """
    # Convert start_date and end_date to datetime objects
    start = datetime.strptime(start_date, '%Y-%m-%d')
    end = datetime.strptime(end_date, '%Y-%m-%d')

    # Generate a full list of months in 'YYYY-MM' format
    months = []
    current = start
    while current <= end:
        months.append(current.strftime('%Y-%m'))
        current = (current.replace(day=1) + timedelta(days=31)).replace(day=1)  # Move to the next month

    # Query the database for completed months
    query = """
    SELECT strftime('%Y-%m', date_of_data_name) AS month
    FROM data_import_control
    WHERE name = :photometer_name
    AND complete = 1
    """
    completed_months = set(
        row[0] for row in execute_query(query, {"photometer_name": photometer_name})
    )

    # Filter out months that are already completed
    filtered_months = [month for month in months if month not in completed_months]

    return filtered_months

if __name__ == "__main__":
    # Ensure database and table
    print(f"Database path: {db_name}")
    create_table()

    # Example usage
    photometer_name = 'stars926'
    start_date = '2024-01-15'  # Example start date
    end_date = '2024-03-10'    # Example end date

    # Generate the list of months
    months = generate_month_list(photometer_name, start_date, end_date)
    print("Generated months in timespan:")
    print(months)