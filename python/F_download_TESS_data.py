import os
import subprocess
import sys
from D_setup_download import generate_month_list, create_input_control_table
from E_data_2_DB import process_ecsv_files

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
    Captures errors and warnings to return them for further handling.
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
        # Run the tess-ida-pipe command
        result = subprocess.run(command, cwd=jupyter_dir, env=env, capture_output=True, text=True, check=True)
        print(f"TESS-IDA-Pipe erfolgreich ausgeführt für {photometer_name}, {month}.")
    except subprocess.CalledProcessError as e:
        error_output = e.stderr or e.stdout
        print(f"Error occurred for {photometer_name}, {month}: {error_output}")
        
        if "No monthly file exists" in error_output:
            return f"Monat {month} von {photometer_name} ist nicht verfügbar."
        
        if "Cannot connect to host" in error_output:
            return "Keine Internetverbindung vorhanden."
        
        return "Unbekannter Fehler aufgetreten."

    # Check if the expected .ecsv file exists
    ecsv_folder = os.path.join(jupyter_dir, "ECSV", photometer_name)
    ecsv_file_path = os.path.join(ecsv_folder, f"{photometer_name}_{month}.ecsv")

    if not os.path.exists(ecsv_file_path):
        print(f"Datei {photometer_name}_{month}.ecsv nicht gefunden in {ecsv_folder}.")
        return f"Monat {month} von {photometer_name} ist nicht verfügbar."
    
    # File exists, no error
    print(f"Datei {ecsv_file_path} gefunden.")
    return None

if __name__ == "__main__":
    photometer_names = sys.argv[1].split(",")
    start_date = sys.argv[2]
    end_date = sys.argv[3]

    script_dir = os.path.abspath(os.path.dirname(__file__))
    jupyter_dir = os.path.join(script_dir, "TESS-IDA-TOOLS", "jupyter")

    print("Ensuring database and table...")
    create_input_control_table()

    print(f"Generating month list for photometers: {photometer_names}")
    filtered_months = generate_month_list(photometer_names, start_date, end_date)
    print(f"Months to process: {filtered_months}")

    errors = []  # Collect errors for each photometer and month
    for photometer_name in photometer_names:
        for month in filtered_months:
            result = run_tess_ida_pipe(jupyter_dir, photometer_name, month)
            if result:  # If an error or warning was returned
                errors.append(result)  # Store the error
            else:
                print(f"Download für {photometer_name} im Monat {month} abgeschlossen.")  # Success for this month

    ecsv_folder = os.path.join(jupyter_dir, "ECSV")
    relative_db_path = os.path.join(script_dir, "..", "data", "TessNetwork_data.db")
    absolute_db_path = os.path.abspath(relative_db_path)

    print(f"ECSV Folder: {ecsv_folder}")
    print(f"Database Path: {absolute_db_path}")
    process_ecsv_files(ecsv_folder, photometer_names, filtered_months, absolute_db_path)

    if errors:
        print("Zusammenfassung der Warnungen/Fehler:")
        for error in errors:
            print(error)
    else:
        print("Download aller Dateien erfolgreich abgeschlossen.")


