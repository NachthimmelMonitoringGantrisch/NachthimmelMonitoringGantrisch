library(shiny)


# UI-Komponente mit drei Tabs
ui <- navbarPage(
  title = "Photometer Analyse App",
  
  # Tab für Datenbezug
  tabPanel("Datenbezug",
           sidebarLayout(
             sidebarPanel(
               # Eingabefeld für den Photometer-Namen
               textInput("photometerName", "Gib den Photometer-Namen ein:", value = "stars"),
               dateRangeInput("dateRangeFetchData", "Wähle Datum:"),
               checkboxInput("preprocessing", "Vorprozessierung", value = FALSE),
               actionButton("updateData", "aktualisieren", icon = NULL, width = NULL, disabled = FALSE),
               actionButton("nextPanelToAnalysis", "weiter zur Auswertung", icon = NULL, width = NULL, disabled = FALSE)  # Add the switch here
             ),
             mainPanel(
               textOutput("dataStatus")  # Platzhalter, um zu zeigen, ob Daten hochgeladen wurden
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

# Server function (placeholder for this example)
server <- function(input, output, session) {
  output$dataStatus <- renderText({
    paste("Daten für Photometer", input$photometerName, "wurden hochgeladen.")
  })
  
  output$reportStatus <- renderText({
    if (input$exportButton > 0) {
      "Der Report wurde exportiert."
    }
  })
  
  output$plotOutput <- renderPlot({
    # Placeholder plot
    plot(1:10, 1:10, main = "Beispiel-Plot für die Photometer-Analyse")
  })
}

# Run the app
shinyApp(ui = ui, server = server)
