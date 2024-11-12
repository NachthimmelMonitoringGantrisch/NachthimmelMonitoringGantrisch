# Load required libraries
library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)
library(tidyr)

# Path to the SQLite database
db_tess_data_path <- normalizePath(file.path("..", "..", "data", "tess_data.db"), mustWork = FALSE)

# Function to load data for the specified photometer, selecting only necessary columns
load_data_from_database <- function(photometer_id) {
  if (!file.exists(db_tess_data_path)) {
    stop(paste("Database not found at path:", db_tess_data_path))
  }
  
  conn <- dbConnect(RSQLite::SQLite(), db_tess_data_path)
  table_name <- paste0(photometer_id, "_data")
  query <- paste("SELECT time, msas, sky_temperature, sun_alt, moon_illumination FROM", table_name)
  df <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  
  if (nrow(df) == 0) {
    stop(paste("No data found for photometer:", photometer_id))
  }
  
  return(df)
}

# Function to process the data for the required yearly counts
process_night_data <- function(df) {
  df <- df %>%
    mutate(
      time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      night_id = as.integer(difftime(time, as.POSIXct("1970-01-01 20:00:00", tz = "UTC"), units = "days")) +
        ifelse(hour(time) < 9, -1, 0)
    ) %>%
    filter(sun_alt <= -18, sky_temperature < 0, moon_illumination <= 0.2)
  
  # Group by night_id and calculate max_msas per night, and % of readings with sky_temperature < 0 per night
  night_stats <- df %>%
    group_by(night_id) %>%
    summarise(
      max_msas = max(msas, na.rm = TRUE),
      sky_temp_below_zero_pct = mean(sky_temperature < 0, na.rm = TRUE)
    ) %>%
    ungroup()
  
  # Calculate counts per year
  yearly_counts <- df %>%
    mutate(year = year(time)) %>%
    group_by(year) %>%
    summarise(
      nights_over_21_3 = sum(night_stats$max_msas > 21.3, na.rm = TRUE),  # Count nights with max_msas > 21.3
      nights_cold = sum(night_stats$sky_temp_below_zero_pct >= 0.9, na.rm = TRUE)  # Count nights with 90% of sky_temperature < 0
    )
  
  return(yearly_counts)
}

# Function to plot the data
plot_yearly_counts <- function(yearly_counts, filtered_data) {
  # Ensure filtered_data$time is converted to POSIXct to handle any string or empty values
  filtered_data <- filtered_data %>%
    mutate(time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")) %>%
    filter(!is.na(time))
  
  # Check if there's any data to display and create subtitle accordingly
  if (nrow(filtered_data) > 0) {
    date_range <- range(filtered_data$time, na.rm = TRUE)
    subtitle_text <- paste("Daten von", format(date_range[1], "%Y-%m-%d"), "bis", format(date_range[2], "%Y-%m-%d"))
  } else {
    subtitle_text <- "Keine Daten für die gewählten Kriterien vorhanden"
  }
  
  # Convert data to long format for plotting two bars per year
  yearly_counts_long <- yearly_counts %>%
    pivot_longer(cols = c(nights_over_21_3, nights_cold), names_to = "condition", values_to = "count") %>%
    mutate(condition = recode(condition, "nights_over_21_3" = "Nights with max MSAS > 21.3", 
                              "nights_cold" = "Nights with 90% of sky temp < 0"))
  
  ggplot(yearly_counts_long, aes(x = factor(year), y = count, fill = condition)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.5), width = 0.3) +  # Thinner bars
    labs(
      title = "Yearly Counts of Nights by Condition",
      subtitle = subtitle_text,  # Add the generated subtitle with exact dates
      x = "Year",
      y = "Number of Nights",
      fill = "Condition"
    ) +
    scale_y_continuous(limits = c(0, 366), breaks = seq(0, 366, by = 50)) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 0, hjust = 0.5),
      plot.title = element_text(size = 16),
      plot.subtitle = element_text(size = 12, color = "gray"),
      axis.title = element_text(size = 12)
    ) +
    scale_fill_manual(values = c("#7A4EA3", "#C88719"))  # Dark pastel violet and orange
}

# Main function to run the analysis
main <- function(photometer_id) {
  data <- load_data_from_database(photometer_id)
  yearly_counts <- process_night_data(data)
  plot_yearly_counts(yearly_counts, data)  # Pass the full data to calculate the date range
}