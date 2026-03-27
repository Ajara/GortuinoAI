/*
  ESP32 IoT - Sensores + MQTT + Provisionamiento BLE

  Funcionalidad:
  - Si no hay credenciales guardadas, entra en modo provisionamiento BLE.
  - Recibe por BLE el SSID, password WiFi y broker MQTT.
  - Soporta usuario y password para el broker MQTT.
  - Guarda la configuracion en Preferences.
  - Lee 4 sensores DS18B20 y 1 entrada analogica para bateria.
  - Publica datos cada 5 minutos en formato JSON por MQTT.
  - Atiende peticiones GET_DATA en casa/peticion.
  - Controla dos reles por MQTT en casa/rele/6 y casa/rele/7.
  - Reconexion automatica de WiFi y MQTT.

  Librerias necesarias:
  - WiFi
  - Preferences
  - PubSubClient
  - ArduinoJson
  - OneWire
  - DallasTemperature
  - BLEDevice
  - BLEServer
  - BLEUtils
  - BLE2902

  Provisionamiento BLE:
  - Nombre BLE: ESP32_PROVISIONING
  - Servicio UART BLE estilo Nordic UART Service

  Mensajes soportados por BLE:
  1. JSON:
     {"ssid":"MiWiFi","password":"MiClave","mqtt":"192.168.1.100","mqtt_user":"usuario","mqtt_password":"secreta"}

  2. Texto plano:
     SSID=MiWiFi;PASS=MiClave;MQTT=192.168.1.100;MQTT_USER=usuario;MQTT_PASS=secreta

  Comando adicional BLE:
  - RESET_CONFIG
*/

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Preferences.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <time.h>

// =========================
// CONFIGURACION DE HARDWARE
// =========================
#define ONE_WIRE_BUS   4
#define VOLTAGE_PIN    34
#define VOLTAGE_PIN_2  35
#define RELAY6_PIN     26
#define RELAY7_PIN     27

// Ajustar segun el divisor real de tension usado para la bateria.
#define ADC_VREF       3.3f
#define ADC_RESOLUTION 4095.0f
#define DIVIDER_R1     30000.0f
#define DIVIDER_R2     7500.0f

// Intervalo de publicacion automatica.
const unsigned long PUBLISH_INTERVAL_MS = 5UL * 60UL * 1000UL;
const uint16_t MQTT_PORT_PLAIN = 1883;
const uint16_t MQTT_PORT_TLS = 8883;
const char *NTP_SERVER_1 = "pool.ntp.org";
const char *NTP_SERVER_2 = "time.nist.gov";

// =========================
// TOPICOS MQTT
// =========================
const char *TOPIC_SENSORS = "casa/estado/sensores";
const char *TOPIC_REQUEST = "casa/peticion";
const char *TOPIC_RELAY6  = "casa/rele/6";
const char *TOPIC_RELAY7  = "casa/rele/7";

// =========================
// BLE UART
// =========================
#define BLE_DEVICE_NAME "ESP32_PROVISIONING"

static BLEUUID SERVICE_UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
static BLEUUID CHAR_RX_UUID("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
static BLEUUID CHAR_TX_UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

Preferences preferences;
WiFiClient wifiClient;
WiFiClientSecure wifiSecureClient;
PubSubClient mqttClient(wifiClient);

OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature ds18b20(&oneWire);
DeviceAddress dsAddresses[4];
uint8_t detectedSensorCount = 0;

BLEServer *bleServer = nullptr;
BLECharacteristic *bleTxCharacteristic = nullptr;

bool bleClientConnected = false;
bool provisioningMode = false;
bool timeSynced = false;

String wifiSSID;
String wifiPassword;
String mqttBroker;
String mqttUsername;
String mqttPassword;
String mqttCaCert;
uint16_t mqttPort = MQTT_PORT_PLAIN;
bool mqttSecure = false;

unsigned long lastPublishTime = 0;

const char *temperatureLabels[4] = {
  "exterior",
  "interior",
  "deposito",
  "ambiente2"
};

void printAddress(const DeviceAddress address) {
  for (uint8_t i = 0; i < 8; i++) {
    if (address[i] < 16) {
      Serial.print("0");
    }
    Serial.print(address[i], HEX);
  }
}

void scanTemperatureSensors() {
  detectedSensorCount = ds18b20.getDeviceCount();
  Serial.print("DS18B20 detectados en bus 1-Wire: ");
  Serial.println(detectedSensorCount);

  for (uint8_t i = 0; i < 4; i++) {
    if (ds18b20.getAddress(dsAddresses[i], i)) {
      Serial.print("Sensor ");
      Serial.print(i);
      Serial.print(" (");
      Serial.print(temperatureLabels[i]);
      Serial.print(") direccion: ");
      printAddress(dsAddresses[i]);
      Serial.println();
      ds18b20.setResolution(dsAddresses[i], 12);
    } else {
      memset(dsAddresses[i], 0, sizeof(DeviceAddress));
      Serial.print("Sensor ");
      Serial.print(i);
      Serial.print(" (");
      Serial.print(temperatureLabels[i]);
      Serial.println(") no disponible en ese indice.");
    }
  }
}

void printAdcDiagnostics() {
  int raw = analogRead(VOLTAGE_PIN);
  float pinVoltage = (raw / ADC_RESOLUTION) * ADC_VREF;
  float batteryVoltage = pinVoltage * ((DIVIDER_R1 + DIVIDER_R2) / DIVIDER_R2);
  int raw2 = analogRead(VOLTAGE_PIN_2);
  float pinVoltage2 = (raw2 / ADC_RESOLUTION) * ADC_VREF;
  float batteryVoltage2 = pinVoltage2 * ((DIVIDER_R1 + DIVIDER_R2) / DIVIDER_R2);

  Serial.print("ADC pin ");
  Serial.print(VOLTAGE_PIN);
  Serial.print(" crudo: ");
  Serial.print(raw);
  Serial.print(" | Vpin: ");
  Serial.print(pinVoltage, 3);
  Serial.print(" V | Vbat estimada: ");
  Serial.print(batteryVoltage, 3);
  Serial.println(" V");

  Serial.print("ADC pin ");
  Serial.print(VOLTAGE_PIN_2);
  Serial.print(" crudo: ");
  Serial.print(raw2);
  Serial.print(" | Vpin: ");
  Serial.print(pinVoltage2, 3);
  Serial.print(" V | Vbat2 estimada: ");
  Serial.print(batteryVoltage2, 3);
  Serial.println(" V");
}

void bleSend(const String &message) {
  Serial.println("[BLE] " + message);
  if (bleTxCharacteristic != nullptr && bleClientConnected) {
    bleTxCharacteristic->setValue(message.c_str());
    bleTxCharacteristic->notify();
  }
}

void saveConfig(
  const String &ssid,
  const String &password,
  const String &broker,
  const String &mqttUser,
  const String &mqttPass,
  bool useSecureMqtt,
  uint16_t brokerPort,
  const String &caCert
) {
  preferences.begin("config", false);
  preferences.putString("wifi_ssid", ssid);
  preferences.putString("wifi_pass", password);
  preferences.putString("mqtt_host", broker);
  preferences.putString("mqtt_user", mqttUser);
  preferences.putString("mqtt_pass", mqttPass);
  preferences.putBool("mqtt_secure", useSecureMqtt);
  preferences.putUShort("mqtt_port", brokerPort);
  preferences.putString("mqtt_ca", caCert);
  preferences.end();
}

void loadConfig() {
  preferences.begin("config", true);
  wifiSSID = preferences.getString("wifi_ssid", "");
  wifiPassword = preferences.getString("wifi_pass", "");
  mqttBroker = preferences.getString("mqtt_host", "");
  mqttUsername = preferences.getString("mqtt_user", "");
  mqttPassword = preferences.getString("mqtt_pass", "");
  mqttSecure = preferences.getBool("mqtt_secure", false);
  mqttPort = preferences.getUShort(
    "mqtt_port",
    mqttSecure ? MQTT_PORT_TLS : MQTT_PORT_PLAIN
  );
  mqttCaCert = preferences.getString("mqtt_ca", "");
  preferences.end();
}

void clearConfig() {
  preferences.begin("config", false);
  preferences.clear();
  preferences.end();
}

bool hasValidConfig() {
  loadConfig();
  return wifiSSID.length() > 0 && mqttBroker.length() > 0;
}

float readBatteryVoltage(uint8_t pin) {
  const int sampleCount = 10;
  uint32_t accumulator = 0;

  for (int i = 0; i < sampleCount; i++) {
    accumulator += analogRead(pin);
    delay(5);
  }

  float adcAverage = accumulator / (float)sampleCount;
  float pinVoltage = (adcAverage / ADC_RESOLUTION) * ADC_VREF;
  float batteryVoltage = pinVoltage * ((DIVIDER_R1 + DIVIDER_R2) / DIVIDER_R2);
  return batteryVoltage;
}

void printTemperatureDiagnostics() {
  ds18b20.requestTemperatures();
  for (uint8_t i = 0; i < 4; i++) {
    Serial.print("Temp ");
    Serial.print(i);
    Serial.print(" (");
    Serial.print(temperatureLabels[i]);
    Serial.print("): ");

    float value = ds18b20.getTempCByIndex(i);
    if (value == DEVICE_DISCONNECTED_C) {
      Serial.println("desconectado / no leido");
    } else {
      Serial.print(value, 2);
      Serial.println(" C");
    }
  }
}

void setRelayState(uint8_t pin, const String &message) {
  if (message == "ON") {
    digitalWrite(pin, HIGH);
  } else if (message == "OFF") {
    digitalWrite(pin, LOW);
  }
}

bool syncClock() {
  if (timeSynced) {
    return true;
  }

  configTime(0, 0, NTP_SERVER_1, NTP_SERVER_2);

  struct tm timeInfo;
  for (int i = 0; i < 10; i++) {
    if (getLocalTime(&timeInfo, 1000)) {
      timeSynced = true;
      Serial.println("Reloj sincronizado por NTP.");
      return true;
    }
  }

  Serial.println("No se pudo sincronizar la hora por NTP.");
  return false;
}

String currentTimestampUtc() {
  struct tm timeInfo;
  if (!getLocalTime(&timeInfo, 1000)) {
    return "";
  }

  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeInfo);
  return String(buffer);
}

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  Serial.println("Conectando WiFi...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && (millis() - start) < 15000UL) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("WiFi conectado. IP: ");
    Serial.println(WiFi.localIP());
    syncClock();
  } else {
    Serial.println("No fue posible conectar WiFi.");
  }
}

void publishSensorData() {
  if (!mqttClient.connected()) {
    return;
  }

  printTemperatureDiagnostics();
  printAdcDiagnostics();
  ds18b20.requestTemperatures();

  StaticJsonDocument<384> doc;
  JsonObject temperatures = doc.createNestedObject("temperaturas");

  for (int i = 0; i < 4; i++) {
    float value = ds18b20.getTempCByIndex(i);
    if (value == DEVICE_DISCONNECTED_C) {
      temperatures[temperatureLabels[i]] = nullptr;
    } else {
      temperatures[temperatureLabels[i]] = value;
    }
  }

  doc["voltaje_bateria"] = readBatteryVoltage(VOLTAGE_PIN);
  doc["voltaje_bat_2"] = readBatteryVoltage(VOLTAGE_PIN_2);
  doc["wifi_rssi"] = WiFi.RSSI();
  doc["ip"] = WiFi.localIP().toString();
  String timestamp = currentTimestampUtc();
  if (timestamp.length() > 0) {
    doc["timestamp"] = timestamp;
  }

  char payload[448];
  serializeJson(doc, payload);

  if (mqttClient.publish(TOPIC_SENSORS, payload, true)) {
    Serial.print("Publicado: ");
    Serial.println(payload);
  } else {
    Serial.println("Error publicando en MQTT.");
  }
}

void mqttCallback(char *topic, byte *payload, unsigned int length) {
  String message;
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }

  String topicStr = String(topic);
  Serial.print("MQTT [");
  Serial.print(topicStr);
  Serial.print("] -> ");
  Serial.println(message);

  if (topicStr == TOPIC_REQUEST && message == "GET_DATA") {
    publishSensorData();
    return;
  }

  if (topicStr == TOPIC_RELAY6) {
    setRelayState(RELAY6_PIN, message);
    return;
  }

  if (topicStr == TOPIC_RELAY7) {
    setRelayState(RELAY7_PIN, message);
  }
}

void connectMQTT() {
  if (WiFi.status() != WL_CONNECTED || mqttClient.connected()) {
    return;
  }

  Serial.println("Conectando MQTT...");
  String clientId = "ESP32_" + String((uint32_t)ESP.getEfuseMac(), HEX);

  if (mqttSecure) {
    mqttClient.setClient(wifiSecureClient);
    if (mqttCaCert.length() > 0) {
      wifiSecureClient.setCACert(mqttCaCert.c_str());
      Serial.println("MQTT TLS con validacion de certificado.");
    } else {
      wifiSecureClient.setInsecure();
      Serial.println("MQTT TLS sin CA configurada. Conexion cifrada sin validacion del servidor.");
    }
  } else {
    mqttClient.setClient(wifiClient);
  }

  bool connected = false;
  if (mqttUsername.length() > 0) {
    connected = mqttClient.connect(clientId.c_str(), mqttUsername.c_str(), mqttPassword.c_str());
  } else {
    connected = mqttClient.connect(clientId.c_str());
  }

  if (connected) {
    Serial.println("MQTT conectado.");
    mqttClient.subscribe(TOPIC_REQUEST);
    mqttClient.subscribe(TOPIC_RELAY6);
    mqttClient.subscribe(TOPIC_RELAY7);
  } else {
    Serial.print("Fallo MQTT, state=");
    Serial.println(mqttClient.state());
  }
}

bool parseProvisioningPayload(const String &data) {
  String ssid;
  String password;
  String broker;
  String mqttUser;
  String mqttPass;
  String mqttCa;
  uint16_t parsedMqttPort = MQTT_PORT_PLAIN;
  bool useSecureMqtt = false;

  StaticJsonDocument<1536> jsonDoc;
  DeserializationError error = deserializeJson(jsonDoc, data);

  if (!error) {
    ssid = jsonDoc["ssid"] | "";
    password = jsonDoc["password"] | jsonDoc["pass"] | "";
    broker = jsonDoc["mqtt"] | jsonDoc["mqtt_ip"] | jsonDoc["broker"] | "";
    mqttUser = jsonDoc["mqtt_user"] | jsonDoc["mqtt_username"] | "";
    mqttPass = jsonDoc["mqtt_password"] | jsonDoc["mqtt_pass"] | "";
    mqttCa = jsonDoc["mqtt_ca"] | jsonDoc["ca_cert"] | "";
    useSecureMqtt = jsonDoc["mqtt_secure"] | jsonDoc["mqtt_tls"] | false;
    parsedMqttPort = jsonDoc["mqtt_port"] |
      (useSecureMqtt ? MQTT_PORT_TLS : MQTT_PORT_PLAIN);
  } else {
    int ssidStart = data.indexOf("SSID=");
    int passStart = data.indexOf("PASS=");
    int mqttStart = data.indexOf("MQTT=");
    int mqttUserStart = data.indexOf("MQTT_USER=");
    int mqttPassStart = data.indexOf("MQTT_PASS=");
    int mqttSecureStart = data.indexOf("MQTT_SECURE=");
    int mqttPortStart = data.indexOf("MQTT_PORT=");

    if (ssidStart >= 0) {
      int end = data.indexOf(';', ssidStart);
      if (end < 0) {
        end = data.length();
      }
      ssid = data.substring(ssidStart + 5, end);
    }

    if (passStart >= 0) {
      int end = data.indexOf(';', passStart);
      if (end < 0) {
        end = data.length();
      }
      password = data.substring(passStart + 5, end);
    }

    if (mqttStart >= 0) {
      int end = data.indexOf(';', mqttStart);
      if (end < 0) {
        end = data.length();
      }
      broker = data.substring(mqttStart + 5, end);
    }

    if (mqttUserStart >= 0) {
      int end = data.indexOf(';', mqttUserStart);
      if (end < 0) {
        end = data.length();
      }
      mqttUser = data.substring(mqttUserStart + 10, end);
    }

    if (mqttPassStart >= 0) {
      int end = data.indexOf(';', mqttPassStart);
      if (end < 0) {
        end = data.length();
      }
      mqttPass = data.substring(mqttPassStart + 10, end);
    }

    if (mqttSecureStart >= 0) {
      int end = data.indexOf(';', mqttSecureStart);
      if (end < 0) {
        end = data.length();
      }
      String secureValue = data.substring(mqttSecureStart + 12, end);
      secureValue.trim();
      useSecureMqtt = secureValue == "1" || secureValue.equalsIgnoreCase("true");
    }

    if (mqttPortStart >= 0) {
      int end = data.indexOf(';', mqttPortStart);
      if (end < 0) {
        end = data.length();
      }
      parsedMqttPort = (uint16_t)data.substring(mqttPortStart + 10, end).toInt();
    } else {
      parsedMqttPort = useSecureMqtt ? MQTT_PORT_TLS : MQTT_PORT_PLAIN;
    }
  }

  ssid.trim();
  password.trim();
  broker.trim();
  mqttUser.trim();
  mqttPass.trim();
  mqttCa.trim();

  if (ssid.length() == 0 || broker.length() == 0) {
    return false;
  }

  if (parsedMqttPort == 0) {
    parsedMqttPort = useSecureMqtt ? MQTT_PORT_TLS : MQTT_PORT_PLAIN;
  }

  saveConfig(
    ssid,
    password,
    broker,
    mqttUser,
    mqttPass,
    useSecureMqtt,
    parsedMqttPort,
    mqttCa
  );
  return true;
}

class BleServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    (void)server;
    bleClientConnected = true;
    Serial.println("Cliente BLE conectado.");
  }

  void onDisconnect(BLEServer *server) override {
    (void)server;
    bleClientConnected = false;
    Serial.println("Cliente BLE desconectado.");
    BLEDevice::startAdvertising();
  }
};

class BleRxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    String data = characteristic->getValue();
    if (data.length() == 0) {
      return;
    }
    data.trim();

    Serial.print("BLE RX: ");
    Serial.println(data);

    if (data.equalsIgnoreCase("RESET_CONFIG")) {
      clearConfig();
      bleSend("Configuracion borrada. Reiniciando...");
      delay(1000);
      ESP.restart();
      return;
    }

    if (parseProvisioningPayload(data)) {
      bleSend("Configuracion guardada. Reiniciando...");
      delay(1000);
      ESP.restart();
    } else {
      bleSend("Formato invalido. Usa JSON o SSID=...;PASS=...;MQTT=...;MQTT_USER=...;MQTT_PASS=...;MQTT_SECURE=1;MQTT_PORT=8883");
    }
  }
};

void startBleProvisioning() {
  provisioningMode = true;

  BLEDevice::init(BLE_DEVICE_NAME);
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new BleServerCallbacks());

  BLEService *service = bleServer->createService(SERVICE_UUID);

  bleTxCharacteristic = service->createCharacteristic(
    CHAR_TX_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  bleTxCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic *bleRxCharacteristic = service->createCharacteristic(
    CHAR_RX_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  bleRxCharacteristic->setCallbacks(new BleRxCallbacks());

  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->start();

  Serial.println("Provisionamiento BLE activo.");
  Serial.println("Nombre BLE: " BLE_DEVICE_NAME);
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(RELAY6_PIN, OUTPUT);
  pinMode(RELAY7_PIN, OUTPUT);
  digitalWrite(RELAY6_PIN, LOW);
  digitalWrite(RELAY7_PIN, LOW);

  analogReadResolution(12);
  ds18b20.begin();
  scanTemperatureSensors();
  printTemperatureDiagnostics();
  printAdcDiagnostics();

  if (!hasValidConfig()) {
    Serial.println("Sin configuracion guardada. Iniciando BLE.");
    startBleProvisioning();
    return;
  }

  Serial.print("SSID configurado: ");
  Serial.println(wifiSSID);
  Serial.print("Broker MQTT: ");
  Serial.println(mqttBroker);
  Serial.print("Puerto MQTT: ");
  Serial.println(mqttPort);
  Serial.print("MQTT seguro: ");
  Serial.println(mqttSecure ? "si" : "no");
  Serial.print("Usuario MQTT: ");
  Serial.println(mqttUsername.length() > 0 ? mqttUsername : "(anonimo)");

  mqttClient.setServer(mqttBroker.c_str(), mqttPort);
  mqttClient.setCallback(mqttCallback);

  connectWiFi();
  connectMQTT();

  // Publicacion inicial poco despues del arranque si la conexion ya existe.
  lastPublishTime = millis() - PUBLISH_INTERVAL_MS + 5000UL;
}

void loop() {
  if (provisioningMode) {
    delay(100);
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  if (WiFi.status() == WL_CONNECTED && !mqttClient.connected()) {
    connectMQTT();
  }

  mqttClient.loop();

  unsigned long now = millis();
  if (now - lastPublishTime >= PUBLISH_INTERVAL_MS) {
    publishSensorData();
    lastPublishTime = now;
  }
}
