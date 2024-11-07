# Load necessary libraries
library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)

# Path to the SQLite database
db_tess_data_path <- normalizePath(file.path("..","..","data", "tess_data.db"), mustWork = FALSE)

# Function to load data from the SQLite database for a specific photometer
load_data_from_database <- function(photometer_id) {
  # Connect to the SQLite database
  conn <- dbConnect(RSQLite::SQLite(), db_tess_data_path)
  
  # Construct the SQL query to get data for the selected photometer
  table_name <- paste0(photometer_id, "_data")
  query <- paste("SELECT * FROM", table_name)
  
  # Fetch the data into a data frame
  df <- dbGetQuery(conn, query)
  
  # Close the connection
  dbDisconnect(conn)
  
  return(df)
}

# Function to preprocess the data and calculate mean MSAS per night
preprocess_data <- function(df) {
  # Convert timestamp to POSIXct and assign to a new column for processing
  df$timestamp <- as.POSIXct(df$timestamp)
  
  # Define "night" as starting at 18:00 (6:00 PM) and ending at 06:00 the next day
  df <- df %>%
    mutate(
      # Assign the start of the "night" for each observation
      night_start = if_else(
        hour(timestamp) >= 18,
        as.POSIXct(format(timestamp, "%Y-%m-%d 18:00:00")),
        as.POSIXct(format(timestamp - days(1), "%Y-%m-%d 18:00:00"))
      )
    )
  
  # Group by each night and calculate mean MSAS for each night period
  nightly_stats <- df %>%
    group_by(night_start) %>%
    summarise(mean_msas = mean(msas, na.rm = TRUE)) %>%
    ungroup()
  
  return(nightly_stats)
}

# Function to plot the histogram of the number of nights per mean MSAS value by month
plot_histogram <- function(df_nightly_stats) {
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
  
  # Plot the histogram of the processed data
  plot_histogram(processed_data)
}

main(photometer_id)

