import os
import subprocess
from setup_download import generate_month_list, create_table

def activate_venv(jupyter_dir):
    """
    Activates the virtual environment in the jupyter directory.
    Returns the path to the Python executable if successful.
    """
    venv_python = os.path.join(jupyter_dir, ".venv", "Scripts", "python.exe")

    try:
        if not os.path.exists(venv_python):
            raise FileNotFoundError(
                f"Python executable not found in virtual environment at: {venv_python}. "
                "Ensure the environment is set up correctly."
            )

        print(f"Virtual environment Python executable located at: {venv_python}")
        return venv_python
    except FileNotFoundError as e:
        print(f"Error: {e}")
        raise
    except Exception as e:
        print(f"Unexpected error during virtual environment activation: {e}")
        raise


def run_tess_ida_pipe(jupyter_dir, photometer_name, month):
    """
    Runs the tess-ida-pipe command to download data for a specific photometer and month.
    """
    venv_python = activate_venv(jupyter_dir)
    tess_ida_pipe_path = os.path.join(jupyter_dir, ".venv", "Scripts", "tess-ida-pipe.exe")

    if not os.path.exists(tess_ida_pipe_path):
        raise FileNotFoundError(f"tess-ida-pipe executable not found at: {tess_ida_pipe_path}. Ensure the tool is installed.")

    command = [
        tess_ida_pipe_path,
        "--console", "single",
        "--in-dir", "IDA",
        "--out-dir", "ECSV",
        "--name", photometer_name,
        "--month", month,
    ]
    print(f"Preparing to run command for photometer '{photometer_name}' in month '{month}':")
    print(f"Command: {command}")

    # Set up the environment variables
    env = os.environ.copy()
    env["PATH"] = f"{os.path.dirname(venv_python)};{env['PATH']}"
    env["AIODNS_RESOLVER"] = "default"  # Force default resolver

    try:
        # Run the command
        subprocess.run(command, cwd=jupyter_dir, env=env, check=True)
        print(f"tess-ida-pipe executed successfully for {photometer_name} in {month}.")
    except subprocess.CalledProcessError as e:
        print(f"Error while running tess-ida-pipe for {photometer_name} in {month}: {e}")
    except Exception as e:
        print(f"Unexpected error during tess-ida-pipe execution for {photometer_name} in {month}: {e}")


if __name__ == "__main__":
    # Input data
    photometer_names = ["stars926", "stars927"]  # List of photometers
    start_date = "2024-01-12"  # Start date in "YYYY-MM-DD" format
    end_date = "2024-03-24"    # End date in "YYYY-MM-DD" format

    # Ensure the database and table exist
    try:
        print("Ensuring database and table...")
        create_table()
        print("Database and table setup complete.")
    except Exception as e:
        print(f"Error ensuring database and table: {e}")
        exit(1)

    # Set the directory to the jupyter folder
    script_dir = os.path.abspath(os.path.dirname(__file__))
    jupyter_dir = os.path.join(script_dir, "TESS-IDA-TOOLS", "jupyter")

    if not os.path.exists(jupyter_dir):
        print(f"Error: Jupyter directory not found at: {jupyter_dir}")
        exit(1)

    # Summary logs
    successful_downloads = []
    failed_downloads = []

    # Generate filtered months for each photometer
    for photometer_name in photometer_names:
        try:
            print(f"Generating month list for photometer: {photometer_name}")
            filtered_months = generate_month_list(photometer_name, start_date, end_date)
            if not filtered_months:
                print(f"No months to process for photometer '{photometer_name}' in the given date range.")
                continue

            # Iterate through each month for the current photometer
            for month in filtered_months:
                try:
                    run_tess_ida_pipe(jupyter_dir, photometer_name, month)
                    successful_downloads.append((photometer_name, month))
                except Exception as e:
                    print(f"Error processing photometer '{photometer_name}' for month '{month}': {e}")
                    failed_downloads.append((photometer_name, month))
        except Exception as e:
            print(f"Error generating month list for photometer '{photometer_name}': {e}")

    # Print summary logs
    print("\nDownload Summary:")
    print("Successful downloads:")
    for photometer, month in successful_downloads:
        print(f"  Photometer: {photometer}, Month: {month}")

    print("\nFailed downloads:")
    for photometer, month in failed_downloads:
        print(f"  Photometer: {photometer}, Month: {month}")

    print("All processing completed.")
