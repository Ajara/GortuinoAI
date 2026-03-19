package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	jwt "github.com/golang-jwt/jwt/v5"
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/sqlite"
	"golang.org/x/crypto/bcrypt"
)

// ===================== MODELOS =====================

type User struct {
	ID       uint   `gorm:"primary_key"`
	Username string `gorm:"unique_index;not null"`
	Password string `gorm:"not null"` // hash bcrypt
}

type Config struct {
	ID            uint   `gorm:"primary_key"`
	MQTTBrokerIP  string `gorm:"not null"`
	IsConfigured  bool   `gorm:"not null"`
}

type SensorData struct {
	ID          uint      `gorm:"primary_key" json:"id"`
	Exterior    float64   `gorm:"not null" json:"temp_exterior"`
	Interior    float64   `gorm:"not null" json:"temp_interior"`
	Deposito    float64   `gorm:"not null" json:"temp_deposito"`
	Ambiente2   float64   `gorm:"not null" json:"temp_ambiente2"`
	VoltajeBat  float64   `gorm:"not null" json:"bateria_v"`
	VoltajeBat2 float64   `gorm:"not null" json:"voltaje_bat_2"`
	CreatedAt   time.Time `gorm:"index" json:"created_at"`
}

// ===================== ESTADO EN MEMORIA =====================

type SystemState struct {
	mu    sync.RWMutex
	Rele6 bool
	Rele7 bool
}

func (s *SystemState) SetRele6(on bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.Rele6 = on
}

func (s *SystemState) SetRele7(on bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.Rele7 = on
}

func (s *SystemState) Snapshot() (rele6, rele7 bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.Rele6, s.Rele7
}

// ===================== CONTEXTO DE APLICACIÓN =====================

type AppContext struct {
	DB          *gorm.DB
	MQTTClient  mqtt.Client
	State       *SystemState
	MQTTBroker  string
	JWTSecret   []byte
	OnlineChan  chan SensorData
}

// ===================== AUTH / JWT =====================

const jwtExpiry = 24 * time.Hour

// ===================== MQTT =====================

const (
	topicRele6    = "casa/rele/6"
	topicRele7    = "casa/rele/7"
	topicSensores = "casa/estado/sensores"
	topicPeticion = "casa/peticion"
)

func (app *AppContext) initMQTT(brokerIP string) {
	if brokerIP == "" {
		return
	}
	brokerURL := "tcp://" + brokerIP + ":1883"
	opts := mqtt.NewClientOptions().
		AddBroker(brokerURL).
		SetClientID("backend-" + time.Now().Format("20060102150405")).
		SetAutoReconnect(true)

	opts.SetOnConnectHandler(func(c mqtt.Client) {
		log.Printf("Conectado a MQTT broker %s", brokerURL)
		// Estado seguro: forzar OFF
		if token := c.Publish(topicRele6, 0, false, "OFF"); token.Wait() && token.Error() != nil {
			log.Printf("Error publicando OFF rele6: %v", token.Error())
		} else {
			app.State.SetRele6(false)
		}
		if token := c.Publish(topicRele7, 0, false, "OFF"); token.Wait() && token.Error() != nil {
			log.Printf("Error publicando OFF rele7: %v", token.Error())
		} else {
			app.State.SetRele7(false)
		}

		// Suscribirse a sensores
		if token := c.Subscribe(topicSensores, 0, app.handleSensorMessage); token.Wait() && token.Error() != nil {
			log.Printf("Error suscribiendo a %s: %v", topicSensores, token.Error())
		}

		// Suscribirse a peticiones (por si en futuro se usa desde backend)
		if token := c.Subscribe(topicPeticion, 0, nil); token.Wait() && token.Error() != nil {
			log.Printf("Error suscribiendo a %s: %v", topicPeticion, token.Error())
		}
	})

	client := mqtt.NewClient(opts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		log.Printf("No se pudo conectar a MQTT: %v", token.Error())
	} else {
		app.MQTTClient = client
		app.MQTTBroker = brokerIP
	}
}

func (app *AppContext) handleSensorMessage(client mqtt.Client, msg mqtt.Message) {
	var payload struct {
		Exterior    float64 `json:"temp_exterior"`
		Interior    float64 `json:"temp_interior"`
		Deposito    float64 `json:"temp_deposito"`
		Ambiente2   float64 `json:"temp_ambiente2"`
		BateriaV    float64 `json:"bateria_v"`
		BateriaV2   float64 `json:"voltaje_bat_2"`
	}
	if err := json.Unmarshal(msg.Payload(), &payload); err != nil {
		log.Printf("Error parseando JSON sensores: %v", err)
		return
	}

	record := SensorData{
		Exterior:    payload.Exterior,
		Interior:    payload.Interior,
		Deposito:    payload.Deposito,
		Ambiente2:   payload.Ambiente2,
		VoltajeBat:  payload.BateriaV,
		VoltajeBat2: payload.BateriaV2,
		CreatedAt:   time.Now(),
	}

	if err := app.DB.Create(&record).Error; err != nil {
		log.Printf("Error guardando SensorData: %v", err)
	}

	// Si hay una petición online esperando, enviar el dato más reciente
	if app.OnlineChan != nil {
		select {
		case app.OnlineChan <- record:
		default:
		}
	}
}

// ===================== HANDLERS HTTP =====================

type setupRequest struct {
	Username      string `json:"username" binding:"required"`
	Password      string `json:"password" binding:"required"`
	MQTTBrokerIP  string `json:"mqtt_broker_ip" binding:"required"`
}

type loginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type jwtClaims struct {
	UserID   uint   `json:"user_id"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

func (app *AppContext) generateToken(user *User) (string, error) {
	now := time.Now()
	claims := jwtClaims{
		UserID:   user.ID,
		Username: user.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(jwtExpiry)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(app.JWTSecret)
}

func (app *AppContext) handleLogin(c *gin.Context) {
	var req loginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user User
	if err := app.DB.Where("username = ?", req.Username).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	token, err := app.generateToken(&user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "token generation failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": token})
}

func (app *AppContext) authRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing Authorization header"})
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid Authorization header"})
			return
		}

		tokenStr := parts[1]
		token, err := jwt.ParseWithClaims(tokenStr, &jwtClaims{}, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return app.JWTSecret, nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			return
		}

		claims, ok := token.Claims.(*jwtClaims)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token claims"})
			return
		}

		c.Set("user_id", claims.UserID)
		c.Set("username", claims.Username)
		c.Next()
	}
}

func (app *AppContext) handleSetup(c *gin.Context) {
	var count int
	if err := app.DB.Model(&User{}).Count(&count).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "db error"})
		return
	}
	if count > 0 {
		c.JSON(http.StatusForbidden, gin.H{"error": "setup already done"})
		return
	}

	var req setupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "password hash error"})
		return
	}

	user := User{
		Username: req.Username,
		Password: string(hash),
	}
	if err := app.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "db error creating user"})
		return
	}

	cfg := Config{
		MQTTBrokerIP: req.MQTTBrokerIP,
		IsConfigured: true,
	}
	if err := app.DB.Save(&cfg).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "db error saving config"})
		return
	}

	app.initMQTT(req.MQTTBrokerIP)

	c.JSON(http.StatusOK, gin.H{"status": "setup completed"})
}

func (app *AppContext) handleActual(c *gin.Context) {
	var last SensorData
	if err := app.DB.Order("created_at desc").First(&last).Error; err != nil && !gorm.IsRecordNotFoundError(err) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "db error"})
		return
	}

	rele6, rele7 := app.State.Snapshot()

	c.JSON(http.StatusOK, gin.H{
		"sensores": last,
		"reles": gin.H{
			"rele6": map[string]interface{}{
				"estado": boolToEstado(rele6),
				"on":     rele6,
			},
			"rele7": map[string]interface{}{
				"estado": boolToEstado(rele7),
				"on":     rele7,
			},
		},
	})
}

func boolToEstado(on bool) string {
	if on {
		return "Abierto"
	}
	return "Cerrado"
}

func (app *AppContext) handleHistorico(c *gin.Context) {
	since := time.Now().Add(-24 * time.Hour)
	var records []SensorData
	if err := app.DB.
		Where("created_at >= ?", since).
		Order("created_at asc").
		Find(&records).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "db error"})
		return
	}
	c.JSON(http.StatusOK, records)
}

func (app *AppContext) handleValvula(c *gin.Context) {
	id := c.Param("id")
	switch id {
	case "1":
		app.triggerValve1()
	case "2":
		app.triggerValve2()
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

// Solicita lectura online al ESP32 via MQTT y devuelve los valores sin necesidad de esperar al siguiente ciclo periódico.
func (app *AppContext) handleActualOnline(c *gin.Context) {
	if app.MQTTClient == nil || !app.MQTTClient.IsConnectionOpen() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "MQTT no disponible"})
		return
	}

	ch := make(chan SensorData, 1)
	app.OnlineChan = ch
	defer func() { app.OnlineChan = nil }()

	// Pedir lectura inmediata al ESP32
	if token := app.MQTTClient.Publish(topicPeticion, 0, false, "GET_DATA"); token.Wait() && token.Error() != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "no se pudo publicar petición MQTT"})
		return
	}

	select {
	case data := <-ch:
		rele6, rele7 := app.State.Snapshot()
		c.JSON(http.StatusOK, gin.H{
			"sensores": data,
			"reles": gin.H{
				"rele6": map[string]interface{}{
					"estado": boolToEstado(rele6),
					"on":     rele6,
				},
				"rele7": map[string]interface{}{
					"estado": boolToEstado(rele7),
					"on":     rele7,
				},
			},
		})
	case <-time.After(5 * time.Second):
		c.JSON(http.StatusGatewayTimeout, gin.H{"error": "timeout esperando datos online"})
	}
}

func (app *AppContext) triggerValve1() {
	if app.MQTTClient == nil || !app.MQTTClient.IsConnectionOpen() {
		log.Println("MQTT no disponible para valvula 1")
		return
	}
	if token := app.MQTTClient.Publish(topicRele6, 0, false, "ON"); token.Wait() && token.Error() != nil {
		log.Printf("Error publicando ON rele6: %v", token.Error())
		return
	}
	app.State.SetRele6(true)

	go func() {
		time.Sleep(30 * time.Second)
		if token := app.MQTTClient.Publish(topicRele6, 0, false, "OFF"); token.Wait() && token.Error() != nil {
			log.Printf("Error publicando OFF rele6: %v", token.Error())
			return
		}
		app.State.SetRele6(false)
	}()
}

func (app *AppContext) triggerValve2() {
	if app.MQTTClient == nil || !app.MQTTClient.IsConnectionOpen() {
		log.Println("MQTT no disponible para valvula 2")
		return
	}
	// Seguridad: apagar rele6 primero
	if token := app.MQTTClient.Publish(topicRele6, 0, false, "OFF"); token.Wait() && token.Error() != nil {
		log.Printf("Error publicando OFF rele6: %v", token.Error())
	}
	app.State.SetRele6(false)

	if token := app.MQTTClient.Publish(topicRele7, 0, false, "ON"); token.Wait() && token.Error() != nil {
		log.Printf("Error publicando ON rele7: %v", token.Error())
		return
	}
	app.State.SetRele7(true)

	go func() {
		time.Sleep(30 * time.Second)
		if token := app.MQTTClient.Publish(topicRele7, 0, false, "OFF"); token.Wait() && token.Error() != nil {
			log.Printf("Error publicando OFF rele7: %v", token.Error())
			return
		}
		app.State.SetRele7(false)
	}()
}

// ===================== MAIN & UTILIDADES =====================

func main() {
	dbPath := getEnv("DB_PATH", "iot.db")
	db, err := gorm.Open("sqlite3", dbPath)
	if err != nil {
		log.Fatalf("error abriendo BD: %v", err)
	}
	defer db.Close()

	db.AutoMigrate(&User{}, &Config{}, &SensorData{})

	jwtSecret := []byte(getEnv("JWT_SECRET", "super-secret-change-me"))

	app := &AppContext{
		DB:        db,
		State:     &SystemState{},
		JWTSecret: jwtSecret,
	}

	// Cargar configuración de broker en arranque
	var cfg Config
	if err := db.First(&cfg).Error; err == nil && cfg.IsConfigured && cfg.MQTTBrokerIP != "" {
		app.initMQTT(cfg.MQTTBrokerIP)
	}

	router := gin.Default()

	// CORS con Authorization permitido
	router.Use(cors.New(cors.Config{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{"GET", "POST", "OPTIONS"},
		AllowHeaders: []string{"Origin", "Content-Type", "Authorization"},
	}))

	router.POST("/setup", app.handleSetup)
	router.POST("/login", app.handleLogin)

	api := router.Group("/api", app.authRequired())
	{
		api.GET("/actual", app.handleActual)
		api.GET("/actual/online", app.handleActualOnline)
		api.GET("/historico", app.handleHistorico)
		api.POST("/valvula/:id", app.handleValvula)
	}

	srv := &http.Server{
		Addr:    ":8080",
		Handler: router,
	}

	// Manejo de señales para apagado controlado
	idleConnsClosed := make(chan struct{})
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh

		log.Println("Recibida señal, apagando servidor HTTP...")

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := srv.Shutdown(ctx); err != nil {
			log.Printf("Error en apagado HTTP: %v", err)
		}

		if app.MQTTClient != nil && app.MQTTClient.IsConnectionOpen() {
			app.MQTTClient.Disconnect(250)
		}

		close(idleConnsClosed)
	}()

	log.Println("Servidor escuchando en :8080")
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("ListenAndServe error: %v", err)
	}

	<-idleConnsClosed
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

