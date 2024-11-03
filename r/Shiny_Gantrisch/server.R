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
  
  # Observe event for updateData button to trigger Python code execution
  observeEvent(input$updateData, {
    # Ensure all necessary inputs are present
    req(input$photometerName, input$dateRangeFetchData, input$preprocessing)
    
    # Retrieve values from the UI
    photometer_name <- input$photometerName
    date_range <- input$dateRangeFetchData
    preprocessing <- input$preprocessing
    
    # Run the Python code with parameters
    source_python_code(photometer_name, date_range[1], date_range[2], preprocessing)
    
    # Update the data status message
    output$dataStatus <- renderText({
      paste("Daten für Photometer", photometer_name, "wurden aktualisiert.")
    })
  })
  
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