package models

import (
	"errors"
	"time"
)

var ErrConfigNotFound = errors.New("config not found")

type User struct {
	ID       uint   `gorm:"primaryKey" json:"id"`
	Username string `gorm:"uniqueIndex;size:100;not null" json:"username"`
	Password string `gorm:"size:255;not null" json:"-"`
}

type Config struct {
	ID           uint   `gorm:"primaryKey" json:"id"`
	MQTTBrokerIP string `gorm:"size:255;not null" json:"mqtt_broker_ip"`
	MQTTPort     uint16 `gorm:"not null;default:1883" json:"mqtt_port"`
	MQTTSecure   bool   `gorm:"not null;default:false" json:"mqtt_secure"`
	MQTTCA       string `gorm:"type:text" json:"mqtt_ca"`
	MQTTUsername string `gorm:"size:255" json:"mqtt_username"`
	MQTTPassword string `gorm:"size:255" json:"-"`
	IsConfigured bool   `gorm:"not null;default:false" json:"is_configured"`
}

type SensorData struct {
	ID         uint      `gorm:"primaryKey" json:"id"`
	Exterior   *float64  `json:"exterior"`
	Interior   *float64  `json:"interior"`
	Deposito   *float64  `json:"deposito"`
	Ambiente2  *float64  `json:"ambiente2"`
	VoltajeBat float64   `gorm:"column:voltaje_bat;not null" json:"voltaje_bat"`
	VoltajeBat2 float64  `gorm:"column:voltaje_bat_2;not null" json:"voltaje_bat_2"`
	CreatedAt  time.Time `gorm:"not null;index" json:"created_at"`
}

type SensorPayload struct {
	Temperaturas struct {
		Exterior  *float64 `json:"exterior"`
		Interior  *float64 `json:"interior"`
		Deposito  *float64 `json:"deposito"`
		Ambiente2 *float64 `json:"ambiente2"`
	} `json:"temperaturas"`
	VoltajeBat  float64 `json:"voltaje_bateria"`
	VoltajeBat2 float64 `json:"voltaje_bat_2"`
	Timestamp   string  `json:"timestamp"`
}
