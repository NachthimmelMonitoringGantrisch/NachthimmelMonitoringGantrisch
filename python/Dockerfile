# Dockerfile für TESS-IDA-TOOLS mit virtueller Umgebung

# Verwende ein schlankes Python-Image
FROM python:3.9-slim

# Setze das Arbeitsverzeichnis auf /app
WORKDIR /app

# Installiere Systemabhängigkeiten
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

# Klone das TESS-IDA-TOOLS-Repository
RUN git clone https://github.com/STARS4ALL/TESS-IDA-TOOLS.git

# Wechsel in das Repository-Verzeichnis
WORKDIR /app/TESS-IDA-TOOLS

# Erstelle das Jupyter-Verzeichnis und richte eine virtuelle Umgebung ein
RUN mkdir jupyter && \
    python3 -m venv jupyter/.venv

# Installiere Abhängigkeiten innerhalb der virtuellen Umgebung
RUN . jupyter/.venv/bin/activate && \
    pip install -U pip && \
    pip install notebook matplotlib && \
    pip install git+https://github.com/STARS4ALL/TESS-IDA-TOOLS#main && \
    pip install aiodns aiohttp==3.9.5 importlib_resources pandas psycopg2 sqlalchemy

# Füge Umgebungsvariablen für die Konfiguration hinzu
ENV IDA_URL="https://fta-cloud.fis.ucm.es/index.php/s/Gr9DAbfiX8Pdm86" \
    DATABASE_FILE="adm/tessida.db" \
    PATH="/app/jupyter/.venv/bin:$PATH"

# Kopiere die .env-Datei für die Konfiguration (falls erforderlich, sonst generiere sie manuell)
COPY .env /app/TESS-IDA-TOOLS/.env

# Führe den Initialisierungsbefehl für die Datenbank aus
RUN . jupyter/.venv/bin/activate && \
    tess-ida-db --console schema create

# Setze den Befehl zum Starten eines Jupyter Notebooks oder Ausführen eines spezifischen TESS-IDA-TOOLS Befehls
CMD ["tess-ida-pipe", "--console", "single", "--in-dir", "IDA", "--out-dir", "ECSV", "--name", "stars926", "--month", "2024-03"]
