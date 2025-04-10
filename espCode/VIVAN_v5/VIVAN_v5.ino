#include <esp_now.h>
#include <WiFi.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>
#include <ArduinoJson.h>  // JSON library

// Define GPS module pins
#define GPS_RX 16
#define GPS_TX 17

// Global Constant for Vehicle Number
const char VEHICLE_NUMBER[] = "ABC123";

// GPS Module & Serial Communication
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);

// ESP-NOW Data Structure
typedef struct struct_message {
  char msg[150];  // Buffer for JSON message
} struct_message;

struct_message myData;
struct_message incomingData;

// Broadcast address (FF:FF:FF:FF:FF:FF sends to all ESP-NOW devices)
uint8_t broadcastAddress[] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

// 📌 Initialize ESP-NOW
void initESPNow() {
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();

  if (esp_now_init() != ESP_OK) {
    Serial.println("{\"error\": \"ESP-NOW initialization failed!\"}");
    return;
  }

  esp_now_register_send_cb(OnDataSent);
  esp_now_register_recv_cb(OnDataRecv);

  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, broadcastAddress, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;

  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("{\"error\": \"Failed to add peer\"}");
  }
}

// 📌 ESP-NOW Send Callback
void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  // Serial.printf("{\"status\": \"%s\"}\n", status == ESP_NOW_SEND_SUCCESS ? "Success" : "Fail");
}

// 📌 ESP-NOW Receive Callback
void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *data, int len) {
  memcpy(&incomingData, data, sizeof(incomingData));

  StaticJsonDocument<150> receivedDoc;
  deserializeJson(receivedDoc, incomingData.msg);

  if (receivedDoc["type"] == "ChatRequest") {
    serializeJson(receivedDoc, Serial);
    Serial.println();
    return;
  }

  if (receivedDoc["type"] == "ChatResponse") {
    serializeJson(receivedDoc, Serial);
    Serial.println();
    return;
  }

  if (receivedDoc["type"] == "ChatMessage") {
    serializeJson(receivedDoc, Serial);
    Serial.println();
    return;
  }

  // Fetch GPS data for self
  float self_lat, self_lon, self_speed;
  String rtc_time = getGPSTime();
  getGPSData(self_lat, self_lon, self_speed);

  // Create Final JSON Packet
  StaticJsonDocument<200> finalDoc;
  finalDoc["type"] = "Packet";

  // Received Vehicle Data
  finalDoc["remote_latitude"] = receivedDoc["latitude"];
  finalDoc["remote_longitude"] = receivedDoc["longitude"];
  finalDoc["remote_speed"] = receivedDoc["speed"];
  finalDoc["remote_vehicle"] = receivedDoc["vehicle"];
  finalDoc["remote_status"] = receivedDoc["status"];
  finalDoc["remote_time"] = receivedDoc["rtc_time"];
  finalDoc["remote_mac"] = receivedDoc["mac"];

  // Self GPS Data
  finalDoc["self_latitude"] = self_lat;
  finalDoc["self_longitude"] = self_lon;
  finalDoc["self_speed"] = self_speed;
  finalDoc["self_vehicle"] = VEHICLE_NUMBER;
  finalDoc["self_time"] = rtc_time;

  // Print Final Data
  serializeJson(finalDoc, Serial);
  Serial.println();
}

// 📌 Fetch GPS Data
void getGPSData(float &lat, float &lon, float &speed) {
  unsigned long startMillis = millis();
  while (gpsSerial.available() && millis() - startMillis < 500) {
    gps.encode(gpsSerial.read());
  }

  if (gps.location.isValid()) {
    lat = gps.location.lat();
    lon = gps.location.lng();
    speed = gps.speed.kmph();
  } else {
    lat = lon = speed = -1.1;  // Invalid Data
  }
}

// 📌 Fetch GPS RTC Time
String getGPSTime() {
  if (gps.time.isValid()) {
    return String(gps.time.hour()) + ":" + String(gps.time.minute()) + ":" + String(gps.time.second());
  }
  return "Time Unavailable";
}

void convertMAC(String macStr, uint8_t *mac) {
  sscanf(macStr.c_str(), "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx", &mac[0], &mac[1], &mac[2], &mac[3], &mac[4], &mac[5]);
}

// 📌 Prepare JSON Data for Transmission
void prepareAndSendData() {
  float lat, lon, speed;
  String rtc_time = getGPSTime();
  getGPSData(lat, lon, speed);

  StaticJsonDocument<150> doc;
  if (lat != -1) {
    doc["latitude"] = lat;
    doc["longitude"] = lon;
    doc["speed"] = speed;
    doc["status"] = "OK";
  } else {
    doc["status"] = "GPS Error";
  }

  doc["vehicle"] = VEHICLE_NUMBER;
  doc["rtc_time"] = rtc_time;
  doc["mac"] = WiFi.macAddress();

  char jsonBuffer[150];
  serializeJson(doc, jsonBuffer);

  strncpy(myData.msg, jsonBuffer, sizeof(myData.msg) - 1);
  myData.msg[sizeof(myData.msg) - 1] = '\0';

  esp_err_t result = esp_now_send(broadcastAddress, (uint8_t *)&myData, sizeof(myData));

  if (result != ESP_OK) {
    Serial.println("{\"error\": \"Message Send Failed\"}");
  }
}

void requestChat(const char *macstr) {
  uint8_t mac[6];
  convertMAC(macstr, mac);
  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, mac, 6);
  esp_now_add_peer(&peerInfo);

  StaticJsonDocument<150> doc;
  doc["type"] = "ChatRequest";
  doc["mac"] = WiFi.macAddress();
  doc["vehicle"] = VEHICLE_NUMBER;

  char jsonBuffer[150];
  serializeJson(doc, jsonBuffer);

  strncpy(myData.msg, jsonBuffer, sizeof(myData.msg) - 1);
  myData.msg[sizeof(myData.msg) - 1] = '\0';

  if (!esp_now_is_peer_exist(mac)) {  // Check if peer already exists
    if (esp_now_add_peer(&peerInfo) == ESP_OK) {
      Serial.println("Peer added successfully!");
    } else {
      Serial.println("Failed to add peer.");
    }
  }


  esp_err_t result = esp_now_send(mac, (uint8_t *)&myData, sizeof(myData));
}

void responseChat(const char *macstr, const char *res) {
  uint8_t mac[6];
  convertMAC(macstr, mac);
  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, mac, 6);
  esp_now_add_peer(&peerInfo);

  StaticJsonDocument<150> doc;
  doc["type"] = "ChatResponse";
  doc["mac"] = WiFi.macAddress();
  doc["vehicle"] = VEHICLE_NUMBER;
  doc["response"] = res;

  char jsonBuffer[150];
  serializeJson(doc, jsonBuffer);

  strncpy(myData.msg, jsonBuffer, sizeof(myData.msg) - 1);
  myData.msg[sizeof(myData.msg) - 1] = '\0';

  if (!esp_now_is_peer_exist(mac)) {  // Check if peer already exists
    if (esp_now_add_peer(&peerInfo) == ESP_OK) {
      Serial.println("Peer added successfully!");
    } else {
      Serial.println("Failed to add peer.");
    }
  }

  esp_err_t result = esp_now_send(mac, (uint8_t *)&myData, sizeof(myData));
}

void sendChat(const char *macstr, const char *msg) {

  Serial.println("send message function called.....");

  uint8_t mac[6];
  convertMAC(macstr, mac);
  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, mac, 6);
  esp_now_add_peer(&peerInfo);

  StaticJsonDocument<150> doc;
  doc["type"] = "ChatMessage";
  doc["mac"] = WiFi.macAddress();
  doc["vehicle"] = VEHICLE_NUMBER;
  doc["msg"] = msg;

  char jsonBuffer[150];
  serializeJson(doc, jsonBuffer);

  strncpy(myData.msg, jsonBuffer, sizeof(myData.msg) - 1);
  myData.msg[sizeof(myData.msg) - 1] = '\0';

  esp_err_t result = esp_now_send(mac, (uint8_t *)&myData, sizeof(myData));

  Serial.print("Printing sent result: ");
  Serial.println(result);
}

// 📌 Task for Sending GPS Data
void TaskSendGPS(void *pvParameters) {
  while (1) {
    prepareAndSendData();
    vTaskDelay(pdMS_TO_TICKS(2000));  // 2s delay
  }
}

void TaskSerialReceive(void *pvParameters) {
  while (1) {
    if (Serial.available() > 0) {
      String receivedData = Serial.readStringUntil('\n');  // Read JSON string
      Serial.print("Received from PC: ");
      Serial.println(receivedData);

      // Parse JSON
      StaticJsonDocument<200> doc;  // Adjust size as needed
      DeserializationError error = deserializeJson(doc, receivedData);

      if (error) {
        Serial.print("JSON Parsing failed: ");
        Serial.println(error.c_str());
        return;
      }

      // Extract the "type" key
      const char *type = doc["type"];
      if (type && strcmp(type, "ChatMessage") == 0) {
        // Verify the JSON contains required fields
        if (doc.containsKey("mac") && doc.containsKey("message")) {
          const char *mac = doc["mac"];
          const char *msg = doc["message"];
          // Validate the strings aren't NULL
          if (mac && msg) {
            Serial.println("Sending chat message...");
            Serial.print("Recipient MAC: ");
            Serial.println(mac);
            Serial.print("Message: ");
            Serial.println(msg);

            sendChat(mac,msg);
          } else {
            Serial.println("Error: MAC or message is NULL");
          }
        } else {
          Serial.println("Error: Missing required fields in JSON");
        }
      }
      if (type && strcmp(type, "Request") == 0) {
        const char *mac = doc["mac"];  // Extract MAC address
        if (mac) {
          requestChat(mac);
        } else {
          Serial.println("Key 'mac' not found in JSON!");
        }
      } else if (type && strcmp(type, "ChatResponse") == 0) {
        const char *mac = doc["mac"];
        const char *response = doc["response"];

        // Serial.println("Sending Response message...");
        // Serial.print("Recipient MAC: ");
        // Serial.println(mac);
        // Serial.print("Message: ");
        // Serial.println(response);
        // sendChat(mac, response);
        responseChat(mac, response);

      }  else {
        // Serial.println("Key 'type' not found or does not match 'Request'!");
      }
    }
    vTaskDelay(pdMS_TO_TICKS(100));  // Prevents excessive CPU usage
  }
}


// 📌 Task for Receiving ESP-NOW Data
void TaskReceive(void *pvParameters) {
  while (1) {
    vTaskDelay(pdMS_TO_TICKS(100));  // Small delay for efficiency
  }
}

// 📌 Setup Function
void setup() {
  Serial.begin(115200);
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX, GPS_TX);

  initESPNow();

  xTaskCreatePinnedToCore(TaskSendGPS, "TaskSendGPS", 4096, NULL, 1, NULL, 0);
  xTaskCreatePinnedToCore(TaskReceive, "TaskReceive", 4096, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(TaskSerialReceive, "TaskSerialReceive", 4096, NULL, 1, NULL, 0);  // New Serial Task
}

// 📌 Main Loop (Unused since FreeRTOS handles tasks)
void loop() {}
       