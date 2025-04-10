#include <esp_now.h>
#include <WiFi.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>
#include <ArduinoJson.h>  // JSON library

// Define GPS module pins
#define GPS_RX 16
#define GPS_TX 17

// Global Constant for Vehicle Number
const char VEHICLE_NUMBER[] = "MK999";

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
uint8_t broadcastAddress[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

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
        lat = lon = speed = -1;  // Invalid Data
    }
}

// 📌 Fetch GPS RTC Time
String getGPSTime() {
    if (gps.time.isValid()) {
        return String(gps.time.hour()) + ":" + String(gps.time.minute()) + ":" + String(gps.time.second());
    }
    return "Time Unavailable";
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

    char jsonBuffer[150];
    serializeJson(doc, jsonBuffer);
    
    strncpy(myData.msg, jsonBuffer, sizeof(myData.msg) - 1);
    myData.msg[sizeof(myData.msg) - 1] = '\0';

    esp_err_t result = esp_now_send(broadcastAddress, (uint8_t *)&myData, sizeof(myData));

    if (result != ESP_OK) {
        Serial.println("{\"error\": \"Message Send Failed\"}");
    }
}

// 📌 Task for Sending GPS Data
void TaskSendGPS(void *pvParameters) {
    while (1) {
        prepareAndSendData();
        vTaskDelay(pdMS_TO_TICKS(2000));  // 2s delay
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
}

// 📌 Main Loop (Unused since FreeRTOS handles tasks)
void loop() {}
