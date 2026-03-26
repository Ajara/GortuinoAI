package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"syscall"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// --- MODELOS DE DATOS ---

type User struct {
	gorm.Model
	Username string `gorm:"unique;not null"`
	Password string `gorm:"not null"`
}

type Config struct {
	ID             uint `gorm:"primaryKey"`
	MQTT_Broker_IP string
	IsConfigured   bool
}

type SensorData struct {
	ID             uint      `gorm:"primaryKey" json:"id"`
	Exterior       float64   `json:"Exterior"`
	Interior       float64   `json:"Interior"`
	Deposito       float64   `json:"Deposito"`
	Ambiente2       float64   `json:"Ambiente2"`
	Voltaje_Bat    float64   `json:"VoltajeBateria"`
	Voltaje_Bat2   float64   `json:"VoltajeBateria2"`
	CreatedAt      time.Time `json:"timestamp"`
}

// --- ESTADO GLOBAL EN MEMORIA ---

type SystemState struct {
	sync.RWMutex
	Rele6 bool `json:"rele6"`
	Rele7 bool `json:"rele7"`
}

var (
	db          *gorm.DB
	state       = &SystemState{}
	mqttClient  mqtt.Client
	mqttReady   = make(chan struct{})
)

// --- INICIALIZACIÓN DE DB ---

func initDB() {
	var err error
	// Asegurar que el directorio data existe
	os.MkdirAll("data", 0755)
	db, err = gorm.Open(sqlite.Open("data/iot_system.db"), &gorm.Config{})
	if err != nil {
		log.Fatalf("Error conectando a SQLite: %v", err)
	}
	db.AutoMigrate(&User{}, &Config{}, &SensorData{})
}

// --- LÓGICA MQTT ---

func setupMQTT(brokerIP string) {
	opts := mqtt.NewClientOptions()
	opts.AddBroker(fmt.Sprintf("tcp://%s:1883", brokerIP))
	opts.SetClientID("Go_Backend_IoT")
	opts.SetAutoReconnect(true)

	// Callback al conectar/reconectar (SEGURIDAD: Poner todo en OFF)
	opts.OnConnect = func(c mqtt.Client) {
		log.Printf("Conectado al Broker MQTT: %s", brokerIP)
		c.Publish("casa/rele/6", 0, false, "OFF")
		c.Publish("casa/rele/7", 0, false, "OFF")
		
		state.Lock()
		state.Rele6 = false
		state.Rele7 = false
		state.Unlock()

		// Suscribirse a sensores
		c.Subscribe("casa/estado/sensores", 0, func(client mqtt.Client, msg mqtt.Message) {
			log.Printf("MQTT recibido en tópico %s: %s", msg.Topic(), string(msg.Payload()))
			
			var data SensorData
			if err := json.Unmarshal(msg.Payload(), &data); err != nil {
				log.Printf("ERROR parseando JSON de sensores: %v | Payload: %s", err, string(msg.Payload()))
				return
			}
			
			data.CreatedAt = time.Now()
			if err := db.Create(&data).Error; err != nil {
				log.Printf("ERROR guardando en DB: %v", err)
			} else {
				log.Println("Persistidos datos de sensores recibidos vía MQTT")
			}
		})
	}

	mqttClient = mqtt.NewClient(opts)
	log.Printf("Iniciando conexión MQTT hacia: %s...", brokerIP)
	if token := mqttClient.Connect(); token.Wait() && token.Error() != nil {
		log.Printf("ERROR CRÍTICO MQTT: %v", token.Error())
	} else {
		log.Printf("MQTT: Solicitud de conexión enviada correctamente")
	}
}

// --- HANDLERS API ---

func RefreshHandler(c *gin.Context) {
	if mqttClient == nil || !mqttClient.IsConnected() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "MQTT no conectado"})
		return
	}
	mqttClient.Publish("casa/peticion", 0, false, "GET_DATA")
	c.JSON(http.StatusOK, gin.H{"message": "Solicitud GET_DATA enviada al ESP32"})
}

func SetupHandler(c *gin.Context) {
	var count int64
	db.Model(&User{}).Count(&count)
	if count > 0 {
		c.JSON(http.StatusForbidden, gin.H{"error": "El sistema ya ha sido configurado"})
		return
	}

	var req struct {
		Username     string `json:"username" binding:"required"`
		Password     string `json:"password" binding:"required"`
		MQTT_Broker  string `json:"mqtt_broker_ip" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Cifrar contraseña
	hashed, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	
	// Guardar Usuario y Config
	user := User{Username: req.Username, Password: string(hashed)}
	config := Config{ID: 1, MQTT_Broker_IP: req.MQTT_Broker, IsConfigured: true}

	db.Create(&user)
	db.Save(&config)

	// Conectar MQTT inmediatamente
	go setupMQTT(req.MQTT_Broker)

	c.JSON(http.StatusOK, gin.H{"message": "Configuración inicial exitosa"})
}

func ActualHandler(c *gin.Context) {
	var lastReading SensorData
	db.Order("created_at desc").First(&lastReading)

	state.RLock()
	defer state.RUnlock()

	c.JSON(http.StatusOK, gin.H{
		"sensores": lastReading,
		"reles": gin.H{
			"rele6": mapStatus(state.Rele6),
			"rele7": mapStatus(state.Rele7),
		},
	})
}

func mapStatus(b bool) string {
	if b { return "Abierto" }
	return "Cerrado"
}

func HistoricoHandler(c *gin.Context) {
	var readings []SensorData
	last24h := time.Now().Add(-24 * time.Hour)
	db.Where("created_at > ?", last24h).Order("created_at asc").Find(&readings)
	c.JSON(http.StatusOK, readings)
}

func ValvulaHandler(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))

	if mqttClient == nil || !mqttClient.IsConnected() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "MQTT no conectado"})
		return
	}

	switch id {
	case 1:
		go func() {
			mqttClient.Publish("casa/rele/6", 0, false, "ON")
			updateState(6, true)
			time.Sleep(30 * time.Second)
			mqttClient.Publish("casa/rele/6", 0, false, "OFF")
			updateState(6, false)
		}()
	case 2:
		go func() {
			// Seguridad: Asegurar que R6 esté OFF
			mqttClient.Publish("casa/rele/6", 0, false, "OFF")
			updateState(6, false)
			
			mqttClient.Publish("casa/rele/7", 0, false, "ON")
			updateState(7, true)
			time.Sleep(30 * time.Second)
			mqttClient.Publish("casa/rele/7", 0, false, "OFF")
			updateState(7, false)
		}()
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de válvula no válido"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Comando enviado. La válvula se cerrará en 30s automáticamente"})
}

func updateState(rele int, val bool) {
	state.Lock()
	defer state.Unlock()
	if rele == 6 { state.Rele6 = val }
	if rele == 7 { state.Rele7 = val }
}

// --- MAIN ---

func main() {
	initDB()

	// Intentar cargar config previa
	var cfg Config
	if err := db.First(&cfg, 1).Error; err == nil && cfg.IsConfigured {
		go setupMQTT(cfg.MQTT_Broker_IP)
	}

	r := gin.Default()

	// Middleware de CORS para desarrollo
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Rutas
	r.POST("/setup", SetupHandler)
	api := r.Group("/api")
	{
		api.POST("/refresh", RefreshHandler)
		api.GET("/actual", ActualHandler)
		api.GET("/historico", HistoricoHandler)
		api.POST("/valvula/:id", ValvulaHandler)
	}

	// Servidor con Apagado Controlado (Graceful Shutdown)
	srv := &http.Server{
		Addr:    ":8080",
		Handler: r,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Error en el servidor: %s\n", err)
		}
	}()

	// Esperar señal de interrupción
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Apagando servidor...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	
	if mqttClient != nil {
		mqttClient.Disconnect(250)
	}

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("Fallo en el apagado forzado del servidor:", err)
	}

	log.Println("Microservicio detenido correctamente.")
}
