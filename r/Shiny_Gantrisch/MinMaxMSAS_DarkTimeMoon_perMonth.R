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
  query <- paste("SELECT time, msas, sun_alt, moon_illumination, night_id FROM", table_name)
  df <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  
  if (nrow(df) == 0) {
    stop(paste("No data found for photometer:", photometer_id))
  }
  
  return(df)
}

# Function to calculate total time per night based on provided photometer, date range, and msas threshold
calculate_total_time_per_night <- function(data, xmin_date, xmax_date, msas_threshold = 21.3, time_diff_threshold = 200) {
  data <- data %>%
    mutate(time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%OS")) %>%  
    arrange(time)  
  
  data <- data %>%
    mutate(time_diff_next = c(as.numeric(difftime(time[-1], time[-n()], units = "secs")), NA)) %>%
    filter(is.na(time_diff_next) | time_diff_next <= time_diff_threshold)
  
  data_filtered <- data %>%
    filter(msas >= msas_threshold)
  
  data_filtered_range <- data_filtered %>%
    filter(as.Date(time) >= xmin_date & as.Date(time) <= xmax_date)
  
  data_night_summary <- data_filtered_range %>%
    group_by(night_id) %>%  
    summarise(total_time_sec = sum(time_diff_next, na.rm = TRUE))  
  
  data_night_summary$total_time_hours <- data_night_summary$total_time_sec / 3600
  
  return(data_night_summary)
}

process_data <- function(df, month) {
  parsed_date <- ym(month)  
  selected_year <- year(parsed_date)
  selected_month <- month(parsed_date)
  
  df <- df %>%
    mutate(
      time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S")  
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

plot_month <- function(df_night_stats, month) {
  bortle_scale <- data.frame(
    min_msas = c(21.90, 21.50, 21.30, 20.80, 20.10, 19.10, 18.00, -Inf),
    max_msas = c(Inf, 21.90, 21.50, 21.30, 20.80, 20.10, 19.10, 18.00),
    color = c("#2E2E2E", "#404040", "#0000FF", "#00FF00", "#FFFF00", "#FFA500", "#FF0000", "#FFFFFF"),
    bortle_class = c("1", "2", "3", "4", "4.5", "5", "6-7", "8-9")
  )
  
  parsed_date <- ym(month)
  xmin_date <- floor_date(as.Date(parsed_date), "month")
  xmax_date <- ceiling_date(as.Date(parsed_date), "month") - 1
  
  p1 <- ggplot(df_night_stats, aes(x = date)) +
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
    labs(x = NULL, y = "MSAS [mag/arcsec²]", color = "MSAS Werte") +
    scale_y_continuous(limits = c(15, 24), breaks = seq(15, 24, by = 1)) +
    scale_x_date(limits = c(xmin_date, xmax_date), breaks = seq(xmin_date, xmax_date, by = "1 day")) +
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

plot_bar <- function(data_night_summary, month) {
  parsed_date <- ym(month)
  xmin_date <- floor_date(as.Date(parsed_date), "month")
  xmax_date <- ceiling_date(as.Date(parsed_date), "month") - 1
  
  # Convert night_id to start and end dates
  data_night_summary <- data_night_summary %>%
    mutate(
      start_date = as.Date(substr(night_id, 2, 9), "%Y%m%d"),
      end_date = start_date + 1
    )
  
  # Create the bar plot with fixed x-axis range for the month
  p2 <- ggplot(data_night_summary, aes(xmin = start_date, xmax = end_date, ymin = 0, ymax = total_time_hours)) +
    geom_rect(fill = "#8a8a8a", color = "black", alpha = 0.8) +
    scale_x_date(limits = c(xmin_date, xmax_date), breaks = seq(xmin_date, xmax_date, by = "1 day")) +
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
    )
  
  return(p2)
}

plot_line <- function(data, month) {
  parsed_date <- ym(month)  # Parse the input month
  xmin_date <- floor_date(as.Date(parsed_date), "month")
  xmax_date <- ceiling_date(as.Date(parsed_date), "month") - 1
  
  data_filtered <- data %>%
    mutate(time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")) %>%
    filter(time >= xmin_date & time <= xmax_date)
  
  p3 <- ggplot(data_filtered, aes(x = time, y = moon_illumination, color = moon_illumination)) +
    geom_line(color = "#8a8a8a", size = 1.2) +
    labs(
      x = "Tag",
      y = "Mondphase"
    ) +
    scale_x_datetime(
      limits = c(as.POSIXct(xmin_date), as.POSIXct(xmax_date)),
      date_labels = "%b %d",
      date_breaks = "1 day"
    ) +
    scale_y_continuous(limits = c(0, 1), breaks = c(0, 1)) +
    theme_minimal() +
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
  xmin_date <- floor_date(as.Date(ym(month)), "month")
  xmax_date <- ceiling_date(as.Date(ym(month)), "month") - 1

  data_night_summary <- calculate_total_time_per_night(data, xmin_date, xmax_date + 1)

  p1 <- plot_month(yearly_counts, month)
  p2 <- plot_bar(data_night_summary, month)
  p3 <- plot_line(data, month)
  
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