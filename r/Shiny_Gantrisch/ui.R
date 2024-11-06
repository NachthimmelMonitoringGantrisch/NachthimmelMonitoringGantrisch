library(shiny)
library(DT)

# UI-Komponente mit drei Tabs
ui <- navbarPage(
  title = "Photometer Analyse App",
  
  # Link to the CSS file
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")
  ),
  
  #----------------------------------------------------------------- Tab for "Daten herunterladen" -------------------------------------------------
  tabPanel("Daten herunterladen",
           fillPage(
             sidebarLayout(
               sidebarPanel(
                 dateRangeInput("dateRangeFetchData", 
                                "Wähle die Zeitspanne für den Download:"),
                 actionButton("updateData", 
                              "aktualisieren"),
                 actionButton("nextPanelToAnalysis", 
                              "weiter zur Auswertung"),
                 actionButton("downloadData", 
                              "Daten herunterladen")
               ),
               mainPanel(
                 DTOutput("tablePhotometerDownload", height = "100%")
               )
             )
           )),
  
  #---------------------------------------------------------------- Tab for "Photometer Analyse" ---------------------------------------------------
  tabPanel("Photometer Analyse",
           sidebarLayout(
             sidebarPanel(
               # Dropdown to select the analysis type
               selectInput("analysisType", "Select Analysis Type:",
                           choices = c("PhotometerStatistics", 
                                       "PhotometerGraphicsMonthly", 
                                       "PhotometerGraphicsPerNight", 
                                       "PhotometerComparison")),
               
               # Conditional UI elements based on the selected analysis type
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerStatistics'",
                 dateRangeInput("dateRange1", "Wähle Datum für Plot 1:")
               ),
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerGraphicsMonthly'",
                 dateRangeInput("dateRange2", "Wähle Datum für Plot 2:")
               ),
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerGraphicsPerNight'",
                 dateRangeInput("dateRange3", "Wähle Datum für Plot 3:"),
                 sliderInput("slider1", "Wähle den Abstand", -1, 1, 0.25)
               ),
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerComparison'",
                 dateRangeInput("dateRange4", "Wähle Datum für Plot 4:")
               )
             ),
             
             # Main panel to display the plot
             mainPanel(
               plotOutput("plotOutput")
             )
           )),
  
  #----------------------------------------------------------------- Tab for "Analyse Report" ------------------------------------------------------
  tabPanel("Analyse Report",
           sidebarLayout(
             sidebarPanel(
               checkboxInput("check_PhotometerStatistics", 
                             "Photometer Statistik", value = TRUE),
               checkboxInput("check_PhotometerGraphics", 
                             "Photometer Grafik", value = TRUE),
               checkboxInput("check_PhotometerComparison", 
                             "Photometer Vergleich", value = TRUE),
               actionButton("exportButton", 
                            "Exportiere Report")
             ),
             mainPanel(
               textOutput("reportStatus")  # Placeholder for export status
             )
           ))
)
