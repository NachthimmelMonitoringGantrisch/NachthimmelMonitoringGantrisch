library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)
library(tidyr)
library(gridExtra)

# Path to the SQLite database
db_tess_data_path <- normalizePath(file.path("..", "..", "data", "TessNetwork_data.db"), mustWork = FALSE)

# Function to load data for the specified photometer, selecting only necessary columns
load_data_from_database <- function(photometer_id) {
  if (!file.exists(db_tess_data_path)) {
    stop(paste("Datenbank nicht gefunden unter Pfad:", db_tess_data_path))
  }
  
  conn <- dbConnect(RSQLite::SQLite(), db_tess_data_path)
  table_name <- paste0(photometer_id, "_data")
  query <- paste("SELECT time, msas, sky_temperature, moon_illumination, night_id, astronomical_night FROM", table_name)
  df <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  
  if (nrow(df) == 0) {
    stop(paste("Keine Daten gefunden für Photometer:", photometer_id))
  }
  
  return(df)
}

# Function to process the data for the required yearly counts
process_night_data <- function(df) {
  df <- df %>%
    filter(astronomical_night == 1, sky_temperature < 0, moon_illumination < 0.3) %>%
    mutate(
      year = year(as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))
    )
  
  # Ensure all years in the data are represented
  all_years <- tibble(year = unique(year(df$time)))
  
  night_stats <- df %>%
    group_by(year, night_id) %>%
    summarise(
      max_msas = max(msas, na.rm = TRUE),
      sky_temp_below_zero_pct = mean(sky_temperature < 0, na.rm = TRUE),
      .groups = 'drop'
    )
  
  yearly_counts <- night_stats %>%
    group_by(year) %>%
    summarise(
      nights_over_21_3 = sum(max_msas > 21.3, na.rm = TRUE),
      nights_cold = sum(sky_temp_below_zero_pct >= 0.9, na.rm = TRUE),
      ratio = ifelse(nights_cold > 0, (nights_over_21_3 / nights_cold) * 100, NA),
      .groups = 'drop'
    )
  
  # Merge to include all years with 0 where applicable
  yearly_counts <- all_years %>%
    left_join(yearly_counts, by = "year") %>%
    mutate(
      nights_over_21_3 = ifelse(is.na(nights_over_21_3), 0, nights_over_21_3),
      nights_cold = ifelse(is.na(nights_cold), 0, nights_cold),
      ratio = ifelse(is.na(ratio), 0, ratio)
    )
  
  return(yearly_counts)
}

# Function to plot the data
plot_yearly_counts <- function(yearly_counts, filtered_data) {
  filtered_data <- filtered_data %>%
    mutate(time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")) %>%
    filter(!is.na(time))
  
  if (nrow(filtered_data) > 0) {
    date_range <- range(filtered_data$time, na.rm = TRUE)
    subtitle_text <- paste("Daten von", format(date_range[1], "%Y-%m-%d"), "bis", format(date_range[2], "%Y-%m-%d"))
  } else {
    subtitle_text <- "Keine Daten für die gewählten Kriterien vorhanden"
  }
  
  yearly_counts_long <- yearly_counts %>%
    pivot_longer(cols = c(nights_over_21_3, nights_cold), names_to = "condition", values_to = "count") %>%
    mutate(condition = recode(condition, 
                              "nights_over_21_3" = "Nächte mit max MSAS > 21.3", 
                              "nights_cold" = "Nächte mit 90% Himmelstemperatur < 0"))
  
  fixed_y_limit <- 200 # Fixed y-axis scale limit
  
  p1 <- ggplot(yearly_counts_long, aes(x = factor(year), y = count, fill = condition)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.5), width = 0.3) +
    labs(
      title = "Jährliche Anzahl der Nächte nach Bedingung",
      subtitle = subtitle_text,
      x = "Jahr",
      y = "Anzahl der Nächte",
      fill = "Bedingung:"
    ) +
    scale_y_continuous(limits = c(0, fixed_y_limit), 
                       breaks = seq(0, fixed_y_limit, by = 25),
                       minor_breaks = NULL) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 0, hjust = 0.5),
      plot.title = element_text(size = 16),
      plot.subtitle = element_text(size = 12, color = "gray"),
      axis.title = element_text(size = 12),
      legend.position = "bottom"
    ) +
    scale_fill_manual(values = c("#7A4EA3", "#C88719"))
  
  p2 <- ggplot(yearly_counts, aes(x = factor(year), y = ratio)) +
    geom_linerange(aes(ymin = ratio - 1, ymax = ratio + 1), color = "#C88719", size = 7) +
    labs(
      title = "Anteil der Nächte mit max MSAS > 21.3 im Verhältnis zu Nächten mit Himmelstemperatur < 0°",
      x = "Jahr",
      y = "Anteil [%]"
    ) +
    scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, by = 10), minor_breaks = NULL) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 0, hjust = 0.5),
      plot.title = element_text(size = 16),
      axis.title = element_text(size = 12)
    )
  
  if (nrow(yearly_counts) > 2) {
    p2 <- p2 + geom_smooth(method = "lm", color = "#404040", linetype = "dashed", se = FALSE)
  } else {
    p2 <- p2 + geom_text(aes(label = paste0(round(ratio, 1), "%")), vjust = -1, size = 4, color = "#404040")
  }
  
  grid.arrange(p1, p2, ncol = 1, heights = c(10, 7))
}

# Main function to run the analysis
main <- function(photometer_id) {
  data <- load_data_from_database(photometer_id)
  yearly_counts <- process_night_data(data)
  plot_yearly_counts(yearly_counts, data)
}
