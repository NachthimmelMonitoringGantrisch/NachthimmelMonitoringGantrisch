# Load required libraries
library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)
library(gridExtra)
library(cowplot)
library(patchwork)

# Path to the SQLite database
db_tess_data_path <- normalizePath(file.path("..", "..", "data", "TessNetwork_data.db"), mustWork = FALSE)

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
  p1 <- ggplot(df_night_stats, aes(x = date)) +
    # Add Bortle scale as background colors
    geom_rect(data = bortle_scale, aes(xmin = xmin_date, xmax = xmax_date, ymin = min_msas, ymax = max_msas, fill = bortle_class), 
              alpha = 0.1, inherit.aes = FALSE) +
    scale_fill_manual(
      values = bortle_scale$color,
      name = "Bortle-Skala",
      labels = bortle_scale$bortle_class
    ) +
    geom_hline(yintercept = 21.3, linetype = "dashed", color = "red", size = 0.8) + 
    geom_line(aes(y = min_msas, color = "Min"), size = 1.2) +
    geom_line(aes(y = max_msas, color = "Max"), size = 1.2) +
    annotate("text", x = xmax_date, y = 21.3, label = "MSAS 21.3 Grenze", color = "red", hjust = 0.8, vjust = -1.5, size = 4) +
    labs(
      x = NULL,
      y = "MSAS [mag/arcsec²]",
      color = "MSAS Werte"
    ) +
    scale_y_continuous(limits = c(15, 24), breaks = seq(15, 24, by = 1)) +
    scale_x_date(breaks = seq(xmin_date, xmax_date, by = "1 day")) +
    theme_minimal() +
    theme(
      axis.text.x = element_blank(),
      axis.title.x = element_blank(),
      panel.grid.minor.x = element_line(color = "lightgrey", size = 0.5),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(color = "lightgrey", size = 0.5),
      panel.grid.minor.y = element_line(color = "lightgrey", size = 0.5),
      legend.position = "top"
    ) +
    scale_color_manual(values = c("Min" = "steelblue", "Max" = "orange"))
  
  return(p1)
}

plot_bar <- function(data_night_summary) {
  p2 <- ggplot(data_night_summary, aes(x = night, y = total_time_hours)) +
    geom_bar(stat = "identity", fill = "#8a8a8a") +
    labs(
      title = NULL,
      y = "Zeittotal MSAS > 21.3 [h]",
      x = NULL
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_blank(),
      axis.title.x = element_blank(),
      axis.ticks.x = element_blank(),
      panel.grid.major.x = element_line(color = "lightgrey", size = 0.5),
      panel.grid.minor.x = element_blank(),
      panel.grid.major.y = element_line(color = "lightgrey", size = 0.5),
      panel.grid.minor.y = element_blank()
    ) +
    scale_x_datetime(date_labels = "%b %d", date_breaks = "1 day")
  
  return(p2)
}

plot_line <- function(data, xmin_date, xmax_date) {
  data_filtered <- data %>%
    mutate(time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")) %>%
    filter(time >= xmin_date & time <= xmax_date)

  p3 <- ggplot(data_filtered, aes(x = time, y = moon_illumination, color = moon_illumination)) +
    geom_line(color = "#8a8a8a", size = 1.2) +
    labs(
      x = "Tag",
      y = "Mondphase"
    ) +
    theme_minimal() +
    scale_y_continuous(limits = c(0, 1), breaks = c(0, 1)) +
    scale_x_datetime(date_labels = "%b %d", date_breaks = "1 day") +
    theme(
      axis.text.x = element_text(angle = 90, hjust = 0.5, vjust = 0.5),
      panel.grid.minor.x = element_line(color = "lightgrey", size = 0.5),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(color = "lightgrey", size = 0.5),
      panel.grid.minor.y = element_blank()
    )

  return(p3)
}

main <- function(photometer_id, month) {
  data <- load_data_from_database(photometer_id)
  
  # Process the data for the selected month
  yearly_counts <- process_data(data, month)
  
  # Calculate xmin_date and xmax_date for the selected month
  xmin_date <- min(yearly_counts$date)
  xmax_date <- max(yearly_counts$date)

  data_night_summary <- calculate_total_time_per_night(data, xmin_date, xmax_date + 1)

  p1 <- plot_month(yearly_counts, month)
  p2 <- plot_bar(data_night_summary)
  p3 <- plot_line(data, xmin_date, xmax_date)
  
  # Parse the input month to get a formatted string for the title
  parsed_date <- ym(month)
  plot_title <- paste("Analyse", month.name[month(parsed_date)], year(parsed_date))

  # Use patchwork for alignment
  final_plot <- p1 / p2 / p3 + 
    plot_layout(heights = c(4, 2, 1)) + 
    plot_annotation(title = plot_title, 
                  subtitle = "1. Grafik: Min und Max MSAS pro Nacht\n2. Grafik: Zeittotal MSAS > 21.3 pro Nacht\n3. Grafik: Mondphase wärend des Monats",
                  theme = theme(
                    plot.title = element_text(face = "bold", size = 14),
                    plot.subtitle = element_text(size = 14))
                  )
  
  print(final_plot)
}