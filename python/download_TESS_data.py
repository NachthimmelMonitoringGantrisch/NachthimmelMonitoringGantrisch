import os
import subprocess
import sys
from setup_download import generate_month_list, create_input_control_table

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
        subprocess.run(command, cwd=jupyter_dir, env=env, check=True)
        print(f"tess-ida-pipe executed successfully for {photometer_name}, {month}.")
    except subprocess.CalledProcessError as e:
        print(f"Error occurred while running tess-ida-pipe for {photometer_name}, {month}: {e}")
    except FileNotFoundError:
        print("tess-ida-pipe command not found. Ensure tess-ida-pipe is installed correctly.")

if __name__ == "__main__":
    # Get input from command-line arguments
    photometer_names = sys.argv[1].split(",")  # Comma-separated list of photometers
    start_date = sys.argv[2]  # Start date in "YYYY-MM-DD" format
    end_date = sys.argv[3]    # End date in "YYYY-MM-DD" format

    # Ensure the database and table exist
    print("Ensuring database and table...")
    create_input_control_table()

    # Set the directory to the jupyter folder
    script_dir = os.path.abspath(os.path.dirname(__file__))
    jupyter_dir = os.path.join(script_dir, "TESS-IDA-TOOLS", "jupyter")

    # Generate filtered months for each photometer
    for photometer_name in photometer_names:
        print(f"Generating month list for photometer: {photometer_name}")
        filtered_months = generate_month_list(photometer_name, start_date, end_date)

        # Iterate through each month for the current photometer
        for month in filtered_months:
            run_tess_ida_pipe(jupyter_dir, photometer_name, month)
