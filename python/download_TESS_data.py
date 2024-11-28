import os
import subprocess
import asyncio
from asyncio import events

# Ensure the correct event loop is used on Windows
if os.name == 'nt' and not isinstance(asyncio.get_event_loop_policy(), asyncio.WindowsSelectorEventLoopPolicy):
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

def activate_venv(jupyter_dir):
    """
    Activates the virtual environment in the jupyter directory.
    """
    venv_path = os.path.join(jupyter_dir, ".venv", "Scripts", "activate.bat")

    if not os.path.exists(venv_path):
        print(f"Virtual environment activation script not found at {venv_path}. Ensure the environment exists.")
        return

    try:
        print(f"Activating virtual environment at {venv_path}...")
        subprocess.call(venv_path, shell=True)
        print("Virtual environment activated.")
    except Exception as e:
        print(f"Error activating virtual environment: {e}")

def run_tess_ida_pipe(jupyter_dir):
    """
    Runs the tess-ida-pipe command to download data, ensuring the virtual environment is active.
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
        "--name", "stars926",
        "--month", "2024-03"
    ]
    print(f"Running command: {command}")

    # Set up the environment variables
    env = os.environ.copy()
    env["PATH"] = f"{venv_path};{env['PATH']}"
    env["AIODNS_RESOLVER"] = "default"  # Force default resolver

    try:
        # Run the command
        subprocess.run(command, cwd=jupyter_dir, env=env, check=True)
        print("tess-ida-pipe executed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error occurred while running tess-ida-pipe: {e}")
    except FileNotFoundError:
        print("tess-ida-pipe command not found. Ensure tess-ida-pipe is installed correctly.")

if __name__ == "__main__":
    # Set the directory to the jupyter folder
    script_dir = os.path.abspath(os.path.dirname(__file__))
    jupyter_dir = os.path.join(script_dir, "TESS-IDA-TOOLS", "jupyter")

    # Run the tess-ida-pipe command
    run_tess_ida_pipe(jupyter_dir)
