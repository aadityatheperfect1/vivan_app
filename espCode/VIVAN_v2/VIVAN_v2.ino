#include <esp_now.h>
#include <WiFi.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>
#include <ArduinoJson.h>  // Include ArduinoJson for JSON handling

// Define GPS module pins
#define GPS_RX 16
#define GPS_TX 17

TinyGPSPlus gps;
HardwareSerial gpsSerial(2);

// Data structure for ESP-NOW communication
typedef struct struct_message {
    char msg[120];  // Increased size for JSON message
} struct_message;

// Message objects
struct_message myData;
struct_message incomingData;

// Broadcast address (FF:FF:FF:FF:FF:FF sends to all ESP-NOW devices)
uint8_t broadcastAddress[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

// ESP-NOW Send Callback
void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
    // Serial.printf("{\"status\": \"%s\"}\n", status == ESP_NOW_SEND_SUCCESS ? "Success" : "Fail");
}

// ESP-NOW Receive Callback
void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *data, int len) {
    memcpy(&incomingData, data, sizeof(incomingData));
    
    Serial.println(incomingData.msg);
}

// Task for Transmitting GPS Data
void TaskSendGPS(void *pvParameters) {
    while (1) {
        unsigned long startMillis = millis();
        
        // Read GPS data for up to 500ms
        while (gpsSerial.available() && (millis() - startMillis < 500)) {
            char c = gpsSerial.read();
            gps.encode(c);
        }

        char jsonBuffer[120];  // Buffer for JSON string
        const char vehicleNo[] = "AB123"; // Vehicle number

        // Create JSON object
        StaticJsonDocument<120> doc;
        doc["type"] = "Packet";

        if (gps.location.isValid()) {
            // If GPS has a valid fix, send coordinates
            doc["latitude"] = gps.location.lat();
            doc["longitude"] = gps.location.lng();
            doc["speed"] = gps.speed.kmph();  // Add speed in km/h
            doc["vehicle"] = vehicleNo;
            doc["status"] = "OK"; // GPS working fine
        } else if (gps.satellites.value() == 0) {
            // No satellites detected
            doc["status"] = "No satellites detected";
            doc["vehicle"] = vehicleNo;
        } else {
            // GPS not calibrated
            doc["status"] = "GPS not calibrated";
            doc["vehicle"] = vehicleNo;
        }

        // Serialize JSON
        serializeJson(doc, jsonBuffer);

        // Copy JSON to message structure
        strncpy(myData.msg, jsonBuffer, sizeof(myData.msg) - 1);
        myData.msg[sizeof(myData.msg) - 1] = '\0';  // Ensure null termination

        // Send message via ESP-NOW
        esp_err_t result = esp_now_send(broadcastAddress, (uint8_t *)&myData, sizeof(myData));

        if (result != ESP_OK) {
            Serial.println("{\"error\": \"Error sending message\"}");
        }

        vTaskDelay(pdMS_TO_TICKS(2000));  // Delay 2 seconds
    }
}

// Task for Receiving ESP-NOW Messages
void TaskReceive(void *pvParameters) {
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(100));  // Small delay to allow other tasks to run
    }
}

void setup() {
    Serial.begin(115200);

    // Set ESP32 in Wi-Fi Station mode
    WiFi.mode(WIFI_STA);
    WiFi.disconnect();

    // Initialize ESP-NOW
    if (esp_now_init() != ESP_OK) {
        Serial.println("{\"error\": \"ESP-NOW initialization failed!\"}");
        return;
    }

    // Register ESP-NOW Callbacks
    esp_now_register_send_cb(OnDataSent);
    esp_now_register_recv_cb(OnDataRecv);

    // Add broadcast peer
    esp_now_peer_info_t peerInfo = {};
    memcpy(peerInfo.peer_addr, broadcastAddress, 6);
    peerInfo.channel = 0;
    peerInfo.encrypt = false;

    if (esp_now_add_peer(&peerInfo) != ESP_OK) {
        Serial.println("{\"error\": \"Failed to add peer\"}");
        return;
    }

    // Initialize GPS module
    gpsSerial.begin(9600, SERIAL_8N1, GPS_RX, GPS_TX);

    // Create FreeRTOS tasks
    xTaskCreatePinnedToCore(TaskSendGPS, "TaskSendGPS", 4096, NULL, 1, NULL, 0); // Run on Core 0
    xTaskCreatePinnedToCore(TaskReceive, "TaskReceive", 4096, NULL, 1, NULL, 1); // Run on Core 1
}

void loop() {
    // FreeRTOS handles tasks, so no need to do anything here.
}
