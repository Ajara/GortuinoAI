package mqtt

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	paho "github.com/eclipse/paho.mqtt.golang"
	"gorm.io/gorm"

	"iot_service_go/internal/models"
	"iot_service_go/internal/state"
	"iot_service_go/internal/storage"
)

const (
	topicSensors = "casa/estado/sensores"
	topicRequest = "casa/peticion"
	topicRelay6  = "casa/rele/6"
	topicRelay7  = "casa/rele/7"
)

type Manager struct {
	db    *gorm.DB
	state *state.SystemState

	mu     sync.RWMutex
	client paho.Client
}

func NewManager(db *gorm.DB, systemState *state.SystemState) *Manager {
	return &Manager{
		db:    db,
		state: systemState,
	}
}

func (m *Manager) Connect(config models.Config) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.client != nil && m.client.IsConnected() {
		m.client.Disconnect(250)
	}

	brokerURL := normalizeBrokerURL(config.MQTTBrokerIP)
	if config.MQTTSecure {
		brokerURL = normalizeBrokerURLWithPort(config.MQTTBrokerIP, config.MQTTPort, "ssl")
	} else {
		brokerURL = normalizeBrokerURLWithPort(config.MQTTBrokerIP, config.MQTTPort, "tcp")
	}
	opts := paho.NewClientOptions()
	opts.AddBroker(brokerURL)
	opts.SetClientID(fmt.Sprintf("iot-backend-%d", time.Now().UnixNano()))
	opts.SetAutoReconnect(true)
	opts.SetConnectRetry(true)
	opts.SetConnectRetryInterval(5 * time.Second)
	opts.SetOrderMatters(false)
	if config.MQTTUsername != "" {
		opts.SetUsername(config.MQTTUsername)
		opts.SetPassword(config.MQTTPassword)
	}
	if config.MQTTSecure {
		tlsConfig := &tls.Config{
			MinVersion: tls.VersionTLS12,
		}
		if strings.TrimSpace(config.MQTTCA) != "" {
			pool := x509.NewCertPool()
			if !pool.AppendCertsFromPEM([]byte(config.MQTTCA)) {
				return fmt.Errorf("invalid mqtt ca certificate")
			}
			tlsConfig.RootCAs = pool
		} else {
			tlsConfig.InsecureSkipVerify = true
		}
		opts.SetTLSConfig(tlsConfig)
	}

	opts.OnConnect = func(client paho.Client) {
		log.Printf("mqtt connected to %s", brokerURL)
		m.forceSafeRelays(client)
		if token := client.Subscribe(topicSensors, 1, m.handleSensorMessage); token.Wait() && token.Error() != nil {
			log.Printf("mqtt subscribe error: %v", token.Error())
		}
	}

	opts.OnConnectionLost = func(_ paho.Client, err error) {
		log.Printf("mqtt connection lost: %v", err)
	}

	client := paho.NewClient(opts)
	token := client.Connect()
	if token.Wait() && token.Error() != nil {
		return token.Error()
	}

	m.client = client
	return nil
}

func (m *Manager) PublishRelay6(payload string) error {
	return m.publish(topicRelay6, payload)
}

func (m *Manager) PublishRelay7(payload string) error {
	return m.publish(topicRelay7, payload)
}

func (m *Manager) RequestSensorRead() error {
	return m.publish(topicRequest, "GET_DATA")
}

func (m *Manager) publish(topic, payload string) error {
	m.mu.RLock()
	client := m.client
	m.mu.RUnlock()

	if client == nil || !client.IsConnectionOpen() {
		return fmt.Errorf("mqtt client not connected")
	}

	token := client.Publish(topic, 1, false, payload)
	token.Wait()
	return token.Error()
}

func (m *Manager) Close(timeout time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.client != nil {
		m.client.Disconnect(uint(timeout.Milliseconds()))
	}
}

func (m *Manager) forceSafeRelays(client paho.Client) {
	for _, topic := range []string{topicRelay6, topicRelay7} {
		token := client.Publish(topic, 1, false, "OFF")
		token.Wait()
		if token.Error() != nil {
			log.Printf("mqtt safe publish error on %s: %v", topic, token.Error())
		}
	}

	m.state.SetBoth(false, false)
}

func (m *Manager) handleSensorMessage(_ paho.Client, message paho.Message) {
	var payload models.SensorPayload
	if err := json.Unmarshal(message.Payload(), &payload); err != nil {
		log.Printf("invalid sensor payload: %v", err)
		return
	}

	createdAt := time.Now().UTC()
	if payload.Timestamp != "" {
		parsedTime, err := time.Parse(time.RFC3339, payload.Timestamp)
		if err != nil {
			log.Printf("invalid sensor timestamp %q: %v", payload.Timestamp, err)
		} else {
			createdAt = parsedTime.UTC()
		}
	}

	data := models.SensorData{
		Exterior:   payload.Temperaturas.Exterior,
		Interior:   payload.Temperaturas.Interior,
		Deposito:   payload.Temperaturas.Deposito,
		Ambiente2:  payload.Temperaturas.Ambiente2,
		VoltajeBat: payload.VoltajeBat,
		VoltajeBat2: payload.VoltajeBat2,
		CreatedAt:  createdAt,
	}

	if err := storage.SaveSensorData(m.db, data); err != nil {
		log.Printf("saving sensor data: %v", err)
	}
}

func normalizeBrokerURL(broker string) string {
	trimmed := strings.TrimSpace(broker)
	if strings.HasPrefix(trimmed, "tcp://") || strings.HasPrefix(trimmed, "ssl://") || strings.HasPrefix(trimmed, "ws://") || strings.HasPrefix(trimmed, "wss://") {
		return trimmed
	}
	return fmt.Sprintf("tcp://%s:1883", trimmed)
}

func normalizeBrokerURLWithPort(broker string, port uint16, scheme string) string {
	trimmed := strings.TrimSpace(broker)
	if strings.HasPrefix(trimmed, "tcp://") || strings.HasPrefix(trimmed, "ssl://") || strings.HasPrefix(trimmed, "ws://") || strings.HasPrefix(trimmed, "wss://") {
		return trimmed
	}
	if port == 0 {
		if scheme == "ssl" {
			port = 8883
		} else {
			port = 1883
		}
	}
	return fmt.Sprintf("%s://%s:%d", scheme, trimmed, port)
}
