library(shiny)
library(RSQLite)
library(reticulate)  # Load reticulate to enable Python code execution
library(jsonlite)
library(DT)

# Code that runs only once when the app starts
initial_setup <- function() {
  print("First check if Python env is installed")
  print("If not installed, create Env")
  print("If installed, install TESS-IDA")
  print("Else skip")
  print("Finished")

  # Example: Run any initial Python setup if needed
  # py_run_string("print('Python setup code executed')")
}

# Call the setup function
initial_setup()

# Define a function to run Python code with UI values as parameters
source_python_code <- function(photometer_name, start_date, end_date, preprocessing) {
  # Assign R inputs to Python variables
  py$photometer_name <- photometer_name
  py$start_date <- start_date
  py$end_date <- end_date
  py$preprocessing <- preprocessing
  
  # Execute Python code with these variables
  py_run_string("
print(f'Photometer Name: {photometer_name}')
print(f'Date Range: {start_date} to {end_date}')
print(f'Preprocessing Enabled: {preprocessing}')
# Additional Python code can go here
")
}

#---------------------------------------------------------------------- Server component ----------------------------------------------------------
server <- function(input, output, session) {
  
#----------------------------------------------------------------- "Datenbezug" - Table Metadata --------------------------------------------------
  
  # Set working directory (adjust as necessary)
  setwd("C:/Users/Nando Amport/5230_Geoinformatik_Repository/NachthimmelMonitoringGantrisch")
  
  # Check the current working directory
  print(paste("Current working directory:", getwd()))
  
  # Define relative path and convert to absolute path
  db_metadata_path <- normalizePath(file.path("data", "TessNetwork_metadata.db"), mustWork = FALSE)
  
  # Check if the database file exists
  if (!file.exists(db_metadata_path)) {
    print(paste("Database file not found at path:", db_metadata_path))
    output$tablePhotometerDownload <- renderText({
      "Database file not found. Check the file path and try again."
    })
  } else {
    # Try connecting to the SQLite database with error handling
    tryCatch({
      db_metadata <- dbConnect(SQLite(), dbname = db_metadata_path)
      print("Successfully connected to TessNetwork_metadata database.")
      
      # Check if table exists before querying
      if ("TessNetwork_metadata" %in% dbListTables(db_metadata)) {
        # Load data
        photometer_metadata <- dbReadTable(db_metadata, "TessNetwork_metadata")
      } else {
        stop("Table 'TessNetwork_metadata' does not exist in the database.")
      }
      
      # Disconnect from the database
      dbDisconnect(db_metadata)
      
      # Render the static data table with row selection enabled
      output$tablePhotometerDownload <- renderDT({
        datatable(photometer_metadata,
                  rownames = FALSE, 
                  selection = 'multiple',  # Allow multiple row selection
                  options = list(pageLength = 25, 
                                 deferRender = TRUE, 
                                 scrollY = 600,
                                 scrollX = FALSE))
      })
      
      # Reactive expression to extract 'name' values from selected rows
      selected_names <- reactive({
        selected_rows <- input$tablePhotometerDownload_rows_selected
        if (length(selected_rows) > 0) {
          photometer_metadata[selected_rows, "name"]
        } else {
          NULL  # No rows selected
        }
      })
      
#---------------------------------------------------------------- "Datenbezug" - Button Download --------------------------------------------------
      
      # Observe event for "downloadData" button click
      observeEvent(input$downloadData, {
        # Get the list of selected names
        names_list <- selected_names()
        
        # Print the list in the console when the button is clicked
        if (!is.null(names_list) && length(names_list) > 0) {
          print("Selected Photometer Names:")
          print(names_list)
        } else {
          print("Keine Photometer ausgewählt.")
        }
      })
      
    }, error = function(e) {
      # Error handling
      print(paste("Error connecting to database at path:", db_metadata_path, ":", e$message))
      output$tablePhotometerDownload <- renderText({
        "Unable to load data. Check database connection and path."
      })
    })
  }
  
#---------------------------------------------------------------- "Photometer Analyse" - Datenverbindung -----------------------------------------
  
  # Path to the tess_data database
  db_tess_data_path <- normalizePath(file.path("data", "tess_data.db"), mustWork = FALSE)
  
  # Check if the database file exists
  if (!file.exists(db_tess_data_path)) {
    print(paste("Database file 'tess_data' not found at path:", db_tess_data_path))
    output$tableDropdown <- renderUI({
      "Database file not found. Check the file path and try again."
    })
  } else {
    # Connect to the tess_data database and list tables
    tryCatch({
      db_tess_data <- dbConnect(SQLite(), dbname = db_tess_data_path)
      print("Successfully connected to tess_data database.")
      
      # List all tables in the tess_data database
      table_names <- dbListTables(db_tess_data)
      table_names <- table_names[table_names != "data_import_control"]
      print("Tables in tess_data database:")
      print(table_names)
      
      # Update the choices in the dropdown menu
      updateSelectInput(session, "tableDropdown", choices = table_names)
      
      dbDisconnect(db_tess_data)
      
    }, error = function(e) {
      print(paste("Error connecting to 'tess_data' database at path:", db_tess_data_path, ":", e$message))
      output$tableDropdown <- renderText({
        "Unable to connect to tess_data database. Check connection settings."
      })
    })
  }
  
#------------------------------------------------------------------------------------------------------------------------------------------------
  
  # Render different plots based on selected analysis type
  output$plotOutput <- renderPlot({
    selected_type <- input$analysisType
    
    if (selected_type == "PhotometerStatistics") {
      plot(cars, main = "Photometer Statistics")
    } else if (selected_type == "PhotometerGraphicsMonthly") {
      hist(mtcars$mpg, col = "blue", main = "Monthly Photometer Graphics", xlab = "MPG", ylab = "Frequency")
    } else if (selected_type == "PhotometerGraphicsPerNight") {
      boxplot(mpg ~ cyl, data = mtcars, col = "orange", main = "Photometer Graphics Per Night", xlab = "Cylinders", ylab = "MPG")
    } else if (selected_type == "PhotometerComparison") {
      plot(pressure, type = "l", col = "red", main = "Photometer Comparison", xlab = "Temperature", ylab = "Pressure")
    }
  })

#------------------------------------------------------------------------------------------------------------------------------------------------
  
  # Placeholder for export status
  output$reportStatus <- renderText({
    "Bereit zum Exportieren des Reports."
  })
}