# Load required libraries
library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)

# Path to the SQLite database
db_tess_data_path <- normalizePath(file.path("..", "..", "data", "tess_data.db"), mustWork = FALSE)

# Load data from the SQLite database for the specified photometer
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

process_data <- function(df, month) {
  # Parse the input month and extract year and month
  parsed_date <- ym(month)  # Parse "YYYY-MM" to a date
  selected_year <- year(parsed_date)
  selected_month <- month(parsed_date)

  df <- df %>%
    mutate(
      time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      night_id = as.integer(difftime(time, as.POSIXct("1970-01-01 20:00:00", tz = "UTC"), units = "days")) +
        ifelse(hour(time) < 9, -1, 0)
    ) %>%
    filter(
      sun_alt <= -18,         # Filter for sun_alt based on variable
      year(time) == selected_year,      # Filter for the selected year
      month(time) == selected_month,    # Filter for the selected month
      msas > 0            # Exclude values below the minimum MSAS
    )

  # Group by night_id and calculate min and max msas for each night
  df_night_stats <- df %>%
    group_by(night_id) %>%
    summarise(
      date = as.Date(min(time)),           # Use the minimum time for the date
      min_msas = min(msas, na.rm = TRUE),  # Minimum MSAS for the night
      max_msas = max(msas, na.rm = TRUE)   # Maximum MSAS for the night
    ) %>%
    ungroup()

  return(df_night_stats)
}

plot_month <- function(df_night_stats, month) {
  # Parse the input month to get a formatted string for the title
  parsed_date <- ym(month)
  plot_title <- paste("Min und Max MSAS pro Nacht -", month.name[month(parsed_date)], year(parsed_date))
  
  # Define Bortle scale colors and MSAS ranges
  bortle_scale <- data.frame(
    min_msas = c(21.90, 21.50, 21.30, 20.80, 20.10, 19.10, 18.00, -Inf),
    max_msas = c(Inf, 21.90, 21.50, 21.30, 20.80, 20.10, 19.10, 18.00),
    color = c("#2E2E2E", "#404040", "#0000FF", "#00FF00", "#FFFF00", "#FFA500", "#FF0000", "#FFFFFF"),
    bortle_class = c("1", "2", "3", "4", "4.5", "5", "6-7", "8-9")
  )

  # Define the date range for the plot
  xmin_date <- min(df_night_stats$date)
  xmax_date <- max(df_night_stats$date)

  # Plot min and max msas values for each night in the specified month
  ggplot(df_night_stats, aes(x = date)) +
    # Add Bortle scale as background colors
    geom_rect(data = bortle_scale, aes(xmin = xmin_date, xmax = xmax_date, ymin = min_msas, ymax = max_msas, fill = bortle_class), 
              alpha = 0.1, inherit.aes = FALSE) +
    scale_fill_manual(
      values = bortle_scale$color,
      name = "Bortle Class",
      labels = bortle_scale$bortle_class
    ) +
    geom_line(aes(y = min_msas, color = "Min MSAS"), size = 1) +
    geom_line(aes(y = max_msas, color = "Max MSAS"), size = 1) +
    geom_hline(yintercept = 21.3, linetype = "dashed", color = "red", size = 0.8) +  # Reference line for MSAS limit
    labs(
      title = plot_title,
      x = "Datum [Tag]",
      y = "MSAS [mag/arcsec²]",
      color = "MSAS Value"
    ) +
    scale_y_continuous(limits = c(15, 24), breaks = seq(15, 24, by = 0.5)) +  # Set y-axis limits from 15 to 24 with 0.5 breaks
    scale_x_date(breaks = seq(xmin_date, xmax_date, by = "1 day"), date_labels = "%d") +  # Label every day on x-axis
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 90, hjust = 1)  # Rotate x-axis labels to 90 degrees
    )
}

# Main function to run the analysis
main <- function(photometer_id, month) {
  data <- load_data_from_database(photometer_id)
  yearly_counts <- process_data(data, month)
  plot_month(yearly_counts, month)
}