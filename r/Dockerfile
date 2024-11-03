# Verwende ein Basis-Image mit R und Shiny
FROM rocker/shiny:latest

# Setze das Arbeitsverzeichnis
WORKDIR /srv/shiny-server

# Kopiere die Shiny-App-Dateien in das Container-Verzeichnis
COPY Shiny_Gantrisch/ .

# Installiere benötigte R-Pakete
RUN R -e "install.packages(c('shiny', 'ggplot2', 'RSQLite', 'reticulate'))"

# Exponiere den Port
EXPOSE 3838

# Starte die Shiny-App
CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/app.R', host='0.0.0.0', port=3838)"]
