library(shiny)
library(DT)

# UI-Komponente mit drei Tabs
ui <- navbarPage(
  title = "Nachthimmelmonitoring Naturpark Gantrisch",
  
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
                   column(12, uiOutput("notificationArea"))
                 ),
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
                 selectInput("singleMonthsDropdown", 
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
                 condition = "input.analysisType == 'Analyse pro Monat'",
                 plotOutput("plotMinMaxMSASPerMonth")
               ),
               conditionalPanel(
                 condition = "input.analysisType == 'Analyse pro Monat'",
                 plotOutput("plotDarkTimeMoonPerMonth")
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
           ))
)
