FROM golang:1.22-alpine AS builder

WORKDIR /app

RUN apk add --no-cache build-base gcc musl-dev sqlite-dev

COPY go.mod ./
RUN go mod download

COPY . .

RUN go mod tidy
RUN CGO_ENABLED=1 GOOS=linux go build -o /bin/iot-service .

FROM alpine:3.20

RUN apk add --no-cache ca-certificates sqlite-libs

WORKDIR /data

COPY --from=builder /bin/iot-service /usr/local/bin/iot-service

EXPOSE 8080

CMD ["/usr/local/bin/iot-service"]
