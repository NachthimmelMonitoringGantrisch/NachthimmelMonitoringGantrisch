# Verwende das Rocker-Image mit R und Shiny als Basis
FROM rocker/shiny

# Setze das Arbeitsverzeichnis
WORKDIR /srv/shiny-server

# Installiere Python 3 und notwendige System-Abhängigkeiten
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    sqlite3 \
    git

RUN ln -s /bin/python3 /bin/python

# Installiere notwendige R-Pakete
RUN R -e "install.packages(c('shiny', 'ggplot2', 'RSQLite', 'jsonlite', 'reticulate', 'DT', 'dplyr', 'lubridate', 'DBI', 'tidyr', 'gridExtra', 'cowplot', 'patchwork'))"

# Kopiere den gesamten Quellcode (Shiny-App, Python-Skripte und Datenbank)
COPY . /srv/shiny-server/

# Setze die Rechte für den Shiny-Server
RUN chmod -R 755 /srv/shiny-server

# Exponiere den Port 3838 für die Shiny-App
EXPOSE 3838

# CMD: Starte die Shiny-App
CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/r/Shiny_Gantrisch/app.R', host='0.0.0.0', port=3838)"]
