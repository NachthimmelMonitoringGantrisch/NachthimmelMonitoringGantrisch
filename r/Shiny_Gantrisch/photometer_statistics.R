library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)

# Path to the SQLite database
db_tess_data_path <- normalizePath(file.path("..", "..", "data", "tess_data.db"), mustWork = FALSE)

# Function to load data from the SQLite database for a specific photometer
load_data_from_database <- function(photometer_id) {
  # Check if the database exists
  if (!file.exists(db_tess_data_path)) {
    stop(paste("Database not found at path:", db_tess_data_path))
  }
  
  # Connect to the SQLite database
  conn <- dbConnect(RSQLite::SQLite(), db_tess_data_path)
  
  # Construct the SQL query to get data for the selected photometer
  table_name <- paste0(photometer_id, "_data")
  print(paste("Loading data from table:", table_name))
  query <- paste("SELECT * FROM", table_name)
  
  # Fetch the data into a data frame
  df <- dbGetQuery(conn, query)
  
  # Close the connection
  dbDisconnect(conn)
  
  if (nrow(df) == 0) {
    stop(paste("No data found for photometer:", photometer_id))
  }
  
  return(df)
}

# Preprocess the data
preprocess_data <- function(df) {
  # Check for NA values in the 'time' column and remove them
  if (any(is.na(df$time))) {
    warning("NA values detected in time column. Removing them...")
    df <- df %>% filter(!is.na(time))
  }
  
  # Ensure 'time' column exists in the dataframe
  if (!"time" %in% colnames(df)) {
    stop("Time column not found in the data.")
  }
  
  # Print class before converting to POSIXct
  print("Class of time before conversion:")
  print(class(df$time))
  
  # Convert 'time' to POSIXct format for proper datetime handling
  df$time <- as.POSIXct(df$time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  
  # Print class after converting to POSIXct
  print("Class of time after conversion:")
  print(class(df$time))
  
  # Ensure we still have data after filtering
  if (nrow(df) == 0) {
    stop("No data available after filtering NA values in time.")
  }
  
  # Filter data to only include night times (18:00–06:00)
  df <- df %>%
    filter(hour(time) >= 18 | hour(time) < 6) %>%
    mutate(
      # Calculate the 'night_start' for grouping purposes
      night_start = ifelse(
        hour(time) >= 18,
        as.POSIXct(format(time, "%Y-%m-%d 18:00:00")),
        as.POSIXct(format(time - lubridate::days(1), "%Y-%m-%d 18:00:00"))
      )
    )
  
  # Print class of 'night_start' after creation
  print("Class of night_start after creation:")
  print(class(df$night_start))
  
  # Ensure the night_start column is POSIXct
  df$night_start <- as.POSIXct(df$night_start, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  
  # Check if the 'night_start' column was successfully created
  if (!"night_start" %in% colnames(df)) {
    stop("Failed to create night_start column.")
  }
  
  # Ensure there's enough data to proceed
  if (nrow(df) == 0) {
    stop("No data available after filtering by night time (18:00-06:00).")
  }
  
  # Group by each night and calculate mean MSAS for each night period
  df_nightly_stats <- df %>%
    group_by(night_start) %>%
    summarise(mean_msas = mean(msas, na.rm = TRUE)) %>%
    ungroup()
  
  # Check if the night_start and mean_msas columns are available
  if (!"night_start" %in% colnames(df_nightly_stats) | !"mean_msas" %in% colnames(df_nightly_stats)) {
    stop("Failed to calculate nightly statistics. Missing required columns.")
  }
  
  return(df_nightly_stats)
}

# Function to plot the histogram of the number of nights per mean MSAS value by month
plot_histogram <- function(df_nightly_stats) {
  # Check if the necessary column for month exists
  if (!"night_start" %in% colnames(df_nightly_stats)) {
    stop("night_start column is missing in the processed data.")
  }
  
  # Extract the month for grouping by month
  df_nightly_stats$month <- month(df_nightly_stats$night_start, label = TRUE)
  
  # Plot the histogram using ggplot2
  ggplot(df_nightly_stats, aes(x = month, fill = month)) +
    geom_bar(stat = "count", show.legend = FALSE) +
    labs(title = "Number of Nights with Mean MSAS Value per Month",
         x = "Month", y = "Number of Nights") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    scale_fill_brewer(palette = "Set3")
}

# Main function to run the analysis
main <- function(photometer_id) {
  # Load and preprocess the data
  data <- load_data_from_database(photometer_id)
  processed_data <- preprocess_data(data)
  
  # Check if the processed data contains any rows
  if (nrow(processed_data) == 0) {
    stop("No valid data available for the selected photometer.")
  }
  
  # Plot the histogram of the processed data
  plot_histogram(processed_data)
}
