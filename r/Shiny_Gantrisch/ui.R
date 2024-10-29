library(shiny)

# UI-Komponente mit drei Tabs
ui <- navbarPage(
  title = "Photometer Analyse App",
  
  # Tab für Datenbezug
  tabPanel("Datenbezug",
           sidebarLayout(
             sidebarPanel(
               fileInput("fileUpload", "Wähle eine Datei zum Hochladen:", accept = c(".dat"))
             ),
             mainPanel(
               textOutput("dataStatus")  # Platzhalter, um zu zeigen, ob Daten hochgeladen wurden
             )
           )),
  
  # Tab für Photometer-Analyse
  tabPanel("photometer-analyse",
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
