# Load required libraries
library(shiny)
library(RSQLite)
library(reticulate)
library(jsonlite)
library(DT)
library(dplyr)

#----------------------------------------------------------------------
# Initialization of `A_setup_venv_R.py`
#----------------------------------------------------------------------

# Define Python setup script path for `setup_venv_R.py`
setup_venv_script_path <- normalizePath(file.path("..", "..", "python", "A_setup_venv_R.py"), mustWork = TRUE)

# Run the Python setup script using system()
tryCatch({
  message("Setting up virtual environment for R integration...")
  setup_command <- sprintf('python "%s"', setup_venv_script_path)
  
  # Execute the script and capture output
  system_output <- system(setup_command, intern = TRUE)
  print(system_output)
  
  message("Virtual environment setup for R completed successfully.")
}, error = function(e) {
  stop("Failed to set up the virtual environment for R. Error: ", e$message)
})

#----------------------------------------------------------------------
# Initialization of `B_setup_TESS-IDA-TOOLS.py`
#----------------------------------------------------------------------

# Define Python setup script path for `setup_TESS-IDA-TOOLS.py`
setup_tess_script_path <- normalizePath(file.path("..", "..", "python", "B_setup_TESS-IDA-TOOLS.py"), mustWork = TRUE)

# Run the Python setup script using system()
tryCatch({
  message("Initializing TESS-IDA-TOOLS setup...")
  setup_command <- sprintf('python "%s"', setup_tess_script_path)
  
  # Execute the script and capture output
  system_output <- system(setup_command, intern = TRUE)
  print(system_output)
  
  message("TESS-IDA-TOOLS setup completed successfully.")
}, error = function(e) {
  stop("Failed to initialize TESS-IDA-TOOLS. Error: ", e$message)
})

#----------------------------------------------------------------------
# Set Python Environment for Reticulate
#----------------------------------------------------------------------

# Define the Python environment path for reticulate
python_env_path <- normalizePath(file.path("..", "..", ".venv_R", "Scripts", "python.exe"), mustWork = TRUE)

# Use the Python environment with reticulate
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
# Run Tess Download function
#----------------------------------------------------------------------

# Add the `run_tess_download` function here
run_tess_download <- function(photometer_names, start_date, end_date) {
  python_script <- normalizePath("../../python/F_download_TESS_data.py", mustWork = TRUE)
  tess_env_python <- normalizePath("../../python/TESS-IDA-TOOLS/jupyter/.venv/Scripts/python.exe", mustWork = TRUE)
  
  photometer_names_arg <- paste(photometer_names, collapse = ",")
  command <- sprintf(
    '"%s" "%s" "%s" "%s" "%s"',
    tess_env_python,
    python_script,
    photometer_names_arg,
    start_date,
    end_date
  )
  
  tryCatch({
    system_output <- system(command, intern = TRUE)
    print(system_output)
    return("Download completed successfully.")
  }, error = function(e) {
    stop(paste("Error during Python script execution:", e$message))
  })
}

#----------------------------------------------------------------------
# Define the server function
#----------------------------------------------------------------------

server <- function(input, output, session) {
  
  #-------------------------------------------------------------------
  # Run initial setup "C_metadata_2_DB.py"
  #-------------------------------------------------------------------

  observe({
    withProgress(message = "Initialisiere Metadaten Datenbank", value = 0, {
      tryCatch({
        fetch_metadata_path <- normalizePath("../../python/C_metadata_2_DB.py", mustWork = TRUE)
        
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
      # "downloadData" / "Daten herunterladen" - Observe event for button click
      #-------------------------------------------------------------------
      
      observeEvent(input$downloadData, {
        # Clear previous notification
        output$notificationArea <- renderUI({ NULL })
        
        # Fetch selected photometer names and date range
        names_list <- selected_names()
        date_range <- selected_date_range()
        
        # Validate inputs
        if (is.null(names_list) || length(names_list) == 0) {
          output$notificationArea <- renderUI({
            div(style = "color: red; font-weight: bold;", "Fehler: Es wurde kein Photometer ausgewählt.")
          })
          return()
        }
        if (is.null(date_range) || length(date_range) != 2) {
          output$notificationArea <- renderUI({
            div(style = "color: red; font-weight: bold;", "Fehler: Bitte wählen Sie einen gültigen Datumsbereich aus.")
          })
          return()
        }
        
        # Format arguments
        photometers <- paste(names_list, collapse = ",")
        start_date <- date_range[1]
        end_date <- date_range[2]
        
        # Command to call the Python script
        python_path <- normalizePath(file.path("..", "..", "python", "TESS-IDA-TOOLS", "jupyter", ".venv", "Scripts", "python.exe"))
        script_path <- normalizePath(file.path("..", "..", "python", "F_download_TESS_data.py"))
        command <- sprintf('"%s" "%s" "%s" "%s" "%s"', python_path, script_path, photometers, start_date, end_date)
        
        # Display progress bar while running the command
        withProgress(message = "Daten werden heruntergeladen...", value = 0, {
          incProgress(0.3, detail = "Start...")
          tryCatch({
            output_log <- system(command, intern = TRUE)
            print(output_log)  # Log to console for debugging
            
            # Parse output for specific warnings
            warning_message <- NULL
            for (line in output_log) {
              if (grepl("No monthly file exists", line)) {
                warning_message <- sub(".*\\[WARNING\\] \\[download\\] \\[(.*?)\\] No monthly file exists: (.*?)\\.dat", 
                                       "Keine Daten für \\2 gefunden.", line)
                break
              }
            }
            
            # Update notification area
            if (!is.null(warning_message)) {
              output$notificationArea <- renderUI({
                div(style = "color: orange; font-weight: bold;", warning_message)
              })
            } else {
              # If no warnings, display success message with photometer names
              output$notificationArea <- renderUI({
                div(style = "color: green; font-weight: bold;", paste("Download von", photometers, "abgeschlossen."))
              })
            }
            
          }, error = function(e) {
            # Update notification area with error message
            print(e$message)
            output$notificationArea <- renderUI({
              div(style = "color: red; font-weight: bold;", paste("Fehler beim Download:", e$message))
            })
          })
          incProgress(1, detail = "Fertig.")
        })
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
    selected_years <- input$multipleYearsDropdown  # Selected years from the dropdown
    
    # Ensure valid inputs
    req(photometer_id, selected_years)
    
    withProgress(message = "Rendering Photometer Statistics...", value = 0, {
      incProgress(0.3, detail = "Loading data and processing...")
      
      tryCatch({
        # Source the script to ensure updated logic
        source("Histogram_over21perMonth_yearly.R")
        
        # Call the main function with photometer ID and selected years
        plot_result <- main(photometer_id, as.numeric(selected_years))
        
        # Ensure the plot result is valid
        if (!is.null(plot_result)) {
          incProgress(1, detail = "Render complete.")
          return(plot_result)
        } else {
          stop("The plot could not be generated. Please check your data or the script.")
        }
      },
      error = function(e) {
        # Log the error and notify the user
        print(paste("Error occurred:", e$message))
        showNotification(
          paste("Error rendering plot:", e$message),
          type = "error",
          duration = 5
        )
      },
      warning = function(w) {
        # Log warnings
        print(paste("Warning occurred:", w$message))
        showNotification(
          paste("Warning during rendering:", w$message),
          type = "warning",
          duration = 5
        )
      })
    })
  })
  
  #-------------------------------------------------------------------
  # Call "PhotometerStatistics_overYears.R" Script and Generate Plot
  #-------------------------------------------------------------------
  
  output$plotPhotometerStatistics <- renderPlot({
    photometer_id <- input$photometerDropdown  # Selected photometer ID
    print(photometer_id)
    
    withProgress(message = "Rendering Photometer Statistics...", value = 0, {
      incProgress(0.3, detail = "Loading data and processing...")
    
    if (!is.null(photometer_id) && photometer_id != "") {
      source("PhotometerStatistics_overYears.R")
      plot_result <- main(photometer_id)
      
      if (!is.null(plot_result)) {
        incProgress(1, detail = "Render complete.")
        plot_result
      } else {
        print("Plot could not be generated. PhotometerStatistics_overYears.R for issues.")
      }
    } else {
      print("No photometer selected in the dropdown.")
    }
   })
  })
  
  #-------------------------------------------------------------------
  # Call "MinMaxMSAS_perMonth.R" Script and Generate Plot
  #-------------------------------------------------------------------
  
  output$plotMinMaxMSASPerMonth <- renderPlot({
    photometer_id <- input$photometerDropdown  # Selected photometer ID
    month <- input$singleMonthsDropdown # Selected month
    print(photometer_id)
    print(month)
    
    withProgress(message = "Rendering Photometer Statistics...", value = 0, {
      incProgress(0.3, detail = "Loading data and processing...")
      
      if (!is.null(photometer_id) && photometer_id != "") {
        source("MinMaxMSAS_perMonth.R")
        plot_result <- main(photometer_id, month)
        
        if (!is.null(plot_result)) {
          incProgress(1, detail = "Render complete.")
          plot_result
        } else {
          print("Plot could not be generated. PhotometerStatistics_overYears.R for issues.")
        }
      } else {
        print("No photometer selected in the dropdown.")
      }
    })
  })

  #-------------------------------------------------------------------
  # Call "DarkTimeMoon_perMonth.R" Script and Generate Plot
  #-------------------------------------------------------------------
  
  output$plotDarkTimeMoonPerMonth <- renderPlot({
    photometer_id <- input$photometerDropdown  # Selected photometer ID
    month <- input$singleMonthsDropdown # Selected month
    print(photometer_id)
    print(month)
    
    withProgress(message = "Rendering Photometer Statistics...", value = 0, {
      incProgress(0.3, detail = "Loading data and processing...")
      
      if (!is.null(photometer_id) && photometer_id != "") {
        source("DarkTimeMoon_perMonth.R")
        plot_result <- main(photometer_id, month)
        
        if (!is.null(plot_result)) {
          incProgress(1, detail = "Render complete.")
          plot_result
        } else {
          print("Plot could not be generated. PhotometerStatistics_overYears.R for issues.")
        }
      } else {
        print("No photometer selected in the dropdown.")
      }
    })
  })
  
  #-------------------------------------------------------------------
  # Report Status Placeholder
  #-------------------------------------------------------------------
  
  output$reportStatus <- renderText({
    "Bereit zum Exportieren des Reports."
  })
}
