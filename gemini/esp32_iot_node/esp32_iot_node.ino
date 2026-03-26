/*
 * ESP32 IoT Node - Provisioning BLE, MQTT & Sensors
 * 
 * Requisitos:
 * - Librerías: PubSubClient, ArduinoJson, OneWire, DallasTemperature
 * - Hardware: ESP32, 4x DS18B20, 2x Relés, Divisor de tensión para batería
 */

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Preferences.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

// --- Configuración de Pines ---
#define ONE_WIRE_BUS 4      // Pin para los 4 sensores DS18B20
#define PIN_BATERIA 34      // ADC para Batería 1
#define PIN_BATERIA_2 35    // ADC para Batería 2
#define PIN_RELE_6 18       // Relé 6
#define PIN_RELE_7 19       // Relé 7

// --- UUIDs para BLE ---
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// --- Parámetros de Tiempo ---
const unsigned long INTERVALO_ENVIO = 5 * 60 * 1000; // 5 minutos en ms
unsigned long ultimoEnvio = 0;

// --- Objetos ---
Preferences preferences;
WiFiClient espClient;
PubSubClient client(espClient);
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

// --- Variables de Configuración ---
String wifi_ssid = "";
String wifi_pass = "";
String mqtt_broker = "";
bool provisioningMode = false;
bool shouldRestart = false;

// --- Direcciones de Sensores DS18B20 ---
const char* nombresSensores[] = {"Exterior", "Interior", "Deposito", "Ambiente2"};

// --- Prototipos de Funciones ---
void setupBLEProvisioning();
void loadConfig();
void setupWifi();
void mqttCallback(char* topic, byte* payload, unsigned int length);
void reconnectMQTT();
void readAndPublishSensors();
float readBatteryVoltage(int pin);
void saveConfig(String s, String p, String m);

// --- Callbacks de BLE ---
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String data = pCharacteristic->getValue().c_str();
      if (data.length() > 0) {
        Serial.println("BLE Recibido: " + data);
        
        StaticJsonDocument<256> doc;
        DeserializationError error = deserializeJson(doc, data);

        if (!error) {
          String s = doc["ssid"] | "";
          String p = doc["pass"] | "";
          String m = doc["mqtt_ip"] | "";

          if (s != "" && m != "") {
            saveConfig(s, p, m);
          } else {
            Serial.println("JSON incompleto. Se requiere 'ssid' y 'mqtt_ip'");
          }
        } else {
          Serial.println("Error parseando JSON: " + String(error.c_str()));
          // Si falla el JSON, intentamos el formato antiguo por si acaso: SSID;PASS;MQTT_IP
          int firstSemi = data.indexOf(';');
          int secondSemi = data.indexOf(';', firstSemi + 1);
          if (firstSemi > 0 && secondSemi > firstSemi) {
            String s = data.substring(0, firstSemi);
            String p = data.substring(firstSemi + 1, secondSemi);
            String m = data.substring(secondSemi + 1);
            saveConfig(s, p, m);
          }
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  delay(1000); 
  
  pinMode(PIN_RELE_6, OUTPUT);
  pinMode(PIN_RELE_7, OUTPUT);
  digitalWrite(PIN_RELE_6, LOW);
  digitalWrite(PIN_RELE_7, LOW);

  sensors.begin();
  int count = sensors.getDeviceCount();
  Serial.println("\n--- DIAGNÓSTICO DE HARDWARE ---");
  Serial.print("Sensores DS18B20 encontrados: ");
  Serial.println(count);
  if (count == 0) {
    Serial.println("ALERTA: No se detectan sensores en GPIO 4.");
    Serial.println("Verifica resistencia pull-up de 4.7k entre GPIO 4 y 3.3V.");
  }
  Serial.println("--------------------------------\n");

  loadConfig();

  if (wifi_ssid == "" || mqtt_broker == "") {
    provisioningMode = true;
    setupBLEProvisioning();
  } else {
    setupWifi();
    client.setServer(mqtt_broker.c_str(), 1883);
    client.setCallback(mqttCallback);
  }
}

void loop() {
  if (shouldRestart) {
    delay(2000);
    ESP.restart();
  }

  if (provisioningMode) return; // En modo BLE no hacemos nada más

  if (WiFi.status() != WL_CONNECTED) {
    setupWifi();
  }
  if (!client.connected()) {
    reconnectMQTT();
  }
  client.loop();

  unsigned long currentMillis = millis();
  if (currentMillis - ultimoEnvio >= INTERVALO_ENVIO) {
    ultimoEnvio = currentMillis;
    readAndPublishSensors();
  }
}

// --- Gestión de Configuración ---
void loadConfig() {
  preferences.begin("iot-config", true);
  wifi_ssid = preferences.getString("ssid", "");
  wifi_pass = preferences.getString("pass", "");
  mqtt_broker = preferences.getString("mqtt", "");
  preferences.end();
}

void saveConfig(String s, String p, String m) {
  preferences.begin("iot-config", false);
  preferences.putString("ssid", s);
  preferences.putString("pass", p);
  preferences.putString("mqtt", m);
  preferences.end();
  Serial.println("Configuración guardada correctamente.");
  Serial.println("Reiniciando sistema en 2 segundos...");
  shouldRestart = true;
}

// --- Aprovisionamiento BLE ---
void setupBLEProvisioning() {
  Serial.println("Modo Aprovisionamiento BLE activado.");
  BLEDevice::init("ESP32_IoT_Node");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_WRITE
                                       );

  pCharacteristic->setCallbacks(new MyCallbacks());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("Esperando conexión BLE para configurar...");
}

// --- Conectividad ---
void setupWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  
  Serial.print("Conectando a ");
  Serial.println(wifi_ssid);
  
  WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());
  
  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 20) {
    delay(500);
    Serial.print(".");
    retry++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Conectado. IP: " + WiFi.localIP().toString());
  }
}

void reconnectMQTT() {
  while (!client.connected()) {
    Serial.print("Intentando conexión MQTT...");
    String clientId = "ESP32Client-" + String(random(0xffff), HEX);
    
    if (client.connect(clientId.c_str())) {
      Serial.println("Conectado!");
      // Suscribirse a tópicos
      client.subscribe("casa/peticion");
      client.subscribe("casa/rele/6");
      client.subscribe("casa/rele/7");
    } else {
      Serial.print("Error, rc=");
      Serial.print(client.state());
      Serial.println(" Reintentando en 5 segundos...");
      delay(5000);
    }
  }
}

// --- Callback MQTT (Actuadores y Peticiones) ---
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.println("Mensaje recibido [" + String(topic) + "]: " + message);

  if (String(topic) == "casa/rele/6") {
    if (message == "ON") digitalWrite(PIN_RELE_6, HIGH);
    else if (message == "OFF") digitalWrite(PIN_RELE_6, LOW);
  } 
  else if (String(topic) == "casa/rele/7") {
    if (message == "ON") digitalWrite(PIN_RELE_7, HIGH);
    else if (message == "OFF") digitalWrite(PIN_RELE_7, LOW);
  }
  else if (String(topic) == "casa/peticion") {
    if (message == "GET_DATA") {
      readAndPublishSensors();
    }
  }
}
void readAndPublishSensors() {
  sensors.requestTemperatures();
  int deviceCount = sensors.getDeviceCount();

  StaticJsonDocument<512> doc;

  // Lectura segura de sensores de temperatura
  float temps[4];
  for (int i = 0; i < 4; i++) {
    temps[i] = (i < deviceCount) ? sensors.getTempCByIndex(i) : DEVICE_DISCONNECTED_C;
    
    if (temps[i] == DEVICE_DISCONNECTED_C) {
      doc[nombresSensores[i]] = 0.0;
    } else {
      doc[nombresSensores[i]] = serialized(String(temps[i], 2));
    }
  }

  doc["VoltajeBateria"] = serialized(String(readBatteryVoltage(PIN_BATERIA), 2));
  doc["VoltajeBateria2"] = serialized(String(readBatteryVoltage(PIN_BATERIA_2), 2));
  doc["uptime_sec"] = millis() / 1000;

  char buffer[512];
  serializeJson(doc, buffer);

  client.publish("casa/estado/sensores", buffer);
  Serial.println("Datos publicados: " + String(buffer));
}

float readBatteryVoltage(int pin) {
  // Asumiendo divisor de tensión: R1=10k, R2=2.2k (aprox para 12-15V a 3.3V)
  // V_pin = V_bat * (R2 / (R1 + R2))
  // Factor de corrección: (R1 + R2) / R2
  const float factorCorreccion = 5.54; // Ajustar según resistencias reales
  int analogValue = analogRead(pin);
  float voltageAtPin = (analogValue / 4095.0) * 3.3;
  return voltageAtPin * factorCorreccion;
}
