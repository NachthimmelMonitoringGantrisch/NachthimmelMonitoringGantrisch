import os
import subprocess
import sys


def library_installed(pip_executable, library):
    """
    Check if a library is already installed in the virtual environment.
    """
    try:
        result = subprocess.run(
            [pip_executable, "show", library],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return result.returncode == 0
    except Exception as e:
        print(f"Error checking library {library}: {e}")
        return False


def create_and_setup_venv(requirements_file):
    # Define the root directory and the virtual environment directory
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))  # Root folder
    venv_dir = os.path.join(root_dir, ".venv_R")  # Path to .venv_R in root

    # Check if the virtual environment already exists
    if not os.path.exists(venv_dir):
        print(f"Virtual environment '{venv_dir}' not found. Creating...")

        # Create the virtual environment
        subprocess.run([sys.executable, "-m", "venv", venv_dir], check=True)
        print("Virtual environment created successfully.")
    else:
        print(f"Virtual environment '{venv_dir}' already exists. Skipping creation.")

    # Construct the pip executable path within the virtual environment
    pip_executable = os.path.join(venv_dir, "Scripts", "pip") if os.name == "nt" else os.path.join(venv_dir, "bin", "pip")

    # Install only missing libraries from the requirements file
    if os.path.exists(requirements_file):
        print(f"Checking and installing required libraries from {requirements_file}...")
        with open(requirements_file, "r") as file:
            libraries = [line.strip() for line in file if line.strip() and not line.startswith("#")]

        for library in libraries:
            if library_installed(pip_executable, library):
                print(f"Library '{library}' is already installed. Skipping.")
            else:
                print(f"Installing '{library}'...")
                subprocess.run([pip_executable, "install", library], check=True)

        print("Library installation process completed.")
    else:
        print(f"Requirements file '{requirements_file}' not found. Please provide a valid path.")


if __name__ == "__main__":
    # Get the relative path to the requirements file
    requirements_file = os.path.abspath(os.path.join(os.path.dirname(__file__), "requirements", "requirements_venv_R.txt"))

    try:
        create_and_setup_venv(requirements_file)
    except subprocess.CalledProcessError as e:
        print(f"An error occurred: {e}")
        sys.exit(1)
