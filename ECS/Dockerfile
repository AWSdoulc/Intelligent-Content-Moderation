# Basis-Image: Nutze ein schlankes Python-Image
FROM python:3.9-slim

# Arbeitsverzeichnis im Container festlegen
WORKDIR /app

# Kopiere die requirements-Datei und installiere die Abhängigkeiten
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Kopiere den Anwendungscode in das Arbeitsverzeichnis
COPY app.py ./

# Port freigeben, auf dem der Flask-Server laufen wird
EXPOSE 5000

# Starte die Anwendung
CMD ["python", "app.py"]