import os
import subprocess
import asyncio
from setup_download import generate_month_list, create_table  # Import necessary functions
from asyncio import events

# Ensure the correct event loop is used on Windows
if os.name == 'nt' and not isinstance(asyncio.get_event_loop_policy(), asyncio.WindowsSelectorEventLoopPolicy):
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

def activate_venv(jupyter_dir):
    """
    Activates the virtual environment in the jupyter directory.
    """
    venv_path = os.path.join(jupyter_dir, ".venv", "Scripts", "python.exe")

    if not os.path.exists(venv_path):
        print(f"Virtual environment activation script not found at {venv_path}. Ensure the environment exists.")
        return

    try:
        print(f"Activating virtual environment at {venv_path}...")
        subprocess.call(venv_path, shell=True)
        print("Virtual environment activated.")
    except Exception as e:
        print(f"Error activating virtual environment: {e}")

def run_tess_ida_pipe(jupyter_dir, photometer_name, month):
    """
    Runs the tess-ida-pipe command to download data for a specific photometer and month.
    """
    # Activate the virtual environment
    activate_venv(jupyter_dir)

    venv_path = os.path.join(jupyter_dir, ".venv", "Scripts")
    tess_ida_pipe_path = os.path.join(venv_path, "tess-ida-pipe.exe")

    # Ensure tess-ida-pipe exists
    if not os.path.exists(tess_ida_pipe_path):
        print(f"tess-ida-pipe executable not found at {tess_ida_pipe_path}")
        return

    # Command to execute
    command = [
        tess_ida_pipe_path,
        "--console", "single",
        "--in-dir", "IDA",
        "--out-dir", "ECSV",
        "--name", photometer_name,
        "--month", month
    ]
    print(f"Running command for photometer: {photometer_name}, month: {month}")
    print(f"Command: {command}")

    # Set up the environment variables
    env = os.environ.copy()
    env["PATH"] = f"{venv_path};{env['PATH']}"
    env["AIODNS_RESOLVER"] = "default"  # Force default resolver

    try:
        # Run the command
        subprocess.run(command, cwd=jupyter_dir, env=env, check=True)
        print(f"tess-ida-pipe executed successfully for {photometer_name}, {month}.")
    except subprocess.CalledProcessError as e:
        print(f"Error occurred while running tess-ida-pipe for {photometer_name}, {month}: {e}")
    except FileNotFoundError:
        print("tess-ida-pipe command not found. Ensure tess-ida-pipe is installed correctly.")

if __name__ == "__main__":
    # Input data
    photometer_names = ["stars926", "stars927"]  # List of photometers
    start_date = "2024-01-12"  # Start date in "YYYY-MM" format
    end_date = "2024-03-24"    # End date in "YYYY-MM" format

    # Ensure the database and table exist
    print("Ensuring database and table...")
    create_table()

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
