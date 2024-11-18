# TESS-IDA-TOOLS

Collection of utilities to download and analyze TESS Photometer Network data from IDA files.

_If all that you need is simply to download IDA monthly files from our NextCloud Server, our
simple [get-tess-ida.py](doc/get-tess-ida.md) script is all that you need. Read no further._

# Summary

- [Installation and configuration](doc/install.md).
- [Avaliable utilities](doc/utilities.md)
- [Usage example](doc/example.md)
- [The IDA monthly files](doc/IDA.md).
- [The auxiliar database](doc/auxiliar.md)

Instruction with ChatGPT
Fabian 10.10.2024

# TESS-IDA Command Instructions

## Step -1: Clone Repo

```bash
git clone git@github.com:STARS4ALL/TESS-IDA-TOOLS.git
git clone https://github.com/STARS4ALL/TESS-IDA-TOOLS.git
```

```bash
cd TESS-IDA-TOOLS
```

## Step 0: Create Virtual Environment

```bash
mkdir jupyter
cd jupyter
python3 -m venv .venv
```

## Step 1: Activate the Virtual Environment

```bash
Linux: source .venv/Scripts/activate
Windows: .venv\Scripts\activate
```

## Step 1: Install the following modules

`aiohttp` must be installed because of the error `aiodns needs a SelectorEventLoop on Windows`. This is the recommended [solution](https://github.com/nathom/streamrip/issues/729), which installs `aiohttp` at a specific version. That works for me.

```bash
    pip install -U pip #maybe not necessary
    pip install notebook matplotlib
    pip install git+https://github.com/STARS4ALL/TESS-IDA-TOOLS#main
    pip install aiodns
    pip install aiohttp==3.9.5
    pip install importlib_resources
    pip install pandas psycopg2 sqlalchemy
```

## Step 1: Configure TESS-IDA-TOOLS

Create a .env File

```txt
IDA_URL=https://fta-cloud.fis.ucm.es/index.php/s/Gr9DAbfiX8Pdm86
DATABASE_FILE=adm/tessida.db
```

## Step 1: Initialize the database

```bash
tess-ida-db --console schema create
```

## Step 1: Download data

Download a single IDA monthly file `stars289_2022-03.dat` and convert into an ECSV file using the pipleline tool

```bash
tess-ida-pipe --console single --in-dir IDA --out-dir ECSV --name stars926 --month 2024-03
```

If no such File exists: [WARNING] [download] [stars926] No monthly file exits: stars926_2022-03.dat
If there is no internet connection: [CRITICAL] [root] [tess.ida.pipeline] Fatal error => Cannot connect to host fta-cloud.fis.ucm.es:443 ssl:default [getaddrinfo failed]

Download IDA monthly files in between a range and convert into ECSV file using the pipleline tool

```bash
tess-ida-pipe --console range --in-dir IDA --out-dir ECSV --name stars926 --since 2023-10 --until 2024-09
tess-ida-pipe --console range --in-dir IDA --out-dir ECSV --name stars930 --since 2023-10 --until 2024-09
tess-ida-pipe --console range --in-dir IDA --out-dir ECSV --name stars927 --since 2023-05 --until 2024-09
```

# Step DB import

import_DB.ipynb
