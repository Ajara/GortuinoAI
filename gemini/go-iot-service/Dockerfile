# --- ETAPA 1: Construcción ---
FROM golang:1.22-alpine AS builder

# Instalar dependencias necesarias para CGO (requerido por SQLite)
RUN apk add --no-cache gcc musl-dev sqlite-dev

WORKDIR /app

# Copiar archivos de dependencias
COPY go.mod go.sum* ./
RUN go mod download

# Copiar el código fuente
COPY . .

# Sincronizar dependencias y generar go.sum
RUN go mod tidy

# Compilar el binario con soporte para SQLite (CGO_ENABLED=1)
RUN CGO_ENABLED=1 GOOS=linux CGO_CFLAGS="-D_LARGEFILE64_SOURCE" go build -o main .

# --- ETAPA 2: Ejecución ---
FROM alpine:latest

# Instalar certificados y librerías de tiempo de ejecución de SQLite
RUN apk add --no-cache ca-certificates sqlite-libs

# Directorio de la aplicación
WORKDIR /app

# Copiar el binario desde la etapa de construcción
COPY --from=builder /app/main .

# Crear directorio para la base de datos
RUN mkdir data

# Exponer el puerto del API Gin
EXPOSE 8080

# Comando para ejecutar la aplicación
CMD ["./main"]
