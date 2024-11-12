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
  query <- paste("SELECT time, msas, sun_alt FROM", table_name)
  df <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  
  if (nrow(df) == 0) {
    stop(paste("No data found for photometer:", photometer_id))
  }
  
  return(df)
}

# Function to process the data to count nights with max_msas > 21.3
process_night_data <- function(df) {
  # Define night_id based on time and day boundaries
  df <- df %>%
    mutate(
      time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      night_id = as.integer(difftime(time, as.POSIXct("1970-01-01 20:00:00", tz = "UTC"), units = "days")) +
        ifelse(hour(time) < 5, -1, 0)
    )
  
  # Filter by sun_alt <= -18 and calculate max_msas per night_id
  result <- df %>%
    filter(sun_alt <= -18) %>%                       # Filter for sun_alt <= -18
    group_by(night_id) %>%                           # Group by night_id
    summarise(max_msas = max(msas, na.rm = TRUE)) %>% # Calculate max msas per night
    filter(max_msas > 21.3) %>%                      # Filter for max_msas > 21.3
    summarise(nights_over_21_3 = n())                # Count the number of nights
  
  return(result$nights_over_21_3)
}

# Function to plot the histogram of nights with max_msas > 21.3
# Function to plot the histogram of nights with max_msas > 21.3
plot_histogram <- function(df_nightly_stats) {
  # Group by night_id to calculate the max MSAS per night
  df_nightly_stats <- df_nightly_stats %>%
    mutate(
      time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      night_id = as.integer(difftime(time, as.POSIXct("1970-01-01 20:00:00", tz = "UTC"), units = "days")) +
        ifelse(hour(time) < 5, -1, 0)
    ) %>%
    filter(sun_alt <= -18) %>%                       # Filter for sun_alt <= -18
    group_by(night_id) %>%
    summarise(max_msas = max(msas, na.rm = TRUE), night_date = as.Date(min(time))) %>%
    filter(max_msas > 21.3) %>%
    mutate(
      month = month(night_date, label = TRUE, abbr = TRUE),
      year = year(night_date)
    )
  
  # Plot the histogram, checking if there’s any data to plot
  if (nrow(df_nightly_stats) == 0) {
    ggplot(data.frame(month = factor(month.abb, levels = month.abb)), aes(x = month)) +
      geom_blank() +
      labs(
        title = "Nights with Max MSAS > 21.3 per Month",
        x = "Month", y = "Number of Nights"
      ) +
      scale_y_continuous(limits = c(0, 31)) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        strip.text = element_text(size = 12, face = "bold"),
        panel.spacing = unit(1, "lines")
      ) +
      annotate("text", x = 6.5, y = 15, label = "No nights found with max MSAS > 21.3", color = "red", size = 5, fontface = "bold")
  } else {
    ggplot(df_nightly_stats, aes(x = month)) +
      geom_bar(stat = "count", fill = "steelblue", show.legend = FALSE) +
      labs(
        title = "Nights with Max MSAS > 21.3 per Month",
        x = "Month", y = "Number of Nights"
      ) +
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
  nights_count <- process_night_data(data)
  plot_histogram(data)
}

