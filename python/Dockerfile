# Verwende ein schlankes Python-Image
FROM python:3.9-slim

# Setze das Arbeitsverzeichnis
WORKDIR /app

# Installiere Systemabhängigkeiten
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

# Kopiere alle Python-Dateien in das Container-Verzeichnis
COPY python/ /app/python/

# Setze den Pfad der virtuellen Umgebung für den Container (falls erforderlich)
ENV PATH="/app/python/.venv_R/Scripts:$PATH"

# Leg den Container-Befehl fest
CMD ["bash"]
