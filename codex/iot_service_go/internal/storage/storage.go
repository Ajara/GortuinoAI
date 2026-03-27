package storage

import (
	"errors"
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"

	"iot_service_go/internal/models"
)

func NewSQLiteDB(path string) (*gorm.DB, error) {
	return gorm.Open(sqlite.Open(path), &gorm.Config{})
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&models.User{}, &models.Config{}, &models.SensorData{})
}

func CountUsers(db *gorm.DB) (int64, error) {
	var count int64
	if err := db.Model(&models.User{}).Count(&count).Error; err != nil {
		return 0, err
	}
	return count, nil
}

func GetUserByUsername(db *gorm.DB, username string) (models.User, error) {
	var user models.User
	err := db.Where("username = ?", username).First(&user).Error
	return user, err
}

func CheckPasswordHash(hashedPassword, plainPassword string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(plainPassword))
}

func CreateInitialSetup(
	db *gorm.DB,
	username, password string,
	config models.Config,
) error {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	return db.Transaction(func(tx *gorm.DB) error {
		user := models.User{
			Username: username,
			Password: string(hashedPassword),
		}
		if err := tx.Create(&user).Error; err != nil {
			return err
		}

		config.ID = 1
		config.IsConfigured = true

		if err := tx.Save(&config).Error; err != nil {
			return err
		}

		return nil
	})
}

func GetConfig(db *gorm.DB) (models.Config, error) {
	var config models.Config
	err := db.First(&config).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return models.Config{}, models.ErrConfigNotFound
	}
	return config, err
}

func SaveSensorData(db *gorm.DB, data models.SensorData) error {
	if data.CreatedAt.IsZero() {
		data.CreatedAt = time.Now().UTC()
	}
	return db.Create(&data).Error
}

func GetLatestSensorData(db *gorm.DB) (models.SensorData, error) {
	var data models.SensorData
	err := db.Order("created_at desc").First(&data).Error
	return data, err
}

func GetSensorDataLast24Hours(db *gorm.DB) ([]models.SensorData, error) {
	var history []models.SensorData
	since := time.Now().UTC().Add(-24 * time.Hour)
	err := db.Where("created_at >= ?", since).Order("created_at asc").Find(&history).Error
	return history, err
}
