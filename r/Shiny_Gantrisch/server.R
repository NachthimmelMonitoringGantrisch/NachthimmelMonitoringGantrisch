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
  # "PhotometerDropdown" - Load Data and Populate Dropdown
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
      photometer_names <- gsub("_data$", "", table_names)
      print("Tables in tess_data database:")
      print(photometer_names)
      
      # Update dropdown choices
      updateSelectInput(session, "photometerDropdown", choices = photometer_names)
      updateSelectInput(session, "photometerCompare1", choices = photometer_names)
      updateSelectInput(session, "photometerCompare2", choices = photometer_names)
      
      dbDisconnect(db_tess_data)
      
    }, error = function(e) {
      print(paste("Error connecting to 'tess_data' database at path:", db_tess_data_path, ":", e$message))
      output$photometerDropdown <- renderText({
        "Unable to connect to tess_data database. Check connection settings."
      })
    })
  }
  
  #--------------------------------------------------------------------------
  # Observe "photometerDropdown" selection to update "multipleYearsDropdown" and "singleYearsDropdown"
  #--------------------------------------------------------------------------
  
  observeEvent(input$photometerDropdown, {
    # Ensure a photometer is selected
    req(input$photometerDropdown)
    
    # Connect to the database
    conn <- dbConnect(RSQLite::SQLite(), db_tess_data_path)
    
    # Define the table name dynamically based on the selected photometer
    table_name <- paste0(input$photometerDropdown, "_data")
    
    # Check if the table exists in the database
    if (table_name %in% dbListTables(conn)) {
      # Query to get distinct years in the data
      query <- paste("SELECT DISTINCT strftime('%Y', time) AS year FROM", table_name)
      years_data <- dbGetQuery(conn, query)
      
      # If years_data has rows, convert the year column to numeric
      if (nrow(years_data) > 0) {
        available_years <- sort(as.numeric(years_data$year))
      } else {
        available_years <- NULL
      }
    } else {
      available_years <- NULL
    }
    
    # Disconnect from the database
    dbDisconnect(conn)
    
    # Update "multipleYearsDropdown" with available years and set all as selected by default
    updateSelectInput(session, "multipleYearsDropdown", choices = available_years, selected = available_years)
    
    # Update "singleYearsDropdown" with available years (no default selection)
    updateSelectInput(session, "singleYearsDropdown", choices = available_years, selected = NULL)
  })
  
  #--------------------------------------------------------------------------
  # Observe "photometerDropdown" selection to update "singleMonthsDropdown" with latest month on top
  #--------------------------------------------------------------------------
  
  observeEvent(input$photometerDropdown, {
    # Ensure a photometer is selected
    req(input$photometerDropdown)
    
    # Connect to the database
    conn <- dbConnect(RSQLite::SQLite(), db_tess_data_path)
    
    # Define the table name dynamically based on the selected photometer
    table_name <- paste0(input$photometerDropdown, "_data")
    
    # Check if the table exists in the database
    if (table_name %in% dbListTables(conn)) {
      # Query to get distinct years and months
      query <- paste(
        "SELECT DISTINCT strftime('%Y', time) AS year, strftime('%m', time) AS month",
        "FROM", table_name,
        "ORDER BY year DESC, month DESC"
      )
      months_data <- dbGetQuery(conn, query)
      
      # Check if there are results, then organize the months by year with "Year - Month" format
      if (nrow(months_data) > 0) {
        # Initialize an empty list for available months
        available_months <- list()
        
        # Loop through each unique year and format months
        unique_years <- unique(months_data$year)
        for (year in unique_years) {
          # Filter months for the current year
          months <- months_data %>% filter(year == !!year) %>% pull(month)
          # Format each month as "Year - Month Name"
          month_labels <- format(as.Date(paste(year, months, "01", sep = "-")), "%Y - %B")
          # Create a named vector for the months of the current year
          available_months[[year]] <- setNames(as.character(paste(year, months, sep = "-")), month_labels)
        }
        
      } else {
        available_months <- list()
      }
    } else {
      available_months <- list()
    }
    
    # Disconnect from the database
    dbDisconnect(conn)
    
    # Update the "singleMonthsDropdown" with the available months grouped by year, latest month on top
    updateSelectInput(session, "singleMonthsDropdown", choices = available_months, selected = NULL)
  })
  
  #-------------------------------------------------------------------
  # Call "Histogram_over21perMonth_yearly.R" Script and Generate Plot
  #-------------------------------------------------------------------
  
  output$plotHistogramPerYear <- renderPlot({
    photometer_id <- input$photometerDropdown  # Selected photometer ID
    print(photometer_id)
    
    if (!is.null(photometer_id) && photometer_id != "") {
      source("Histogram_over21perMonth_yearly.R")
      plot_result <- main(photometer_id)  # Call the main function from photometer_statistics with the selected photometer ID
      
      if (!is.null(plot_result)) {
        plot_result
      } else {
        print("Plot could not be generated. Check Histogram_over21perMonth_yearly.R for issues.")
      }
    } else {
      print("No photometer selected in the dropdown.")
    }
  })
  
  #-------------------------------------------------------------------
  # Call "PhotometerStatistics_overYears.R" Script and Generate Plot
  #-------------------------------------------------------------------
  
  output$plotPhotometerStatistics <- renderPlot({
    photometer_id <- input$photometerDropdown  # Selected photometer ID
    print(photometer_id)
    
    if (!is.null(photometer_id) && photometer_id != "") {
      source("PhotometerStatistics_overYears.R")
      plot_result <- main(photometer_id)
      
      if (!is.null(plot_result)) {
        plot_result
      } else {
        print("Plot could not be generated. PhotometerStatistics_overYears.R for issues.")
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
