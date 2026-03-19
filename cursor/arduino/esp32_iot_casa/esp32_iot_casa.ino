/*
  ESP32 - IoT Casa (Versión con Trazas de Depuración)
  Mantiene el fix del flag para peticiones manuales y recupera los mensajes Serial.
*/

#include <WiFi.h>
#include <Preferences.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// =================== CONFIGURACIÓN DE HARDWARE ===================
const int ONE_WIRE_BUS = 4;
const int BATTERY_PIN  = 34;
const int BATTERY2_PIN = 35;
const int RELAY6_PIN   = 26;
const int RELAY7_PIN   = 27;

const float ADC_MAX = 4095.0;
const float ADC_REF_V = 3.3;
const float R1 = 100000.0; 
const float R2 = 47000.0;

// =================== CONFIGURACIÓN DE MQTT & TIEMPOS ===================
const uint16_t MQTT_PORT = 1883;
const char *TOPIC_SENSORS = "casa/estado/sensores";
const char *TOPIC_REQUEST = "casa/peticion";
const char *TOPIC_RELAY6  = "casa/rele/6";
const char *TOPIC_RELAY7  = "casa/rele/7";

const unsigned long PUBLISH_INTERVAL_MS = 300000UL; 
unsigned long lastPublishMillis = 0;
bool peticionManual = false; 

// =================== OBJETOS GLOBALES ===================
WiFiClient espClient;
PubSubClient mqttClient(espClient);
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);
Preferences prefs;

String wifiSsid, wifiPass, mqttIp;
bool hasConfig = false, bleMode = false;

// =================== LECTURA DE SENSORES ===================

float getBatteryV(int pin) {
  int raw = analogRead(pin);
  float vOut = (raw / ADC_MAX) * ADC_REF_V;
  return vOut * (R1 + R2) / R2;
}

void publishSensorData() {
  Serial.println("--- Iniciando lectura de sensores ---");
  sensors.requestTemperatures();
  
  float tExt  = sensors.getTempCByIndex(0);
  float tInt  = sensors.getTempCByIndex(1);
  float tDep  = sensors.getTempCByIndex(2);
  float tAmb2 = sensors.getTempCByIndex(3);
  
  // Log de temperaturas para verificar el error -127
  Serial.printf("Temps: Ext:%.2f, Int:%.2f, Dep:%.2f, Amb2:%.2f\n", tExt, tInt, tDep, tAmb2);

  float vBat  = getBatteryV(BATTERY_PIN);
  float vBat2 = getBatteryV(BATTERY2_PIN);
  time_t now = time(nullptr);

  StaticJsonDocument<256> doc;
  doc["temp_exterior"] = (tExt == -127.0) ? 0.0 : tExt;
  doc["temp_interior"] = (tInt == -127.0) ? 0.0 : tInt;
  doc["temp_deposito"] = (tDep == -127.0) ? 0.0 : tDep;
  doc["temp_ambiente2"] = (tAmb2 == -127.0) ? 0.0 : tAmb2;
  doc["bateria_v"] = vBat;
  doc["voltaje_bat_2"] = vBat2;
  doc["timestamp"] = static_cast<long>(now);

  char buffer[256];
  serializeJson(doc, buffer);

  if (mqttClient.connected()) {
    if (mqttClient.publish(TOPIC_SENSORS, buffer)) {
      Serial.print("MQTT Publicado con éxito: ");
      Serial.println(buffer);
    } else {
      Serial.println("Error: Fallo al publicar en MQTT");
    }
  } else {
    Serial.println("Error: MQTT no conectado al intentar publicar");
  }
}

// =================== MQTT CALLBACK ===================

void mqttCallback(char *topic, byte *payload, unsigned int length) {
  String t = String(topic);
  String msg = "";
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  msg.trim();

  Serial.print("Mensaje recibido en [");
  Serial.print(t);
  Serial.print("]: ");
  Serial.println(msg);

  if (t == TOPIC_REQUEST && msg == "GET_DATA") {
    Serial.println("Petición manual detectada. Agendando lectura...");
    peticionManual = true; 
  } else if (t == TOPIC_RELAY6) {
    Serial.print("Cambiando Relé 6 a: "); Serial.println(msg);
    digitalWrite(RELAY6_PIN, (msg == "ON") ? HIGH : LOW);
  } else if (t == TOPIC_RELAY7) {
    Serial.print("Cambiando Relé 7 a: "); Serial.println(msg);
    digitalWrite(RELAY7_PIN, (msg == "ON") ? HIGH : LOW);
  }
}

// =================== GESTIÓN DE CONEXIONES ===================

void ensureConnections() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi desconectado. Reconectando...");
    WiFi.begin(wifiSsid.c_str(), wifiPass.c_str());
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 10000) {
      delay(500);
      Serial.print(".");
    }
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\nWiFi Reconectado!");
      configTime(0, 0, "pool.ntp.org");
    }
  }

  if (WiFi.status() == WL_CONNECTED && !mqttClient.connected()) {
    Serial.println("Iniciando conexión MQTT...");
    mqttClient.setServer(mqttIp.c_str(), MQTT_PORT);
    String clientId = "esp32-" + String(random(0xffff), HEX);
    if (mqttClient.connect(clientId.c_str())) {
      Serial.println("MQTT Conectado!");
      mqttClient.subscribe(TOPIC_REQUEST);
      mqttClient.subscribe(TOPIC_RELAY6);
      mqttClient.subscribe(TOPIC_RELAY7);
    } else {
      Serial.print("Fallo MQTT, rc=");
      Serial.println(mqttClient.state());
    }
  }
}

// =================== MODO BLE & PREFS ===================

void loadConfig() {
  prefs.begin("iot_cfg", true);
  hasConfig = prefs.getBool("configured", false);
  if (hasConfig) {
    wifiSsid = prefs.getString("ssid", "");
    wifiPass = prefs.getString("pass", "");
    mqttIp   = prefs.getString("mqttip", "");
    Serial.println("Configuración cargada desde NVS.");
  } else {
    Serial.println("No se encontró configuración previa.");
  }
  prefs.end();
}

class BLECallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) override {
    String value = pChar->getValue();
    Serial.println("Datos recibidos por BLE!");
    StaticJsonDocument<256> doc;
    deserializeJson(doc, value);
    
    prefs.begin("iot_cfg", false);
    prefs.putString("ssid", doc["ssid"] | "");
    prefs.putString("pass", doc["pass"] | "");
    prefs.putString("mqttip", doc["mqtt_ip"] | "");
    prefs.putBool("configured", true);
    prefs.end();
    
    Serial.println("Configuración guardada. Reiniciando...");
    delay(1000); 
    ESP.restart();
  }
};

void startBLE() {
  bleMode = true;
  Serial.println("Iniciando Modo Configuración (BLE)...");
  BLEDevice::init("ESP32_Config");
  BLEServer *pS = BLEDevice::createServer();
  BLEService *pServ = pS->createService("12345678-1234-1234-1234-1234567890ab");
  BLECharacteristic *pC = pServ->createCharacteristic("abcd1234-5678-90ab-cdef-1234567890ab", BLECharacteristic::PROPERTY_WRITE);
  pC->setCallbacks(new BLECallbacks());
  pServ->start();
  BLEDevice::getAdvertising()->start();
  Serial.println("Esperando JSON por BLE...");
}

// =================== SETUP & LOOP ===================

void setup() {
  Serial.begin(115200);
  Serial.println("\n--- SISTEMA ARRANCANDO ---");
  
  pinMode(RELAY6_PIN, OUTPUT);
  pinMode(RELAY7_PIN, OUTPUT);
  
  Serial.println("Iniciando sensores Dallas...");
  sensors.begin();
  
  loadConfig();
  mqttClient.setCallback(mqttCallback);

  if (!hasConfig) {
    startBLE();
  } else {
    Serial.println("Intentando conexión WiFi inicial...");
    ensureConnections();
  }
}

void loop() {
  if (bleMode) return;

  ensureConnections();
  mqttClient.loop();

  unsigned long now = millis();

  // Publicación periódica
  if (now - lastPublishMillis >= PUBLISH_INTERVAL_MS) {
    lastPublishMillis = now;
    Serial.println("Toca publicación automática.");
    publishSensorData();
  }

  // Publicación manual (Atiende la bandera del callback)
  if (peticionManual) {
    Serial.println("Atendiendo petición manual del loop.");
    publishSensorData();
    peticionManual = false;
  }
  
  delay(10);
}