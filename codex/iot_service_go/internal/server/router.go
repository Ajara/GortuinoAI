package server

import (
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"iot_service_go/internal/auth"
	"iot_service_go/internal/handlers"
)

func NewRouter(api *handlers.APIHandler, jwtManager *auth.JWTManager) *gin.Engine {
	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery())
	router.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: false,
		MaxAge:           12 * time.Hour,
	}))

	router.POST("/setup", api.Setup)
	router.POST("/login", api.Login)

	apiGroup := router.Group("/api")
	apiGroup.Use(AuthMiddleware(jwtManager))
	apiGroup.GET("/actual", api.GetActual)
	apiGroup.GET("/historico", api.GetHistorico)
	apiGroup.POST("/sensores/live", api.RequestLiveSensors)
	apiGroup.POST("/valvula/:id", api.ActivateValve)

	return router
}
