# Load required libraries
library(shiny)
library(RSQLite)
library(reticulate)  # Enable Python code execution
library(jsonlite)
library(DT)

# Initial setup function that runs only once when the app starts
initial_setup <- function() {
  print("First check if Python env is installed")
  print("If not installed, create Env")
  print("If installed, install TESS-IDA")
  print("Else skip")
  print("Finished")
}

# Call the setup function
initial_setup()

# Define a function to execute Python code with UI parameters
source_python_code <- function(photometer_name, start_date, end_date, preprocessing) {
  py$photometer_name <- photometer_name
  py$start_date <- start_date
  py$end_date <- end_date
  py$preprocessing <- preprocessing
  
  py_run_string("
    print(f'Photometer Name: {photometer_name}')
    print(f'Date Range: {start_date} to {end_date}')
    print(f'Preprocessing Enabled: {preprocessing}')
    # Additional Python code can go here
  ")
}

#----------------------------------------------------------------------
# Define the server function
#----------------------------------------------------------------------

server <- function(input, output, session) {
  
  #-------------------------------------------------------------------
  # "Datenbezug" - Load Metadata Table and Display
  #-------------------------------------------------------------------
  
  db_metadata_path <- normalizePath(file.path("..", "..", "data", "TessNetwork_metadata.db"), mustWork = FALSE)
  
  if (!file.exists(db_metadata_path)) {
    print(paste("Database file not found at path:", db_metadata_path))
    output$tablePhotometerDownload <- renderText({
      "Database file not found. Check the file path and try again."
    })
  } else {
    # Connect to the metadata database and load data
    tryCatch({
      db_metadata <- dbConnect(SQLite(), dbname = db_metadata_path)
      print("Successfully connected to TessNetwork_metadata database.")
      
      if ("TessNetwork_metadata" %in% dbListTables(db_metadata)) {
        photometer_metadata <- dbReadTable(db_metadata, "TessNetwork_metadata")
      } else {
        stop("Table 'TessNetwork_metadata' does not exist in the database.")
      }
      
      dbDisconnect(db_metadata)
      
      # Render metadata table with row selection enabled
      output$tablePhotometerDownload <- renderDT({
        datatable(photometer_metadata,
                  rownames = FALSE, 
                  selection = 'multiple',
                  options = list(pageLength = 25, 
                                 deferRender = TRUE, 
                                 scrollY = 600,
                                 scrollX = FALSE))
      })
      
      selected_names <- reactive({
        selected_rows <- input$tablePhotometerDownload_rows_selected
        if (length(selected_rows) > 0) {
          photometer_metadata[selected_rows, "name"]
        } else {
          NULL
        }
      })
      
      # Observe event for "downloadData" button click
      observeEvent(input$downloadData, {
        names_list <- selected_names()
        
        if (!is.null(names_list) && length(names_list) > 0) {
          print("Selected Photometer Names:")
          print(names_list)
        } else {
          print("Keine Photometer ausgewählt.")
        }
      })
      
    }, error = function(e) {
      print(paste("Error connecting to database at path:", db_metadata_path, ":", e$message))
      output$tablePhotometerDownload <- renderText({
        "Unable to load data. Check database connection and path."
      })
    })
  }
  
  #-------------------------------------------------------------------
  # "Photometer Analyse" - Load Data and Populate Dropdown
  #-------------------------------------------------------------------
  
  db_tess_data_path <- normalizePath(file.path("..", "..", "data", "tess_data.db"), mustWork = FALSE)
  
  if (!file.exists(db_tess_data_path)) {
    print(paste("Database file 'tess_data' not found at path:", db_tess_data_path))
    output$photometerDropdown <- renderUI({
      "Database file not found. Check the file path and try again."
    })
  } else {
    tryCatch({
      db_tess_data <- dbConnect(SQLite(), dbname = db_tess_data_path)
      print("Successfully connected to tess_data database.")
      
      table_names <- dbListTables(db_tess_data)
      table_names <- table_names[table_names != "data_import_control"]
      table_names <- gsub("_data$", "", table_names)
      print("Tables in tess_data database:")
      print(table_names)
      
      # Update dropdown choices
      updateSelectInput(session, "photometerDropdown", choices = table_names)
      updateSelectInput(session, "photometerCompare1", choices = table_names)
      updateSelectInput(session, "photometerCompare2", choices = table_names)
      
      dbDisconnect(db_tess_data)
      
    }, error = function(e) {
      print(paste("Error connecting to 'tess_data' database at path:", db_tess_data_path, ":", e$message))
      output$photometerDropdown <- renderText({
        "Unable to connect to tess_data database. Check connection settings."
      })
    })
  }
  
  #-------------------------------------------------------------------
  # Call photometer_statistics Script and Generate Plot
  #-------------------------------------------------------------------
  
  output$plotPhotometerStatistics <- renderPlot({
    photometer_id <- input$photometerDropdown  # Selected photometer ID
    print(photometer_id)
    
    if (!is.null(photometer_id) && photometer_id != "") {
      source("photometer_statistics.R")  # Source the photometer statistics script
      plot_result <- main(photometer_id)  # Call the main function from photometer_statistics with the selected photometer ID
      
      if (!is.null(plot_result)) {
        plot_result
      } else {
        print("Plot could not be generated. Check photometer_statistics.R for issues.")
      }
    } else {
      print("No photometer selected in the dropdown.")
    }
  })
  
  #-------------------------------------------------------------------
  # Report Status Placeholder
  #-------------------------------------------------------------------
  
  output$reportStatus <- renderText({
    "Bereit zum Exportieren des Reports."
  })
}
