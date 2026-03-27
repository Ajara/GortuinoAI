package handlers

import (
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"iot_service_go/internal/auth"
	"iot_service_go/internal/models"
	"iot_service_go/internal/mqtt"
	"iot_service_go/internal/state"
	"iot_service_go/internal/storage"
)

type APIHandler struct {
	db         *gorm.DB
	mqtt       *mqtt.Manager
	state      *state.SystemState
	jwtManager *auth.JWTManager
}

type setupRequest struct {
	Username     string `json:"username" binding:"required,min=3"`
	Password     string `json:"password" binding:"required,min=6"`
	MQTTBrokerIP string `json:"mqtt_broker_ip" binding:"required,hostname|ip"`
	MQTTPort     uint16 `json:"mqtt_port"`
	MQTTSecure   bool   `json:"mqtt_secure"`
	MQTTCA       string `json:"mqtt_ca"`
	MQTTUsername string `json:"mqtt_username"`
	MQTTPassword string `json:"mqtt_password"`
}

type actualResponse struct {
	Sensores models.SensorData `json:"sensores"`
	Rele6    string            `json:"rele6"`
	Rele7    string            `json:"rele7"`
}

type loginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

func NewAPIHandler(
	db *gorm.DB,
	mqttManager *mqtt.Manager,
	systemState *state.SystemState,
	jwtManager *auth.JWTManager,
) *APIHandler {
	return &APIHandler{
		db:         db,
		mqtt:       mqttManager,
		state:      systemState,
		jwtManager: jwtManager,
	}
}

func (h *APIHandler) Setup(c *gin.Context) {
	var req setupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userCount, err := storage.CountUsers(h.db)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to count users"})
		return
	}

	if userCount > 0 {
		c.JSON(http.StatusForbidden, gin.H{"error": "setup already completed"})
		return
	}

	config := models.Config{
		ID:           1,
		MQTTBrokerIP: req.MQTTBrokerIP,
		MQTTPort:     req.MQTTPort,
		MQTTSecure:   req.MQTTSecure,
		MQTTCA:       req.MQTTCA,
		MQTTUsername: req.MQTTUsername,
		MQTTPassword: req.MQTTPassword,
		IsConfigured: true,
	}
	if config.MQTTPort == 0 {
		if config.MQTTSecure {
			config.MQTTPort = 8883
		} else {
			config.MQTTPort = 1883
		}
	}

	if err := storage.CreateInitialSetup(
		h.db,
		req.Username,
		req.Password,
		config,
	); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create initial setup"})
		return
	}

	if err := h.mqtt.Connect(config); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "setup saved but mqtt connection failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "configured"})
}

func (h *APIHandler) Login(c *gin.Context) {
	var req loginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user, err := storage.GetUserByUsername(h.db, req.Username)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load user"})
		return
	}

	if err := storage.CheckPasswordHash(user.Password, req.Password); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	token, err := h.jwtManager.GenerateToken(user.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": token})
}

func (h *APIHandler) GetActual(c *gin.Context) {
	latest, err := storage.GetLatestSensorData(h.db)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "no sensor data available"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load current sensor data"})
		return
	}

	rele6, rele7 := h.state.Snapshot()

	c.JSON(http.StatusOK, actualResponse{
		Sensores: latest,
		Rele6:    relayLabel(rele6),
		Rele7:    relayLabel(rele7),
	})
}

func (h *APIHandler) GetHistorico(c *gin.Context) {
	history, err := storage.GetSensorDataLast24Hours(h.db)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load history"})
		return
	}
	c.JSON(http.StatusOK, history)
}

func (h *APIHandler) RequestLiveSensors(c *gin.Context) {
	if err := h.mqtt.RequestSensorRead(); err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "requested"})
}

func (h *APIHandler) ActivateValve(c *gin.Context) {
	valveID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid valve id"})
		return
	}

	switch valveID {
	case 1:
		if err := h.mqtt.PublishRelay6("ON"); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": err.Error()})
			return
		}
		h.state.SetRelay6(true)

		go func() {
			time.Sleep(30 * time.Second)
			if err := h.mqtt.PublishRelay6("OFF"); err == nil {
				h.state.SetRelay6(false)
			}
		}()

	case 2:
		if err := h.mqtt.PublishRelay6("OFF"); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": err.Error()})
			return
		}
		h.state.SetRelay6(false)

		if err := h.mqtt.PublishRelay7("ON"); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": err.Error()})
			return
		}
		h.state.SetRelay7(true)

		go func() {
			time.Sleep(30 * time.Second)
			if err := h.mqtt.PublishRelay7("OFF"); err == nil {
				h.state.SetRelay7(false)
			}
		}()

	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "valve id must be 1 or 2"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "accepted"})
}

func relayLabel(isOpen bool) string {
	if isOpen {
		return "Abierto"
	}
	return "Cerrado"
}
