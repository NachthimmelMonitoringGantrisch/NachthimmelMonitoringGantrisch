library(shiny)

# UI-Elemente für die Shiny-App
ui <- fluidPage(
  titlePanel("Photometer Daten Analyse"),
  
  sidebarLayout(
    sidebarPanel(
      # Kompakteres Layout: Die Eingabefelder werden untereinander angeordnet
      tags$div(
        style = "display: flex; flex-direction: column; gap: 10px;",
        dateRangeInput("dateRange", "Wähle Datum:", 
                       start = Sys.Date() - 30,  # Standardwert für Startdatum (letzte 30 Tage)
                       end = Sys.Date())  # Aktuelles Datum als Enddatum
      )
    ),
    
    mainPanel(
      # Grafikbereich wird in der Höhe gestreckt
      plotOutput("magnitudePlot", height = "700px")  # Erhöht die Höhe des Plots
    )
  )
)
