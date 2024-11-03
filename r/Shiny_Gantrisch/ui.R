library(shiny)
library(DT)

# UI-Komponente mit drei Tabs
ui <- navbarPage(
  title = "Photometer Analyse App",
  
  # Tab für Datenbezug
  tabPanel("Datenbezug",
           sidebarLayout(
             sidebarPanel(
               textInput("photometerName", 
                         "Gib den Photometer-Namen ein:", 
                         value = "stars"),
               dateRangeInput("dateRangeFetchData", 
                              "Wähle Datum:"),
               checkboxInput("preprocessing", 
                             "Vorprozessierung", 
                             value = TRUE),
               actionButton("updateData", 
                            "aktualisieren", 
                            icon = NULL, 
                            width = NULL, 
                            disabled = FALSE),
               actionButton("nextPanelToAnalysis", 
                            "weiter zur Auswertung", 
                            icon = NULL, 
                            width = NULL, 
                            disabled = FALSE)
             ),
             mainPanel(
               DTOutput("tablePhotometerDownload")
             )
           )),
  
  # Tab für Photometer-Analyse
  tabPanel("Photometer Analyse",
           sidebarLayout(
             sidebarPanel(
               dateRangeInput("dateRange", "Wähle Datum:")
             ),
             mainPanel(
               plotOutput("plotOutput")  # Platzhalter für einen Beispiel-Plot
             )
           )),
  
  # Tab für Analyse Report
  tabPanel("Analyse Report",
           sidebarLayout(
             sidebarPanel(
               actionButton("exportButton", "Exportiere Report")
             ),
             mainPanel(
               textOutput("reportStatus")  # Platzhalter für den Export-Status
             )
           ))
)
