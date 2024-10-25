library(shiny)

# Laden der UI und Server-Logik
source("ui.R")
source("server.R")

# Start der Shiny-App
shinyApp(ui = ui, server = server)
