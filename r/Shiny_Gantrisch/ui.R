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
                                       "monatliche Analyse",
                                       "PhotometerGraphicsMonthly", 
                                       "PhotometerGraphicsPerNight", 
                                       "PhotometerComparison")),
               
               # Photometer Dropdown
               conditionalPanel(
                 condition = "input.analysisType != 'PhotometerComparison'",
                 selectInput("photometerDropdown", 
                             "Auswahl Photometer:", 
                             choices = NULL)
               ),
               
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerStatistics'",
                
               ),
               
               conditionalPanel(
                 condition = "input.analysisType == 'monatliche Analyse'",
                 
               ),
               
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerGraphicsMonthly'",
                 dateRangeInput("dateRange", 
                                "Auswahl Analyse Zeitraum:"),
               ),
               
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerGraphicsPerNight'",
               ),
               
               conditionalPanel(
                 condition = "input.analysisType == 'PhotometerComparison'",
                 
                 fluidRow(
                   column(6,
                          selectInput("photometerCompare1", 
                                      "1. Photometer:", 
                                      choices = NULL)
                   ),
                   column(6,
                          selectInput("photometerCompare2", 
                                      "2. Photometer:", 
                                      choices = NULL)
                   )
                 )
               )
             ),
             
             # Main panel to display the plot conditionally
             mainPanel(
               conditionalPanel(
                 condition = "input.analysisType == 'monatliche Analyse'",
                 plotOutput("plotPerYear")
               )
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
