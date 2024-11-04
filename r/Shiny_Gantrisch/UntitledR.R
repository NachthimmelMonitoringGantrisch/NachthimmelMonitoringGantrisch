library(RSQLite)

db_path <- "C:/Users/Nando Amport/5230_Geoinformatik_Repository/NachthimmelMonitoringGantrisch/data/TessNetwork_metadata.db"
conn <- dbConnect(SQLite(), db_path)

# Test query
data <- dbGetQuery(conn, "SELECT * FROM TessNetwork_metadata LIMIT 5")
print(data)

dbDisconnect(conn)
print(getwd())

file.exists("C:/Users/Nando Amport/5230_Geoinformatik_Repository/NachthimmelMonitoringGantrisch/data/TessNetwork_metadata.db")


library(RSQLite)
db_path <- "C:/Users/Nando Amport/5230_Geoinformatik_Repository/NachthimmelMonitoringGantrisch/data/TessNetwork_metadata.db"
db <- dbConnect(SQLite(), dbname = db_path)

if ("TessNetwork_metadata" %in% dbListTables(db)) {
  print("Connection successful and table found!")
} else {
  print("Table not found.")
}

dbDisconnect(db)
