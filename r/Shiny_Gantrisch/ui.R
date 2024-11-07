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
                 width = 2,
                 
                 dateRangeInput("dateRangeFetchData", 
                                "Wähle die Zeitspanne für den Download:"),
                 
                 # Use fluidRow for each button in separate rows
                 fluidRow(
                   column(12, actionButton("downloadData", "Daten herunterladen", class = "btn-custom"))
                 ),
                 fluidRow(
                   column(12, actionButton("nextPanelToAnalysis", "Weiter zur Auswertung", class = "btn-custom"))
                 ),
                 fluidRow(
                   column(12, actionButton("updateData", "Aktualisieren", class = "btn-custom"))
                 )
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
               width = 2,
               
               # Analyse Typ Dropdown
               selectInput("analysisType", "Wähle den Analyse Typ:",
                           choices = c("PhotometerStatistics", 
                                       "PhotometerGraphicsMonthly", 
                                       "PhotometerGraphicsPerNight", 
                                       "PhotometerComparison")),
               
               # Photometer Dropdown
               conditionalPanel(
                 condition = "input.analysisType != 'PhotometerComparison'",
                 selectInput("photometerDropdown", 
                             "Wähle den Photometer für die Analyse:", 
                             choices = NULL)
               ),
               
               # Input Data Range
               dateRangeInput("dateRange", 
                              "Wähle den Zeitraum für die Analyse:"),
               
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerStatistics'",
                
               ),
               
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerGraphicsMonthly'",
                 
               ),
               
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerGraphicsPerNight'",
                 sliderInput("slider1", 
                             "Wähle den Abstand", 
                             -1, 1, 0.25)
               ),
               
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerComparison'",
                 # Add side-by-side dropdowns for photometer comparison
                 fluidRow(
                   column(6,
                          selectInput("photometerCompare1", 
                                      "Wähle den ersten Photometer:", 
                                      choices = NULL)
                   ),
                   column(6,
                          selectInput("photometerCompare2", 
                                      "Wähle den zweiten Photometer:", 
                                      choices = NULL)
                   )
                 )
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
