# Verwende das Rocker-Image mit R und Shiny
FROM rocker/shiny:latest

# Setze das Arbeitsverzeichnis
WORKDIR /srv/shiny-server

# Kopiere die R Shiny-App-Dateien
COPY r/Shiny_Gantrisch/ /srv/shiny-server/

# Installiere R-Bibliotheken
RUN R -e "install.packages(c('shiny', 'ggplot2', 'RSQLite', 'jsonlite', 'reticulate', 'DT', 'dplyr', 'lubridate', 'DBI', 'tidyr', 'gridExtra', 'cowplot', 'patchwork'))"

# Exponiere den Port 3838
EXPOSE 3838

# Setze den Befehl zum Starten der Shiny-App
CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/app.R', host='0.0.0.0', port=3838)"]
