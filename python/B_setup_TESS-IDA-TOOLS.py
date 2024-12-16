import os
import subprocess
import sys

def install_tess():
    """
    Clones the TESS-IDA-TOOLS repository into the correct python folder if it doesn't already exist
    and ensures the jupyter folder exists.
    """
    # Set the target directory for TESS-IDA-TOOLS inside the python folder
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    python_dir = os.path.join(project_root, "python")
    target_dir = os.path.join(python_dir, "TESS-IDA-TOOLS")

    # Ensure the python directory exists
    os.makedirs(python_dir, exist_ok=True)

    # Clone the repository if it doesn't exist
    if not os.path.exists(target_dir):
        print(f"Cloning the TESS-IDA-TOOLS repository into {target_dir}...")
        try:
            subprocess.check_call(["git", "clone", "https://github.com/STARS4ALL/TESS-IDA-TOOLS.git", target_dir])
            print(f"Repository successfully cloned to {target_dir}")
        except subprocess.CalledProcessError as e:
            print(f"Error occurred while cloning repository: {e}")
            return None
    else:
        print(f"Repository already exists at {target_dir}")

    # Ensure the jupyter directory exists
    jupyter_dir = os.path.join(target_dir, "jupyter")
    os.makedirs(jupyter_dir, exist_ok=True)
    print(f"Jupyter folder ensured at {jupyter_dir}")

    return target_dir, jupyter_dir

def create_virtual_env(jupyter_dir):
    """
    Creates a virtual environment inside the jupyter folder if it doesn't already exist.
    """
    venv_path = os.path.join(jupyter_dir, ".venv")
    if not os.path.exists(venv_path):
        print(f"Creating virtual environment in {venv_path}...")
        subprocess.check_call([sys.executable, "-m", "venv", venv_path])
        print(f"Virtual environment created at {venv_path}")
    else:
        print(f"Virtual environment already exists at {venv_path}")
    return venv_path

def install_libraries(venv_path):
    """
    Installs the required libraries into the virtual environment.
    """
    pip_executable = os.path.join(venv_path, "Scripts", "pip.exe" if os.name == "nt" else "bin/pip")

    # List of libraries to install
    packages = [
        "notebook==7.2.2",
        "matplotlib==3.9.2",
        "sqlalchemy",
        "pandas==2.2.3", 
        "numpy==2.1.3",
        "aiohttp==3.9.5",
        "aiodns==3.0.0",
        "git+https://github.com/STARS4ALL/TESS-IDA-TOOLS#main"
    ]

    print("Installing required libraries...")
    for package in packages:
        subprocess.check_call([pip_executable, "install", package])
    print("All libraries installed successfully.")


def setup_tess_directory():
    """
    Ensures the TESS-IDA-TOOLS directory structure exists.
    """
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    python_dir = os.path.join(project_root, "python")
    tess_tools_dir = os.path.join(python_dir, "TESS-IDA-TOOLS")
    jupyter_dir = os.path.join(tess_tools_dir, "jupyter")

    if not os.path.exists(jupyter_dir):
        os.makedirs(jupyter_dir)
        print(f"Directory structure created at: {jupyter_dir}")
    else:
        print(f"Directory structure already exists at: {jupyter_dir}")
    return jupyter_dir

def activate_venv():
    """
    Activates the virtual environment depending on the operating system.
    """
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    jupyter_dir = os.path.join(project_root, "python", "TESS-IDA-TOOLS", "jupyter")
    venv_path_win = os.path.join(jupyter_dir, '.venv', 'Scripts', 'activate.bat')

    if os.name == 'nt':  # For Windows
        if os.path.exists(venv_path_win):
            subprocess.call([venv_path_win], shell=True)
        else:
            print("Windows virtual environment 'activate.bat' script not found!")

def setup_tess():
    """
    Main function to set up the environment, activate it, and install required libraries.
    """
    # Step 1: Ensure the directory structure
    jupyter_dir = setup_tess_directory()

    # Step 2: Create the virtual environment
    venv_path = create_virtual_env(jupyter_dir)

    # Step 3: Install the required libraries
    install_libraries(venv_path)

    # Step 4: Activate the virtual environment
    activate_venv()

def create_env_file(jupyter_dir):
    """
    Creates a .env file with the specified content in the jupyter folder.
    """
    env_content = """
IDA_URL=https://fta-cloud.fis.ucm.es/index.php/s/Gr9DAbfiX8Pdm86
DATABASE_FILE=adm/tessida.db
    """
    env_file_path = os.path.join(jupyter_dir, ".env")

    with open(env_file_path, "w") as f:
        f.write(env_content.strip())
    print(f".env file created at {env_file_path}")

def run_schema_create(jupyter_dir):
    """
    Runs the `tess-ida-db --console schema create` command in the jupyter folder.
    """
    venv_path = os.path.join(jupyter_dir, ".venv", "Scripts")
    tess_ida_db_path = os.path.join(venv_path, "tess-ida-db.exe")

    if not os.path.exists(tess_ida_db_path):
        print(f"Executable tess-ida-db not found at {tess_ida_db_path}")
        return

    command = [tess_ida_db_path, "--console", "schema", "create"]
    env = os.environ.copy()
    env["PATH"] = f"{venv_path};{env['PATH']}"
    env["DATABASE_FILE"] = os.path.join(jupyter_dir, "adm", "tessida.db")

    try:
        subprocess.check_call(command, cwd=jupyter_dir, env=env)
        print("Schema creation completed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error occurred while running the command: {e}")

# Call the functions
target_dir, jupyter_dir = install_tess()  # Step 1: Install repository and get paths
setup_tess()                              # Step 2: Setup directory structure
create_env_file(jupyter_dir)              # Step 3: Create .env file
run_schema_create(jupyter_dir)            # Step 4: Initialize database schema
