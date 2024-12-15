library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)

# Path to the SQLite database
db_tess_data_path <- normalizePath(file.path("..", "..", "data", "TessNetwork_data.db"), mustWork = FALSE)

# Function to load only necessary data from the SQLite database for a specific photometer
load_data_from_database <- function(photometer_id) {
  if (!file.exists(db_tess_data_path)) {
    stop(paste("Database not found at path:", db_tess_data_path))
  }
  
  conn <- dbConnect(RSQLite::SQLite(), db_tess_data_path)
  table_name <- paste0(photometer_id, "_data")
  query <- paste("SELECT time, msas, night_id, astronomical_night FROM", table_name)
  df <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  
  if (nrow(df) == 0) {
    stop(paste("Keine Daten für Photometer gefunden:", photometer_id))
  }
  
  return(df)
}

# Function to process the data to count nights with max_msas > 21.3
process_night_data <- function(df, selected_years) {
  result <- df %>%
    filter(astronomical_night == 1, year(as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")) %in% selected_years) %>%                    
    group_by(night_id) %>%                          
    summarise(max_msas = max(msas, na.rm = TRUE)) %>%
    filter(max_msas > 21.3) %>%
    summarise(nights_over_21_3 = n())                
  
  return(result$nights_over_21_3)
}

# Function to plot the histogram of nights with max_msas > 21.3
plot_histogram <- function(df, selected_years) {
  df_nightly_stats <- df %>%
    filter(astronomical_night == 1, year(as.POSIXct(time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")) %in% selected_years) %>%                      
    group_by(night_id) %>%
    summarise(max_msas = max(msas, na.rm = TRUE), night_date = as.Date(min(time)), .groups = "drop") %>%
    filter(max_msas > 21.3) %>%
    mutate(
      month = month(night_date, label = TRUE, abbr = TRUE),
      year = year(night_date)
    )
  
  all_months <- data.frame(
    night_date = seq.Date(
      from = as.Date(paste(min(selected_years), "01-01", sep = "-")),
      to = as.Date(paste(max(selected_years), "12-31", sep = "-")),
      by = "month"
    )
  )
  
  monthly_counts <- df_nightly_stats %>%
    group_by(night_date = floor_date(night_date, "month"), year) %>%
    summarise(count = n(), .groups = "drop")
  
  plot_data <- all_months %>%
    mutate(year = year(night_date)) %>%
    left_join(monthly_counts, by = c("night_date", "year")) %>%
    mutate(count = ifelse(is.na(count), 0, count))
  
  if (sum(plot_data$count) == 0) {
    ggplot(data.frame(month = factor(month.abb, levels = month.abb)), aes(x = month)) +
      geom_blank() +
      labs(
        title = "Anzahl Nächte mit max. MSAS > 21.3 pro Monat",
        subtitle = "Keine Daten für die gewählten Kriterien vorhanden",
        x = "Monat", y = "Anzahl Nächte"
      ) +
      scale_y_continuous(limits = c(0, 31)) +
      theme_minimal() +
      annotate("text", x = 6.5, y = 15, label = "Keine Nacht mit max. MSAS > 21.3 gefunden", color = "red", size = 5, fontface = "bold")
  } else {
    date_range <- range(df_nightly_stats$night_date, na.rm = TRUE)
    subtitle_text <- paste("Daten von", format(date_range[1], "%Y-%m-%d"), "bis", format(date_range[2], "%Y-%m-%d"))
    
    ggplot(plot_data, aes(x = month(night_date, label = TRUE, abbr = TRUE), y = count)) +
      geom_bar(stat = "identity", fill = "steelblue", show.legend = FALSE) +
      labs(
        title = "Anzahl Nächte mit max. MSAS > 21.3 pro Monat",
        subtitle = subtitle_text,
        x = "Monat", y = "Anzahl Nächte"
      ) +
      scale_y_continuous(limits = c(0, 31)) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 90, hjust = 1),
        axis.title = element_text(size = 12, face = "plain"),
        plot.title = element_text(size = 16), 
        plot.subtitle = element_text(size = 12, color = "gray"), 
        panel.spacing = unit(1, "lines")
      ) +
      facet_wrap(~ year, ncol = 2)
  }
}

main <- function(photometer_id, selected_years) {
  data <- load_data_from_database(photometer_id)
  process_night_data(data, selected_years)
  plot_histogram(data, selected_years)
}
