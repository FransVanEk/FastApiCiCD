# Base image met Python 3.9
FROM python:3.9-slim

# Werkdirectory in de container
WORKDIR /app

# Kopieer requirements.txt en installeer afhankelijkheden
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kopieer de rest van de applicatie
COPY . .
    
# Exporteer poort 8000 voor de API
EXPOSE 8000

# Start de applicatie met Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]