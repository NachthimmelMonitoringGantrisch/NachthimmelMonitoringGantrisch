# Load required libraries
library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)
library(gridExtra)

# Path to the SQLite database
db_tess_data_path <- normalizePath(file.path("..", "..", "data", "tess_data.db"), mustWork = FALSE)

# Load data from the SQLite database for the specified photometer
load_data_from_database <- function(photometer_id) {
  if (!file.exists(db_tess_data_path)) {
    stop(paste("Database not found at path:", db_tess_data_path))
  }
  
  conn <- dbConnect(RSQLite::SQLite(), db_tess_data_path)
  table_name <- paste0(photometer_id, "_data")
  query <- paste("SELECT * FROM", table_name)
  df <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  
  if (nrow(df) == 0) {
    stop(paste("No data found for photometer:", photometer_id))
  }
  
  return(df)
}

# Function to calculate total time per night based on provided photometer, date range, and msas threshold
calculate_total_time_per_night <- function(data, xmin_date, xmax_date, msas_threshold = 21.3, time_diff_threshold = 200) {
 
  # Ensure the 'time' column is in the correct datetime format
  data <- data %>%
    mutate(time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")) %>%
    arrange(time)  # Ensure data is sorted by time
  
  # Calculate time difference in seconds between consecutive entries and remove rows where time_diff_next exceeds the threshold (e.g., 200 seconds)
  data <- data %>%
    mutate(time_diff_next = c(as.numeric(difftime(time[-1], time[-n()], units = "secs")), NA)) %>%
    filter(is.na(time_diff_next) | time_diff_next <= time_diff_threshold)

  # Filter out rows where msas is less than the threshold
  data_filtered <- data %>%
    filter(msas >= msas_threshold)
  
  # Filter the data for the specified date range
  data_filtered_range <- data_filtered %>%
    filter(as.Date(time) >= xmin_date & as.Date(time) <= xmax_date)
  
  # Create a new 'night' grouping variable by using floor_date to group by midnight (12:00 AM)
  data_filtered_range <- data_filtered_range %>%
    mutate(night = floor_date(time, "day"))  # Group by each night starting from 12:00 AM
  
  # Summarize total time per night
  data_night_summary <- data_filtered_range %>%
    group_by(night) %>%  # Group by night
    summarise(total_time_sec = sum(time_diff_next, na.rm = TRUE))  # Sum the time differences for each night
  
  # Convert total time from seconds to hours for better readability
  data_night_summary$total_time_hours <- data_night_summary$total_time_sec / 3600
  
  return(data_night_summary)
}

# Process data function
process_data <- function(df, month) {
  parsed_date <- ym(month)
  selected_year <- year(parsed_date)
  selected_month <- month(parsed_date)

  df <- df %>%
    mutate(
      time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      night_id = as.integer(difftime(time, as.POSIXct("1970-01-01 20:00:00", tz = "UTC"), units = "days")) +
        ifelse(hour(time) < 9, -1, 0)
    ) %>%
    filter(
      sun_alt <= -18,
      year(time) == selected_year,
      month(time) == selected_month,
      msas > 0
    )

  df_night_stats <- df %>%
    group_by(night_id) %>%
    summarise(
      date = as.Date(min(time)),
      min_msas = min(msas, na.rm = TRUE),
      max_msas = max(msas, na.rm = TRUE)
    ) %>%
    ungroup()

  return(df_night_stats)
}

plot_bar <- function(data_night_summary) {
  ggplot(data_night_summary, aes(x = night, y = total_time_hours)) +
    geom_bar(stat = "identity", fill = "steelblue") +  # Bar plot with custom color
    labs(title = "Total Time per Night", y = "Total Time (hours)", x = NULL) +  # Remove x-axis label
    theme_minimal() +  # Minimal theme for clarity
    theme(axis.text.x = element_blank())  # Remove x-axis labels
}

plot_line <- function(data, xmin_date, xmax_date) {
  data_filtered <- data %>%
    mutate(time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")) %>%
    arrange(time)  # Ensure data is sorted by time

  # Now apply the date filter using the start and end date
  data_filtered <- data_filtered %>%
    filter(time >= xmin_date & time <= xmax_date)

  # Create a full sequence of time from the first to the last time in your data, with an hourly frequency
  full_time_range <- seq(from = min(data_filtered$time), to = max(data_filtered$time), by = "hour")

  # Merge the full time range with the data
  data_full <- data.frame(time = full_time_range) %>%
    left_join(data_filtered, by = "time")

  ggplot(data_filtered, aes(x = time, y = moon_illumination)) +
    geom_line(color = "red") +  # Line plot with red color
    labs(x = "Time", y = NULL) +  # Remove the y-axis label
    theme_minimal() +  # Minimal theme for clarity
    scale_y_continuous(limits = c(0, 1), breaks = c(0, 1)) +  # Set y-axis breaks to only 0 and 1
    scale_x_datetime(date_labels = "%b %d", date_breaks = "1 day") +  # Format x-axis to show date labels
    theme(axis.text.x = element_text(angle = 90, hjust = 1))  # Rotate x-axis labels for better readability
}

# Main function to run the analysis
main <- function(photometer_id, month) {
  data <- load_data_from_database(photometer_id)
  
  # Process the data for the selected month
  yearly_counts <- process_data(data, month)
  
  # Calculate xmin_date and xmax_date for the selected month
  xmin_date <- min(yearly_counts$date)
  xmax_date <- max(yearly_counts$date)

  data_night_summary <- calculate_total_time_per_night(data, xmin_date, xmax_date)

  p1 <- plot_bar(data_night_summary)
  p2 <- plot_line(data, xmin_date, xmax_date)

  grid.arrange(p1, p2, ncol = 1, heights = c(7, 2))
}