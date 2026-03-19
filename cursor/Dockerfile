FROM golang:1.23-alpine AS builder

# Necesario para compilar go-sqlite3 (requiere cgo)
RUN apk add --no-cache ca-certificates gcc musl-dev sqlite

WORKDIR /app

# Copiamos los archivos de módulos primero para aprovechar caché
COPY go.mod ./

# Copiamos el resto del código
COPY . .

# Resolver dependencias dentro del contenedor (crea go.sum) y compilar con cgo habilitado
RUN go mod tidy && go build -o server .

FROM alpine:3.19

# Librerías runtime para go-sqlite3 (cgo)
RUN apk add --no-cache ca-certificates sqlite-libs

WORKDIR /app
COPY --from=builder /app/server .

# Persistencia SQLite: volumen debe montarse en /data
ENV DB_PATH=/data/iot.db
RUN mkdir -p /data

EXPOSE 8080

CMD ["./server"]
