library(shiny)
library(DT)

# UI-Komponente mit drei Tabs
ui <- navbarPage(
  title = "Photometer Analyse App",
  
  # Link to the CSS file
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")
  ),
  
  # Tab für Datenbezug
  tabPanel("Datenbezug",
           fillPage(
             sidebarLayout(
               sidebarPanel(
                 dateRangeInput("dateRangeFetchData", 
                                "Wähle die Zeitspanne für den Download:"),
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
                              disabled = FALSE),
                 actionButton("downloadData", 
                              "Daten herunterladen", 
                              icon = NULL, 
                              width = NULL, 
                              disabled = FALSE)
               ),
               mainPanel(
                 DTOutput("tablePhotometerDownload", height = "100%")
               )
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
