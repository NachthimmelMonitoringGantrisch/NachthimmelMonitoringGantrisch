# Naturpark Gantrisch: Analyse, Automatisierung und Visualisierung von Nachthimmelmonitoring

## Dokumentation und Bedienungsanleitung

<a href="https://documentation-gantrisch.vercel.app/">Hier finden Sie die Dokumentation</a>

## Installation
Die Installation der Plattform "Nachthimmelmonitoring Naturpark Gantrisch" ist mit Docker Containern vorgesehen. Die Umsetzung mit Docker war jedoch nicht erfolgreich. 

---

## Abhänigkeiten

### R + Shiny
Die folgenden R-Pakete werden für die Shiny-Anwendung benötigt. Die aktuell verwendete R-Version ist **4.4.1**.

```r
install.packages("shiny")       # Interaktive Webanwendungen mit R
install.packages("ggplot2")     # Datenvisualisierung
install.packages("RSQLite")     # SQLite-Datenbankanbindung
install.packages("jsonlite")    # Arbeiten mit JSON-Daten
install.packages("reticulate")  # Verbindung zwischen R und Python
install.packages("DT")          # Interaktive DataTables
install.packages("dplyr")       # Datenmanipulation
install.packages("lubridate")   # Arbeiten mit Datum/Zeit
install.packages("DBI")         # Allgemeines Datenbank-Interface
install.packages("tidyr")       # Datenaufräumung
install.packages("gridExtra")   # Kombinieren von Plots
install.packages("cowplot")     # Verbessertes Plot-Layout
install.packages("patchwork")   # Komplexe Plot-Layouts
```

### Vorinstallierte R-Pakete
Die folgende Liste zeigt die Pakete, die standardmäßig in der R-Installation enthalten sind. Diese Pakete sind in der Regel ohne zusätzliche Installation verfügbar.

<table>
  <tr>
    <td>
      <table>
        <tr><th>**Package**</th><th>**Version**</th></tr>
        <tr><td>askpass</td><td>1.2.0</td></tr>
        <tr><td>backports</td><td>1.5.0</td></tr>
        <tr><td>base64enc</td><td>0.1-3</td></tr>
        <tr><td>bit</td><td>4.5.0</td></tr>
        <tr><td>bit64</td><td>4.5.2</td></tr>
        <tr><td>blob</td><td>1.2.4</td></tr>
        <tr><td>bslib</td><td>0.8.0</td></tr>
        <tr><td>callr</td><td>3.7.6</td></tr>
        <tr><td>cli</td><td>3.6.3</td></tr>
        <tr><td>DBI</td><td>1.2.3</td></tr>
        <tr><td>dplyr</td><td>1.1.4</td></tr>
        <tr><td>DT</td><td>0.33</td></tr>
        <tr><td>ggplot2</td><td>3.5.1</td></tr>
        <tr><td>jsonlite</td><td>1.8.9</td></tr>
      </table>
    </td>
    <td>
      <table>
        <tr><th>**Package**</th><th>**Version**</th></tr>
        <tr><td>lubridate</td><td>1.9.3</td></tr>
        <tr><td>reticulate</td><td>1.39.0</td></tr>
        <tr><td>RSQLite</td><td>2.3.7</td></tr>
        <tr><td>shiny</td><td>1.9.1</td></tr>
        <tr><td>stringi</td><td>1.8.4</td></tr>
        <tr><td>tibble</td><td>3.2.1</td></tr>
        <tr><td>tidyr</td><td>1.3.1</td></tr>
        <tr><td>utils</td><td>4.4.1</td></tr>
        <tr><td>R6</td><td>2.5.1</td></tr>
        <tr><td>rpart</td><td>4.1.23</td></tr>
        <tr><td>rprojroot</td><td>2.0.4</td></tr>
        <tr><td>survival</td><td>3.6-4</td></tr>
        <tr><td>tools</td><td>4.4.1</td></tr>
        <tr><td>stats</td><td>4.4.1</td></tr>
        <tr><td>yaml</td><td>2.3.10</td></tr>
      </table>
    </td>
  </tr>
</table>

Diese Pakete sind in der Regel in der Basisinstallation von R enthalten und erfordern keine zusätzliche Installation.

---

### Python
Es werden zwei separate Python-Umgebungen verwendet:

#### 1. **TESS-IDA-TOOLS**
Die virtuelle Umgebung `.venv` enthält die Abhängigkeiten für die TESS-IDA-TOOLS. Diese Abhängigkeiten werden in der Datei `B_setup_TESS-IDA-TOOLS.py` definiert und automatisch bei einem Start der Plattform installiert.

```plaintext
notebook==7.2.2
matplotlib==3.9.2
sqlalchemy
pandas==2.2.3
numpy==2.1.3
aiohttp==3.9.5
aiodns==3.0.0
git+https://github.com/STARS4ALL/TESS-IDA-TOOLS#main
```

**Erklärung der Abhängigkeiten:**
- **notebook==7.2.2**: Zum Ausführen von Jupyter-Notebooks
- **matplotlib==3.9.2**: Visualisierung von Daten
- **sqlalchemy**: ORM (Object Relational Mapper) für den Zugriff auf SQL-Datenbanken
- **pandas==2.2.3**: Datenanalyse und Datenverarbeitung
- **numpy==2.1.3**: Numerische Berechnungen
- **aiohttp==3.9.5**: Asynchrone HTTP-Anfragen
- **aiodns==3.0.0**: Asynchrone DNS-Anfragen
- **TESS-IDA-TOOLS**: GitHub-Repository, das die Tools zur Verarbeitung der TESS-Daten enthält

#### 2. **Python-Umgebung mit Shiny**
Die virtuelle Umgebung `.venv_R` wird verwendet, wenn Python-Skripte in der Shiny-App ausgeführt werden. Diese Umgebungsabhängigkeiten werden in der Datei `python/requirements/requirements_venv_R.txt` definiert. Diese Requirements werden automatisch bei einem Start der Plattform überprüft und installiert.

```plaintext
certifi==2024.8.30
charset-normalizer==3.4.0
greenlet==3.1.1
idna==3.10
lxml==5.3.0
numpy==2.1.3
pandas==2.2.3
python-dateutil==2.9.0.post0
pytz==2024.2
requests==2.32.3
six==1.16.0
SQLAlchemy==2.0.36
typing_extensions==4.12.2
tzdata==2024.2
urllib3==2.2.3
```

---