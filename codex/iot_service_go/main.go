package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"iot_service_go/internal/auth"
	"iot_service_go/internal/handlers"
	"iot_service_go/internal/models"
	"iot_service_go/internal/mqtt"
	"iot_service_go/internal/server"
	"iot_service_go/internal/state"
	"iot_service_go/internal/storage"
)

func main() {
	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = "iot.db"
	}

	db, err := storage.NewSQLiteDB(dbPath)
	if err != nil {
		log.Fatalf("opening database: %v", err)
	}

	if err := storage.AutoMigrate(db); err != nil {
		log.Fatalf("migrating database: %v", err)
	}

	systemState := state.NewSystemState()
	mqttManager := mqtt.NewManager(db, systemState)
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "change-this-in-production"
	}
	jwtManager := auth.NewJWTManager(jwtSecret, 24*time.Hour)

	cfg, err := storage.GetConfig(db)
	if err != nil && !errors.Is(err, models.ErrConfigNotFound) {
		log.Fatalf("loading config: %v", err)
	}

	if cfg.IsConfigured && cfg.MQTTBrokerIP != "" {
		if err := mqttManager.Connect(cfg); err != nil {
			log.Printf("mqtt initial connect failed: %v", err)
		}
	}

	apiHandler := handlers.NewAPIHandler(db, mqttManager, systemState, jwtManager)
	router := server.NewRouter(apiHandler, jwtManager)

	httpServer := &http.Server{
		Addr:              ":8080",
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("http server listening on %s", httpServer.Addr)
		if serveErr := httpServer.ListenAndServe(); serveErr != nil && !errors.Is(serveErr, http.ErrServerClosed) {
			log.Fatalf("http server error: %v", serveErr)
		}
	}()

	waitForShutdown(httpServer, mqttManager)
}

func waitForShutdown(httpServer *http.Server, mqttManager *mqtt.Manager) {
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)

	sig := <-signals
	log.Printf("shutdown signal received: %s", sig)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := httpServer.Shutdown(ctx); err != nil {
		log.Printf("http shutdown error: %v", err)
	}

	mqttManager.Close(2 * time.Second)
	log.Print("shutdown complete")
}
