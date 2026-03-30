/*
 * TapSakay Hardware Module with GPS and PN532 NFC
 * ESP8266 NodeMCU + NEO-6M GPS + PN532 NFC
 * 
 * ESP8266 Connections:
 * - GPS TX  → D5 (GPIO14)
 * - GPS RX  → D6 (GPIO12)
 * - PN532 SDA → D2 (GPIO4)
 * - PN532 SCL → D1 (GPIO5)
 * - PN532 VCC → 3V3
 * - PN532 GND → GND
 */

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <TinyGPS++.h>
#include <ArduinoJson.h>
#include <SoftwareSerial.h>
#include <ESP8266WiFiMulti.h>
#include <DNSServer.h>
#include <ESP8266WebServer.h>
#include <WiFiManager.h>
#include <ESP8266mDNS.h>
#include <Wire.h>
#include <PN532_I2C.h>
#include <PN532.h>

// WiFiManager for WiFi configuration
WiFiManager wifiManager;

// GPS Configuration - Use GPIO numbers directly
#define GPS_RX 14  // GPIO14 - Connect to GPS TX (D5 on NodeMCU)
#define GPS_TX 12  // GPIO12 - Connect to GPS RX (D6 on NodeMCU)
SoftwareSerial gpsSerial(GPS_RX, GPS_TX);
TinyGPSPlus gps;

// PN532 NFC Configuration
PN532_I2C pn532(Wire);
PN532 nfc(pn532);

// Web Server
ESP8266WebServer server(80);

// GPS Data Structure
struct GPSData {
  double latitude = 0;
  double longitude = 0;
  double altitude = 0;
  double speed = 0;
  int satellites = 0;
  bool valid = false;
  unsigned long lastUpdate = 0;
  bool isMock = false;
};

GPSData currentGPS;
unsigned long lastMockSend = 0;
const unsigned long MOCK_SEND_INTERVAL = 10000; // Send mock data every 10 seconds if no GPS

// NFC Data
String lastScannedUID = "";
unsigned long lastNFCRead = 0;

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== TapSakay Hardware Module Starting ===");
  
  // Initialize I2C for PN532
  Wire.begin();
  Wire.setClock(100000); // 100kHz I2C clock
  
  // Initialize PN532
  Serial.println("Initializing PN532 NFC...");
  nfc.begin();
  
  uint32_t versiondata = nfc.getFirmwareVersion();
  if (!versiondata) {
    Serial.println("Didn't find PN53x board");
  } else {
    Serial.print("Found chip PN5");
    Serial.println((versiondata>>24) & 0xFF, HEX);
    Serial.print("Firmware ver. ");
    Serial.print((versiondata>>16) & 0xFF, DEC);
    Serial.print('.');
    Serial.println((versiondata>>8) & 0xFF, DEC);
    
    // Configure board to read RFID tags
    nfc.SAMConfig();
    Serial.println("NFC initialized successfully");
  }
  
  // Initialize GPS
  gpsSerial.begin(9600);
  Serial.println("GPS Serial initialized at 9600 baud");
  
  currentGPS.lastUpdate = millis();
  
  // Setup WiFi using WiFiManager
  Serial.println("Starting WiFi Manager...");
  
  // Set custom parameters for WiFiManager
  wifiManager.setAPStaticIPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
  wifiManager.setAPCallback([](WiFiManager *myWiFiManager) {
    Serial.println("Config AP is running");
    Serial.print("AP Name: ");
    Serial.println(myWiFiManager->getConfigPortalSSID());
    Serial.print("AP IP: ");
    Serial.println(WiFi.softAPIP());
  });
  
  // Try to connect to saved WiFi, or start config portal
  if (!wifiManager.autoConnect("TapSakay-Hardware-Setup")) {
    Serial.println("Failed to connect and hit timeout");
    ESP.reset();
    delay(1000);
  }
  
  Serial.println("WiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  
  // Start mDNS service
  if (MDNS.begin("tapsakay")) {
    Serial.println("mDNS responder started");
    Serial.println("You can now connect to: http://tapsakay.local");
  } else {
    Serial.println("Error setting up MDNS responder!");
  }
  
  Serial.print("Use this IP in the Flutter app: ");
  
  // Setup HTTP endpoints
  server.on("/", handleRoot);
  server.on("/status", handleStatus);
  server.on("/gps", handleGPS);
  server.on("/nfc", handleNFC);
  server.on("/nfc/read", handleNFCRead);
  server.begin();
  
  Serial.println("=== System Ready ===");
  Serial.print("Open browser: http://");
  Serial.println(WiFi.localIP());
}

void loop() {
  server.handleClient();
  
  // Read GPS data with debug output
  while (gpsSerial.available() > 0) {
    char c = gpsSerial.read();
    Serial.print(c); // Debug: Print raw GPS data
    if (gps.encode(c)) {
      updateGPSData();
    }
  }
  
  // Send mock GPS data if no valid GPS for 10 seconds
  if (!currentGPS.valid && (millis() - lastMockSend > MOCK_SEND_INTERVAL)) {
    sendMockGPSData();
    lastMockSend = millis();
  }
  
  // Check for NFC cards (poll every 500ms)
  if (millis() - lastNFCRead > 500) {
    checkNFCCard();
    lastNFCRead = millis();
  }
}

void updateGPSData() {
  if (gps.location.isValid()) {
    currentGPS.latitude = gps.location.lat();
    currentGPS.longitude = gps.location.lng();
    currentGPS.altitude = gps.altitude.meters();
    currentGPS.speed = gps.speed.kmph();
    currentGPS.satellites = gps.satellites.value();
    currentGPS.valid = true;
    currentGPS.lastUpdate = millis();
    currentGPS.isMock = false;
    
    Serial.println("=== GPS Update ===");
    Serial.print("Lat: "); Serial.println(currentGPS.latitude, 6);
    Serial.print("Lng: "); Serial.println(currentGPS.longitude, 6);
    Serial.print("Speed: "); Serial.println(currentGPS.speed);
    Serial.print("Sats: "); Serial.println(currentGPS.satellites);
  }
}

void sendMockGPSData() {
  // Generate mock GPS data around Zamboanga City
  currentGPS.latitude = 6.9214 + (random(-100, 100) / 10000.0);
  currentGPS.longitude = 122.0790 + (random(-100, 100) / 10000.0);
  currentGPS.altitude = random(10, 50);
  currentGPS.speed = random(0, 60);
  currentGPS.satellites = random(4, 12);
  currentGPS.valid = true;
  currentGPS.lastUpdate = millis();
  currentGPS.isMock = true;
  
  Serial.println("=== Mock GPS Data ===");
  Serial.print("Lat: "); Serial.println(currentGPS.latitude, 6);
  Serial.print("Lng: "); Serial.println(currentGPS.longitude, 6);
}

void checkNFCCard() {
  uint8_t uid[] = { 0, 0, 0, 0, 0, 0, 0 };
  uint8_t uidLength;
  
  boolean success = nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength);
  
  if (success) {
    String uidString = "";
    for (uint8_t i = 0; i < uidLength; i++) {
      if (uid[i] < 0x10) uidString += "0";
      uidString += String(uid[i], HEX);
    }
    uidString.toUpperCase();
    
    // Only process if it's a different card
    if (uidString != lastScannedUID) {
      lastScannedUID = uidString;
      Serial.print("NFC Card Detected: ");
      Serial.println(uidString);
      
      // Store for API access
      lastNFCRead = millis();
    }
  }
}

// HTTP Handlers
void handleRoot() {
  String html = R"(
<!DOCTYPE html>
<html>
<head>
    <title>TapSakay Hardware Module</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial; margin: 20px; }
        .card { background: #f5f5f5; padding: 20px; margin: 10px 0; border-radius: 10px; }
        .status { color: green; font-weight: bold; }
        .gps { color: blue; }
        .nfc { color: purple; }
        button { padding: 10px 20px; font-size: 16px; cursor: pointer; }
    </style>
</head>
<body>
    <h1>🚌 TapSakay Hardware Module</h1>
    
    <div class="card">
        <h2>📍 GPS Status</h2>
        <div id="gps-status" class="status">Loading...</div>
        <div id="gps-data" class="gps"></div>
        <button onclick="refreshGPS()">Refresh GPS</button>
    </div>
    
    <div class="card">
        <h2>📱 NFC Status</h2>
        <div id="nfc-status" class="status">Ready</div>
        <div id="nfc-data" class="nfc">Tap a card to read UID</div>
        <button onclick="refreshNFC()">Check NFC</button>
    </div>
    
    <script>
        function refreshGPS() {
            fetch('/gps')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('gps-status').textContent = data.valid ? '✅ GPS Connected' : '❌ No Signal';
                    document.getElementById('gps-data').innerHTML = 
                        '<strong>Lat:</strong> ' + data.latitude + '<br>' +
                        '<strong>Lng:</strong> ' + data.longitude + '<br>' +
                        '<strong>Speed:</strong> ' + data.speed + ' km/h<br>' +
                        '<strong>Satellites:</strong> ' + data.satellites + '<br>' +
                        '<strong>Mock Data:</strong> ' + (data.mock ? 'Yes' : 'No');
                });
        }
        
        function refreshNFC() {
            fetch('/nfc')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('nfc-status').textContent = data.ready ? '✅ NFC Ready' : '❌ NFC Error';
                    document.getElementById('nfc-data').innerHTML = 
                        '<strong>Last Card:</strong> ' + (data.uid || 'None') + '<br>' +
                        '<strong>Status:</strong> ' + data.status;
                });
        }
        
        // Auto-refresh every 2 seconds
        setInterval(() => {
            refreshGPS();
            refreshNFC();
        }, 2000);
        
        // Initial load
        refreshGPS();
        refreshNFC();
    </script>
</body>
</html>
)";
  
  server.send(200, "text/html", html);
}

void handleStatus() {
  StaticJsonDocument<200> doc;
  
  doc["gps_connected"] = currentGPS.valid;
  doc["nfc_ready"] = nfc.getFirmwareVersion() != 0;
  doc["uptime"] = millis();
  doc["wifi_connected"] = WiFi.status() == WL_CONNECTED;
  doc["ip"] = WiFi.localIP().toString();
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

void handleGPS() {
  StaticJsonDocument<300> doc;
  
  doc["latitude"] = currentGPS.latitude;
  doc["longitude"] = currentGPS.longitude;
  doc["altitude"] = currentGPS.altitude;
  doc["speed"] = currentGPS.speed;
  doc["satellites"] = currentGPS.satellites;
  doc["valid"] = currentGPS.valid;
  doc["last_update"] = currentGPS.lastUpdate;
  doc["mock"] = currentGPS.isMock;
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

void handleNFC() {
  StaticJsonDocument<200> doc;
  
  doc["ready"] = nfc.getFirmwareVersion() != 0;
  doc["uid"] = lastScannedUID;
  doc["status"] = lastScannedUID.isEmpty() ? "No card" : "Card detected";
  doc["last_read"] = lastNFCRead;
  
  // Clear UID after reading (so it can be read again)
  if (millis() - lastNFCRead > 2000) {
    lastScannedUID = "";
  }
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

void handleNFCRead() {
  checkNFCCard();
  
  StaticJsonDocument<200> doc;
  doc["uid"] = lastScannedUID;
  doc["detected"] = !lastScannedUID.isEmpty();
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}
