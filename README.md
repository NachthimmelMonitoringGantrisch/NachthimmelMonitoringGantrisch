# Interaktive Webkarte Ballenberg

## Documentation

<a href="https://nachthimmel-monitoring-gantrisch-docs.vercel.app/">Go directly to our Documentation</a>

## Ordnerstruktur

NACHTHIMMELMONITORINGGANTRISCH/
│
├── .idea/                         			# Projekt-Settings (z.B. IDE-spezifische Dateien)
├── data/                          			# Ordner für Roh- und verarbeitete Daten
│
├── python/                        			# Python-Skripte und TESS-IDA-Tools
│   ├── TESS-IDA-TOOLS/            			# TESS-IDA Tools Verzeichnis
│   │   ├── doc/                   			# Dokumentation der TESS-IDA Tools
│   │   ├── jupyter/               			# Jupyter-Notebooks für die Analyse
│   │   └── src/                   			# Quellcode der TESS-IDA Tools
│   │
│   ├── .gitignore                 			# Git Ignore Datei für Python-Ordner
│   ├── get-tess-ida.py            			# Python-Skript für TESS-IDA Datenabfrage
│   ├── justfile                   			# Justfile für Skript-Kommandos
│   ├── LICENSE                    			# Lizenzdatei (stars4all)
│   ├── pyproject.toml             			# Konfigurationsdatei für Python-Paket
│   ├── README_instruction.md      			# README mit Anweisungen für die Installation der TESS-IDA Tools
│   ├── README.md                  			# Haupt-README für das Python-Projekt
│   ├── setup.cfg                  			# Setup-Konfiguration
│   ├── tox.ini                    			# Tox Konfiguration für Tests
│   └── uv.lock                    			# Abhängigkeitsdatei
│
├── r/                             			# Ordner für R-Skripte und Shiny-App
│   ├── Shiny_Gantrisch/           			# Ordner für die R Shiny App Gantrisch
│   │   ├── app.R                  			# Haupt-R Shiny App
│   │   ├── server.R               			# Server-Komponente der Shiny-App
│   │   └── ui.R                   			# UI-Komponente der Shiny-App
│   │
│   └── Dockerfile                 			# Dockerfile für den R Shiny-Container
│
├── docker-compose.yml             			# Docker-Compose Datei zur Verwaltung der Container
├── NachthimmelMonitoringGantrisch.Rproj  	# R Projektdatei
├── README.md                      			# Haupt-README für das Repository
└── .gitignore                     			# Git Ignore Datei für das gesamte Projekt
