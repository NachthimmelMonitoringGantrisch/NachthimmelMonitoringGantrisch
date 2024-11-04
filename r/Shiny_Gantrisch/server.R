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

# Server component
server <- function(input, output, session) {
  
  # Set working directory (adjust as necessary)
  setwd("C:/Users/Nando Amport/5230_Geoinformatik_Repository/NachthimmelMonitoringGantrisch")
  
  # Check the current working directory
  print(paste("Current working directory:", getwd()))
  
  # Define relative path and convert to absolute path
  db_path <- normalizePath(file.path("data", "TessNetwork_metadata.db"), mustWork = FALSE)
  
  # Debugging output
  print(paste("Database path:", db_path))
  
  # Check if the database file exists
  if (!file.exists(db_path)) {
    print(paste("Database file not found at path:", db_path))
    output$tablePhotometerDownload <- renderText({
      "Database file not found. Check the file path and try again."
    })
  } else {
    # Try connecting to the SQLite database with error handling
    tryCatch({
      db <- dbConnect(SQLite(), dbname = db_path)
      
      # Check if table exists before querying
      if ("TessNetwork_metadata" %in% dbListTables(db)) {
        # Load data
        data <- dbReadTable(db, "TessNetwork_metadata")
      } else {
        stop("Table 'TessNetwork_metadata' does not exist in the database.")
      }
      
      # Disconnect from the database
      dbDisconnect(db)
      
      # Render the static data table at the start
      output$tablePhotometerDownload <- renderDT({
        datatable(data, options = list(pageLength = 10, deferRender = TRUE, scrollY = 400))
      })
      
    }, error = function(e) {
      # Error handling
      print(paste("Error connecting to database at path:", db_path, ":", e$message))
      output$tablePhotometerDownload <- renderText({
        "Unable to load data. Check database connection and path."
      })
    })
  }
  
  # Placeholder for data status if no file is uploaded
  output$dataStatus <- renderText({
    "Keine Datei hochgeladen."
  })
  
  # Placeholder for Plot
  output$plotOutput <- renderPlot({
    plot(cars)  # Simple example plot
  })
  
  # Placeholder for export status
  output$reportStatus <- renderText({
    "Bereit zum Exportieren des Reports."
  })
}
