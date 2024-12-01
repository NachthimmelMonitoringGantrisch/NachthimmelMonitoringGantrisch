import os
import subprocess
import sys
from setup_download import generate_month_list, create_input_control_table
from data_2_DB import process_ecsv_files

def activate_venv(jupyter_dir):
    """
    Activates the virtual environment in the jupyter directory.
    Returns the path to the Python executable if successful.
    """
    venv_python = os.path.join(jupyter_dir, ".venv", "Scripts", "python.exe")

    if not os.path.exists(venv_python):
        raise FileNotFoundError(
            f"Python executable not found in virtual environment at: {venv_python}. "
            "Ensure the environment is set up correctly."
        )
    return venv_python

def run_tess_ida_pipe(jupyter_dir, photometer_name, month):
    """
    Runs the tess-ida-pipe command to download data for a specific photometer and month.
    Returns error or warning messages, if any.
    """
    venv_python = activate_venv(jupyter_dir)
    tess_ida_pipe_path = os.path.join(jupyter_dir, ".venv", "Scripts", "tess-ida-pipe.exe")

    if not os.path.exists(tess_ida_pipe_path):
        raise FileNotFoundError(f"tess-ida-pipe executable not found at {tess_ida_pipe_path}.")

    command = [
        tess_ida_pipe_path,
        "--console", "single",
        "--in-dir", "IDA",
        "--out-dir", "ECSV",
        "--name", photometer_name,
        "--month", month,
    ]
    print(f"Running command for photometer: {photometer_name}, month: {month}")
    print(f"Command: {command}")

    env = os.environ.copy()
    env["PATH"] = f"{os.path.dirname(venv_python)};{env['PATH']}"
    env["AIODNS_RESOLVER"] = "default"

    try:
        result = subprocess.run(command, cwd=jupyter_dir, env=env, capture_output=True, text=True, check=True)
        print(f"tess-ida-pipe executed successfully for {photometer_name}, {month}.")
        return None  # No errors
    except subprocess.CalledProcessError as e:
        error_output = e.stderr or e.stdout
        print(f"Error occurred for {photometer_name}, {month}: {error_output}")
        return error_output  # Return error details

if __name__ == "__main__":
     # Get input from command-line arguments
    photometer_names = sys.argv[1].split(",")  # Comma-separated list of photometers
    start_date = sys.argv[2]  # Start date in "YYYY-MM-DD" format
    end_date = sys.argv[3]    # End date in "YYYY-MM-DD" format

    # Set the directory relative to the script's location
    script_dir = os.path.abspath(os.path.dirname(__file__))
    jupyter_dir = os.path.join(script_dir, "TESS-IDA-TOOLS", "jupyter")

    # Ensure the database and table exist
    print("Ensuring database and table...")
    create_input_control_table()

    # Generate filtered months for all photometers
    print(f"Generating month list for photometers: {photometer_names}")
    filtered_months = generate_month_list(photometer_names, start_date, end_date)
    print(f"Months to process: {filtered_months}")

    # Iterate through each photometer and its months
    for photometer_name in photometer_names:
        for month in filtered_months:
            run_tess_ida_pipe(jupyter_dir, photometer_name, month)

    # Process and import data into SQLite database
    ecsv_folder = os.path.join(jupyter_dir, "ECSV")
    relative_db_path = os.path.join(script_dir, "..", "data", "TessNetwork_data.db")
    absolute_db_path = os.path.abspath(relative_db_path)

    print(f"ECSV Folder: {ecsv_folder}")
    print(f"Database Path: {absolute_db_path}")

    process_ecsv_files(ecsv_folder, photometer_names, filtered_months, absolute_db_path)


