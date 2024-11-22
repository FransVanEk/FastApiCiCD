# Stage 1: Base image met Python 3.11
FROM python:3.11-alpine as builder

# Installeer build dependencies
RUN apk add --no-cache gcc musl-dev libffi-dev

# Werkdirectory in de container
WORKDIR /app

# Installeer en update pip
RUN python -m ensurepip && pip install --upgrade pip

# Kopieer requirements.txt en installeer afhankelijkheden
COPY requirements.txt ./
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Minimalistische runtime image
FROM python:3.11-alpine

# Werkdirectory instellen
WORKDIR /app

# Installeer runtime dependencies
RUN apk add --no-cache libffi

# Kopieer geïnstalleerde afhankelijkheden van de builder
COPY --from=builder /install /usr/local

# Kopieer de applicatiecode
COPY . ./

# Exporteer poort 8000 voor de API
EXPOSE 8000

# Start de applicatie met Uvicorn
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]