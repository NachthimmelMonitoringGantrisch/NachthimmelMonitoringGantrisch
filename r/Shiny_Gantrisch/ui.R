library(shiny)
library(DT)

# UI-Komponente mit drei Tabs
ui <- navbarPage(
  title = tagList(
    "Nachthimmelmonitoring Naturpark Gantrisch",
    
    # Documentation icon (left)
    tags$a(
      href = "https://nachthimmel-monitoring-gantrisch-docs.vercel.app/",
      target = "_blank",
      tags$img(
        src = "documentation-icon.png",
        style = "width: 30px; height: 30px; position: absolute; right: 60px; top: 10px; cursor: pointer;",
        title = "Hier zur Dokumentation"
      )
    ),
    
    # GitHub icon (right)
    tags$a(
      href = "https://github.com/NachthimmelMonitoringGantrisch/NachthimmelMonitoringGantrisch",
      target = "_blank",
      tags$img(
        src = "GitHub-logo-weiss.png",
        style = "width: 30px; height: 30px; position: absolute; right: 15px; top: 10px; cursor: pointer;",
        title = "Hier zum GitHub Repository"
      )
    )
  ),
  
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
                                "Auswahl Zeitspanne:",
                                start = Sys.Date() - 30,
                                end = Sys.Date(),
                                max = Sys.Date()
                                ),

                 fluidRow(
                   column(12, actionButton("downloadData", "Daten herunterladen", class = "btn-custom"))
                 ),
                 fluidRow(
                   column(12, 
                          div(
                            h4("Statusbereich:", style = "font-weight: bold; margin-top: 10px; font-size: 14px"),  # Add title
                            uiOutput("notificationArea")
                          )
                   )
                 )
               ),
               mainPanel(
                 DTOutput("tablePhotometerDownload", height = "100%", width = "100%")
               )
             )
           )),
  
  #---------------------------------------------------------------- Tab for "Photometer Analyse" ---------------------------------------------------
  tabPanel("Photometer Analyse",
           sidebarLayout(
             sidebarPanel(
               width = 2,
               
               # Analyse Typ Dropdown
               selectInput("analysisType", "Auswahl Analyse Typ:",
                           choices = c("Photometer Statistik",
                                       "Analyse pro Jahr",
                                       "Analyse pro Monat", 
                                       "Analyse Einzelnächte", 
                                       "Photometer Vergleich")),
               
               # Photometer Dropdown
               conditionalPanel(
                 condition = "input.analysisType != 'Photometer Vergleich'",
                 selectInput("photometerDropdown", 
                             "Auswahl Photometer:", 
                             choices = NULL)
               ),
               
               # Photometer Statistics
               conditionalPanel(
                 condition = "input.analysisType == 'Photometer Statistik'",
               ),
               
               # Analyse pro Jahr
               conditionalPanel(
                 condition = "input.analysisType == 'Analyse pro Jahr'",
                 selectInput( 
                   "multipleYearsDropdown", 
                   "Auswahl der Jahre:", 
                   choices = NULL, 
                   multiple = TRUE 
                 )
               ),
               
               # Analyse pro Monat
               conditionalPanel(
                 condition = "input.analysisType == 'Analyse pro Monat'",
                 selectInput("singleMonthsDropdown", 
                             "Auswahl Monat:", 
                             choices = NULL)
               ),
               
               # Analyse Einzelnächte
               conditionalPanel(
                 condition = "input.analysisType == 'Analyse Einzelnächte'",
                 selectInput("singleNightsMonthsDropdown",  # New unique ID
                             "Auswahl Monat:", 
                             choices = NULL)
               ),
               
               # Photometer Vergleich
               conditionalPanel(
                 condition = "input.analysisType == 'Photometer Vergleich'",
                 
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
                 condition = "input.analysisType == 'Photometer Statistik'",
                 plotOutput("plotPhotometerStatistics")
               ),
               conditionalPanel(
                 condition = "input.analysisType == 'Analyse pro Jahr'",
                 plotOutput("plotHistogramPerYear")
               ),
               conditionalPanel(
                 condition = "input.analysisType == 'Analyse Einzelnächte'",
                 div(
                   style = "height: calc(100vh - 120px); overflow-y: auto; margin: 0; padding: 0;", # Enable scrolling
                   uiOutput("dynamicPlotContainer")  # Dynamically generated plot container
                 )
               ),
               conditionalPanel(
                 condition = "input.analysisType == 'Analyse pro Monat'",
                 plotOutput("plotMinMaxMSASDarkTimeMoonPerMonth", height = "800px", width = "100%")
               )
             )
           )),
  
  #----------------------------------------------------------------- Tab for "Analyse Report" ------------------------------------------------------
  tabPanel("Analyse Report",
           sidebarLayout(
             sidebarPanel(
               checkboxInput("check_Photometer Statistik", 
                             "Photometer Statistik", value = TRUE),
               checkboxInput("check_PhotometerGraphics", 
                             "Visualisierung pro Monat", value = TRUE),
               checkboxInput("check_PhotometerComparison", 
                             "Photometer Vergleich", value = TRUE),
               actionButton("exportButton", 
                            "Exportiere Report")
             ),
             mainPanel(
               textOutput("reportStatus")  # Placeholder for export status
             )
           )),
  
  # Add settings icon to the top-right of the navbar
  header = div(class = "navbar-right",
               tags$img(src = "settings-icon.png", 
                        style = "width: 24px; height: 24px; cursor: pointer; margin-right: 15px;", 
                        title = "Einstellungen", 
                        onclick = "alert('Settings clicked!')")
  )
)
