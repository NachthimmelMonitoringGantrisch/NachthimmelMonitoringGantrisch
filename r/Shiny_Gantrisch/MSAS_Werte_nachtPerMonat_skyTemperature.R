library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)
library(gridExtra)

# Path to the SQLite database
db_tess_data_path <- normalizePath(file.path("..", "..", "data", "tess_data.db"), mustWork = FALSE)

# Function to load data from the database
load_data_from_database <- function(photometer_id) {
  if (!file.exists(db_tess_data_path)) {
    stop(paste("Database not found at path:", db_tess_data_path))
  }
  
  conn <- dbConnect(RSQLite::SQLite(), db_tess_data_path)
  table_name <- paste0(photometer_id, "_data")
  query <- paste("SELECT time, msas, sun_alt, sky_temperature FROM", table_name)
  df <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  
  if (nrow(df) == 0) {
    stop(paste("No data found for photometer:", photometer_id))
  }
  
  df <- df %>%
    mutate(
      time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
    ) %>%
    filter(!is.na(time), !is.na(msas), msas > 0)
  
  return(df)
}

# Function to convert the time column to POSIXct format
convert_time_column <- function(data, time_column_name) {
  data <- data %>% 
    mutate(!!time_column_name := as.POSIXct(.data[[time_column_name]], 
                                            format = "%Y-%m-%d %H:%M:%S", 
                                            tz = "UTC"))
  return(data)
}

# Function to filter invalid or missing data
filter_valid_data <- function(data, time_column_name, msas_column_name) {
  data <- data %>%
    filter(!is.na(.data[[time_column_name]]), 
           !is.na(.data[[msas_column_name]]), 
           .data[[msas_column_name]] > 0)
  return(data)
}

# Function to define the Bortle scale as a data frame
define_bortle_scale <- function() {
  bortle_scale <- data.frame(
    min_msas = c(21.90, 21.50, 21.30, 20.80, 20.10, 19.10, 18.00, -Inf),
    max_msas = c(Inf, 21.90, 21.50, 21.30, 20.80, 20.10, 19.10, 18.00),
    color = c("#2E2E2E", "#404040", "#0000FF", "#00FF00", "#FFFF00", 
              "#FFA500", "#FF0000", "#FFFFFF"),
    bortle_class = c("1", "2", "3", "4", "4.5", "5", "6-7", "8-9")
  )
  return(bortle_scale)
}

# Function to create the plot for a specific night
create_night_plot <- function(df, year, month, day, bortle_scale) {
  # Define start datetime for the night (4 PM on the current day)
  start_datetime <- ymd_hms(paste(year, month, sprintf("%02d", day), "16:00:00"), tz = "UTC")
  
  # Handle case for the last day of the month
  if (day == days_in_month(ymd(paste(year, month, "01")))) {
    end_datetime <- ymd_hms(paste(year, month, sprintf("%02d", day), "23:59:59"), tz = "UTC") + hours(9)
  } else {
    end_datetime <- ymd_hms(paste(year, month, sprintf("%02d", day + 1), "09:00:00"), tz = "UTC")
  }
  
  # Filter data for the specific night
  df_night <- df %>%
    filter(time >= start_datetime, time <= end_datetime)
  
  if (nrow(df_night) == 0) {
    return(NULL)
  }
  
  # Identify periods of astronomical night
  night_intervals <- df_night %>%
    filter(sun_alt <= -18) %>%
    summarise(
      start_night = min(time),
      end_night = max(time),
      .groups = "drop"
    )
  
  # Filter for sky temperature below 0°C and create groups by continuous intervals
  df_night <- df_night %>%
    mutate(temp_below_zero = ifelse(sky_temperature < 0, 1, 0)) %>%
    arrange(time) %>%
    mutate(below_zero_group = cumsum(c(0, diff(temp_below_zero) != 0)))
  
  df_grouped <- df_night %>%
    group_by(below_zero_group) %>%
    summarise(
      start_time = min(time[temp_below_zero == 1], na.rm = TRUE),
      end_time = max(time[temp_below_zero == 1], na.rm = TRUE),
      duration = as.numeric(difftime(max(time[temp_below_zero == 1], na.rm = TRUE), min(time[temp_below_zero == 1], na.rm = TRUE), units = "mins")),
      .groups = "drop"
    ) %>%
    filter(duration >= 30)  # Keep only intervals with duration >= 30 minutes
  
  # Create the plot
  p <- ggplot() +
    # Bortle scale background
    geom_rect(data = bortle_scale, aes(xmin = start_datetime, xmax = end_datetime, ymin = min_msas, ymax = max_msas, fill = bortle_class), 
              alpha = 0.1, inherit.aes = FALSE) +
    scale_fill_manual(
      values = bortle_scale$color,
      name = "Bortle Class",
      labels = bortle_scale$bortle_class
    ) +
    # Add dotted lines for astronomical night start and end
    geom_vline(data = night_intervals, aes(xintercept = as.numeric(start_night)), color = "black", linetype = "dotted", size = 1) +
    geom_vline(data = night_intervals, aes(xintercept = as.numeric(end_night)), color = "black", linetype = "dotted", size = 1) +
    # Add green bars for below-zero temperature intervals
    {if (nrow(df_grouped) > 0) {
      geom_rect(data = df_grouped, aes(xmin = start_time, xmax = end_time), ymin = 14, ymax = 15, fill = "green", alpha = 0.7)
    }} +
    # MSAS line (drawn on top of the bars)
    geom_line(data = df_night, aes(x = time, y = msas), color = "black", size = 1) +
    # Add reference line for MSAS target value (21.3)
    geom_hline(yintercept = 21.3, color = "red", linetype = "dashed", size = 1) +
    # Axis settings
    scale_x_datetime(
      limits = c(start_datetime, end_datetime),
      breaks = seq(start_datetime, end_datetime, by = "3 hours"),
      date_labels = "%H:%M"
    ) +
    scale_y_continuous(
      name = "MSAS [mag/arcsec²]",
      limits = c(15, 26),  # Start MSAS values from 15
      breaks = seq(15, 26, by = 2)
    ) +
    # Title and theme
    labs(
      title = paste("MSAS for", sprintf("%02d", day), month.abb[month], year),
      x = "Time",
      y = "MSAS [mag/arcsec²]"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(size = 7, angle = 90, hjust = 1),
      axis.text.y = element_text(size = 7),
      axis.title.x = element_text(size = 9),
      axis.title.y = element_text(size = 9),
      plot.title = element_text(size = 10, hjust = 0.5),
      legend.position = "none",
      plot.margin = margin(2, 2, 2, 2)
    )
  
  return(p)
}


# Function to plot all nights for a given month
plot_all_nights <- function(df, year, month) {
  bortle_scale <- define_bortle_scale()  # Define Bortle scale once
  
  days_in_month <- days_in_month(ymd(paste(year, month, "01")))
  
  plots <- lapply(1:days_in_month, function(day) {
    create_night_plot(df, year, month, day, bortle_scale)  # Pass Bortle scale
  })
  
  plots <- Filter(Negate(is.null), plots)
  
  if (length(plots) == 0) {
    stop("No data available for the selected month.")
  }
  
  grid.arrange(grobs = plots, ncol = 5)
}

# Main function to run the analysis
main <- function(photometer_id, input_year, input_month) {
  df <- load_data_from_database(photometer_id)
  plot_all_nights(df, input_year, input_month)
}
