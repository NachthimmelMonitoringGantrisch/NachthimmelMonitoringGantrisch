# Load required libraries
library(shiny)
library(RSQLite)
library(reticulate)
library(jsonlite)
library(DT)
library(dplyr)

# Set Python environment path using a relative path
python_env_path <- normalizePath(file.path("..", "..", ".venv_R", "Scripts", "python.exe"), mustWork = TRUE)

# Use the Python environment
use_python(python_env_path, required = TRUE)

# Check if reticulate is correctly configured
print("Python Configuration:")
print(py_config())

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
  # Run initial setup "metadata_2_DB.py"
  #-------------------------------------------------------------------

  observe({
    withProgress(message = "Initialisiere Metadaten Datenbank", value = 0, {
      tryCatch({
        fetch_metadata_path <- normalizePath("../../python/metadata_2_DB.py", mustWork = TRUE)
        
        incProgress(0.2, detail = "Starte Live-Abfrage @ https://api.stars4all.eu/photometers")
        py_run_file(fetch_metadata_path)
        
        incProgress(0.7, detail = "Finalisiere Setup Metadaten")
        print("Python script executed successfully.")
        
        incProgress(0.95, detail = "Setup komplett.")
      }, error = function(e) {
        print(paste("Error executing Python script:", e$message))
        showNotification(paste("Error initializing database:", e$message), type = "error")
      })
    })
  })
  
  #-------------------------------------------------------------------
  # "Datenbezug" - Load Metadata Table and Display
  #-------------------------------------------------------------------
  
  db_metadata_path <- normalizePath(file.path("..", "..", "data", "TessNetwork_metadata.db"), mustWork = FALSE)
  
  if (!file.exists(db_metadata_path)) {
    # Notify user of missing database file
    print(paste("Database file not found at path:", db_metadata_path))
    output$tablePhotometerDownload <- renderText({
      "Database file not found. Check the file path and try again."
    })
  } else {
    # Connect to the metadata database and load data
    tryCatch({
      db_metadata <- dbConnect(SQLite(), dbname = db_metadata_path)
      print("Successfully connected to TessNetwork_metadata database.")
      
      # Check if the metadata table exists
      if ("TessNetwork_metadata" %in% dbListTables(db_metadata)) {
        # Fetch the metadata table
        photometer_metadata <- dbReadTable(db_metadata, "TessNetwork_metadata")
        print("Metadata table loaded successfully.")
      } else {
        stop("Table 'TessNetwork_metadata' does not exist in the database.")
      }
      
      # Disconnect from the database
      dbDisconnect(db_metadata)
      
      # Ensure columns are in the correct order (if required)
      desired_columns <- c(
        "name", "latitude", "longitude", "country", "city", "place", 
        "local_timezone_name", "local_timezone", "org_name"
      )
      missing_columns <- setdiff(desired_columns, colnames(photometer_metadata))
      if (length(missing_columns) > 0) {
        stop(paste("The following required columns are missing:", paste(missing_columns, collapse = ", ")))
      }
      photometer_metadata <- photometer_metadata[, desired_columns]
      
      # Render the metadata table
      output$tablePhotometerDownload <- renderDT({
        datatable(
          photometer_metadata,
          rownames = FALSE,
          selection = 'multiple',
          options = list(
            pageLength = 25,
            autoWidth = TRUE,
            scrollY = "calc(100vh - 200px)",  # Use viewport height dynamically for vertical scrolling
            scrollX = TRUE,                 # Fully stretch horizontally to avoid horizontal scrolling
            columnDefs = list(
              list(width = "80px", targets = c(0, 1, 2)),  # Width for first three columns
              list(width = "100px", targets = c(3:(ncol(photometer_metadata) - 1)))  # Width for remaining columns
            ),
            dom = "lfrtip"
          ),
          class = "display nowrap cell-border",
          style = "default"
        )
      })
      
      #-------------------------------------------------------------------
      #  Selected Photometer names for "downloadData" button click
      #-------------------------------------------------------------------
      
      selected_names <- reactive({
        selected_rows <- input$tablePhotometerDownload_rows_selected
        if (length(selected_rows) > 0) {
          photometer_metadata[selected_rows, "name"]
        } else {
          NULL
        }
      })
      
      
      #-------------------------------------------------------------------
      # Selected time range for "downloadData" button click
      #-------------------------------------------------------------------
      
      selected_date_range <- reactive({
        if (!is.null(input$dateRangeFetchData) && length(input$dateRangeFetchData) == 2) {
          input$dateRangeFetchData
        } else {
          NULL
        }
      })
      
      #-------------------------------------------------------------------
      # "downloadData" / "Daten herunterladen" - Observe event for  button click
      #-------------------------------------------------------------------
      
      observeEvent(input$downloadData, {
        # Clear any previous notification
        output$notificationArea <- renderUI({ NULL })
        
        # Fetch selected photometer names
        names_list <- selected_names()
        date_range <- selected_date_range()
        
        # Validate the date range
        if (!is.null(date_range)) {
          start_date <- date_range[1]
          end_date <- date_range[2]
          
          # Check if start date is after end date
          if (start_date > end_date) {
            print("Fehler: Startdatum ist später als Enddatum.")
            output$notificationArea <- renderUI({
              div(style = "color: red; font-weight: bold;",
                  "Fehler: Das Startdatum darf nicht später als das Enddatum sein.")
            })
            return()
          }
          
          print("Selected Date Range:")
          print(paste("Start Date:", start_date, "| End Date:", end_date))
        } else {
          print("Kein Datumsbereich ausgewählt.")
          output$notificationArea <- renderUI({
            div(style = "color: red; font-weight: bold;",
                "Fehler: Bitte wählen Sie einen gültigen Datumsbereich aus.")
          })
          return()
        }
        
        # Print selected photometer names
        if (!is.null(names_list) && length(names_list) > 0) {
          print("Selected Photometer Names:")
          print(names_list)
        } else {
          print("Keine Photometer ausgewählt.")
          output$notificationArea <- renderUI({
            div(style = "color: red; font-weight: bold;",
                "Fehler: Es wurde kein Photometer ausgewählt.")
          })
          return()
        }
        
        # If all validations pass, display a green notification and start the download
        output$notificationArea <- renderUI({
          div(style = "color: green; font-weight: bold;",
              "Download wird gestartet...")
        })
        
        print("Download starting...")
      })  # End of observeEvent
      
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
