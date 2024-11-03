library(shiny)
library(RSQLite)
library(reticulate)  # Load reticulate to enable Python code execution
library(DT)

# Define Python function to execute
source_python_code <- function() {
  py_run_string("print('Python code executed')")  # Replace with your Python code
  # Alternatively, you can run an external script with py_run_file("path/to/script.py")
}

# Server-Komponente
server <- function(input, output, session) {
  
  # DATENBEZUG - Dynamically list SQL databases in data folder
  output$tablePhotometerDownload <- renderDT({
    db_files <- tryCatch({
      list.files(path = "data", pattern = "\\.db$", full.names = TRUE)  # Use full.names for correct paths
    }, error = function(e) {
      paste("Error accessing data directory:", e$message)
    })
    
    # Print the output to the console for debugging
    print(db_files)  # Check what files are found
    
    # Create a data frame for display in the table
    if (length(db_files) == 0) {
      db_data <- data.frame(Database_Files = "No database files found.")
    } else {
      db_data <- data.frame(Database_Files = db_files)
    }
    
    # Render data table with DT
    datatable(db_data, options = list(pageLength = 5), rownames = FALSE)
  })
  
  # Observe event for updateData button to trigger Python code execution
  observeEvent(input$updateData, {
    # Execute the Python code when the button is clicked
    source_python_code()
    output$dataStatus <- renderText({
      if (is.null(input$fileUpload)) {
        "Keine Datei hochgeladen."
      } else {
        paste("Datei hochgeladen:", input$fileUpload$name, "- Python-Code wurde ausgeführt.")
      }
    })
  })
  
  # Placeholder für Daten-Status, falls keine Datei hochgeladen wird
  output$dataStatus <- renderText({
    if (is.null(input$fileUpload)) {
      "Keine Datei hochgeladen."
    } else {
      paste("Datei hochgeladen:", input$fileUpload$name)
    }
  })
  
  
  # Placeholder für Plot
  output$plotOutput <- renderPlot({
    plot(cars)  # Einfacher Beispiel-Plot
  })
  
  # Placeholder für Export-Status
  output$reportStatus <- renderText({
    "Bereit zum Exportieren des Reports."
  })
}
