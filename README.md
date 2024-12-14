# Naturpark Gantrisch: Analyse, Automatisierung und Visualisierung von Nachthimmelmonitoring

## Dokumentation

<a href="https://nachthimmel-monitoring-gantrisch-docs.vercel.app/">Go directly to the Documentation</a>

## Ordnerstruktur

NachthimmelMonitoringGantrisch
├── .venv_R
│   ├── Include
│   ├── Lib
│   ├── Scripts
│   └── pyvenv.cfg
│
├── data
│   ├── Backup_metadata.db
│   ├── TessNetwork_data.db
│   └── TessNetwork_metadata.db
│
├── python
│   ├── development
│   ├── requirements
│   ├── TESS-IDA-TOOLS
│   │   ├── doc
│   │   ├── jupyter
│   │   │   ├── .venv
│   │   │   ├── adm
│   │   │   ├── ECSV
│   │   │   ├── IDA
│   │   │   └── .env
│   │   │
│   │   ├── src
│   │   ├── .gitignore
│   │   ├── get-tess-ida.py
│   │   ├── justfile
│   │   ├── LICENSE
│   │   ├── pyproject.toml
│   │   ├── README.md
│   │   ├── setup.cfg
│   │   ├── tox.ini
│   │   └── uv.lock
│   │
│   ├── __pycache__
│   ├── Dockerfile
│   ├── A_setup_venv_R.py
│   ├── B_setup_TESS-IDA-TOOLS.py
│   ├── C_metadata_2_DB.py
│   ├── D_setup_download.py
│   ├── E_data_2_DB.py
│   └── F_download_TESS_data.py
│
├── r
│   ├── Shiny_Gantrisch
│   │   ├── www
│   │   ├── app.R
│   │   ├── Histogram_over21perMonth_yearly.R
│   │   ├── MinMaxMSAS_DarkTimeMoon_perMonth.R
│   │   ├── MSAS_Werte_nachtPerMonat_skyTemperature.R
│   │   ├── PhotometerStatistics_overYears.R
│   │   ├── server.R
│   │   └── ui.R
│   │
│   └── Dockerfile
│
├── .gitignore
├── docker-compose.yml
├── NachthimmelMonitoringGantrisch.Rproj
├── README.md
├── README_Install_TESS-IDA-TOOLS.md
├── README_R_Shiny.md
└── README_venv_R.md

