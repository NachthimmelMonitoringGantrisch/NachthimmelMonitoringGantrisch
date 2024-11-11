library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)

# Path to the SQLite database
db_tess_data_path <- normalizePath(file.path("..", "..", "data", "tess_data.db"), mustWork = FALSE)

# Function to load only necessary data from the SQLite database for a specific photometer
load_data_from_database <- function(photometer_id) {
  if (!file.exists(db_tess_data_path)) {
    stop(paste("Database not found at path:", db_tess_data_path))
  }
  
  conn <- dbConnect(RSQLite::SQLite(), db_tess_data_path)
  table_name <- paste0(photometer_id, "_data")
  query <- paste("SELECT time, msas, sun_alt FROM", table_name) # Added sun_alt column
  df <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  
  if (nrow(df) == 0) {
    stop(paste("No data found for photometer:", photometer_id))
  }
  
  return(df)
}

# Preprocess the data to calculate mean MSAS per night based on night_id
preprocess_data <- function(df) {
  df <- df %>%
    filter(!is.na(time), !is.na(msas), !is.na(sun_alt)) %>%
    mutate(time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))
  
  # Filter for nighttime hours and create a night_id
  df <- df %>%
    filter(hour(time) >= 20 | hour(time) < 5) %>%
    mutate(
      night_id = as.integer(difftime(time, as.POSIXct("1970-01-01 20:00:00", tz = "UTC"), units = "days")) + 
        ifelse(hour(time) < 5, -1, 0)
    ) %>%
    filter(sun_alt < -18)  # Additional filter for sun_alt < -18
  
  # Group by "night_id" and calculate mean MSAS for each night, while handling potential NA values
  df_nightly_stats <- df %>%
    group_by(night_id) %>%
    summarise(
      mean_msas = mean(msas, na.rm = TRUE),
      night_date = as.Date(min(time))
    ) %>%
    filter(!is.na(mean_msas)) %>%
    ungroup()
  
  return(df_nightly_stats)
}

plot_histogram <- function(df_nightly_stats) {
  # Extract available years from the unfiltered dataset
  available_years <- df_nightly_stats %>%
    mutate(year = year(night_date)) %>%
    pull(year) %>%
    unique()
  
  # Filter for nights with mean MSAS over 21.3, extract month and year from night_date
  df_nightly_stats <- df_nightly_stats %>%
    filter(mean_msas > 21.3) %>%
    mutate(
      month = month(night_date, label = TRUE, abbr = TRUE),
      year = year(night_date)
    )
  
  # Check if there is data after filtering
  if (nrow(df_nightly_stats) == 0) {
    # Create a dummy dataset for each month in each available year
    df_empty <- expand.grid(
      month = factor(month.abb, levels = month.abb),
      year = available_years
    )
    
    ggplot(df_empty, aes(x = month)) +
      geom_blank() +
      labs(
        title = "Nights with Mean MSAS > 21.3 per Month",
        subtitle = "No nights found with mean MSAS > 21.3",
        x = "Month", y = "Number of Nights"
      ) +
      scale_x_discrete(limits = month.abb) +
      scale_y_continuous(limits = c(0, 31)) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        strip.text = element_text(size = 12, face = "bold"),
        panel.spacing = unit(1, "lines")
      ) +
      facet_wrap(~ year, ncol = 2)
  } else {
    # Calculate the data timespan for the subtitle
    date_range <- range(df_nightly_stats$night_date, na.rm = TRUE)
    subtitle_text <- paste("Data from", format(date_range[1], "%Y-%m-%d"), "to", format(date_range[2], "%Y-%m-%d"))
    
    ggplot(df_nightly_stats, aes(x = month)) +
      geom_bar(stat = "count", fill = "steelblue", show.legend = FALSE) +
      labs(
        title = "Nights with Mean MSAS > 21.3 per Month",
        subtitle = subtitle_text,  # Display timespan of data
        x = "Month", y = "Number of Nights"
      ) +
      scale_x_discrete(limits = month.abb) +
      scale_y_continuous(limits = c(0, 31)) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        strip.text = element_text(size = 12, face = "bold"),
        panel.spacing = unit(1, "lines")
      ) +
      facet_wrap(~ year, ncol = 2)
  }
}

# Main function to run the analysis
main <- function(photometer_id) {
  data <- load_data_from_database(photometer_id)
  processed_data <- preprocess_data(data)
  plot_histogram(processed_data)
}
