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
#include <Adafruit_PN532.h>

// WiFiManager for WiFi configuration
WiFiManager wifiManager;

// Double reset detector
int drd_trigger = 0;

// GPS Configuration - Use GPIO numbers directly
#define GPS_RX 14  // GPIO14 - Connect to GPS TX (D5 on NodeMCU)
#define GPS_TX 12  // GPIO12 - Connect to GPS RX (D6 on NodeMCU)
SoftwareSerial gpsSerial(GPS_RX, GPS_TX);
TinyGPSPlus gps;

// PN532 NFC Configuration for Adafruit Library (I2C only, no IRQ/RESET)
Adafruit_PN532 nfc(-1, -1);

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
};

GPSData currentGPS;

// NFC Data
String lastScannedUID = "";
unsigned long lastNFCRead = 0;

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== TapSakay Hardware Module Starting ===");
  
  // Double reset detection
  drd_trigger = digitalRead(0);
  delay(10);
  
  if (drd_trigger == HIGH) {
    Serial.println("First reset detected - waiting for second...");
    delay(5000);
    if (digitalRead(0) == HIGH) {
      Serial.println("Double reset detected - Starting config portal!");
      wifiManager.resetSettings();
    }
  }
  
  // Initialize I2C for PN532
  // ESP8266: D2=GPIO4 (SDA), D1=GPIO5 (SCL)
  // ESP32: Use GPIO21 (SDA), GPIO22 (SCL)
  #if defined(ESP8266)
    Wire.begin(4, 5); // GPIO4=SDA, GPIO5=SCL (D2, D1 on NodeMCU)
  #elif defined(ESP32)
    Wire.begin(21, 22); // Default ESP32 I2C pins
  #endif
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
  yield(); // Allow WiFi stack to process
  
  // Blink LED to show ESP8266 is running
  static unsigned long lastBlink = 0;
  if (millis() - lastBlink > 2000) {
    digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
    lastBlink = millis();
    Serial.println("ESP8266 is running - Web server active");
  }
  
  // Read GPS data - limit to 100 chars per loop to prevent blocking
  int gpsCharsRead = 0;
  while (gpsSerial.available() > 0 && gpsCharsRead < 100) {
    char c = gpsSerial.read();
    // Serial.print(c); // Remove debug output to prevent blocking
    if (gps.encode(c)) {
      updateGPSData();
    }
    gpsCharsRead++;
    yield(); // Allow WiFi stack to process
  }
  
  // Check for NFC cards
  if (millis() - lastNFCRead > 2000) {
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
    
    Serial.println("=== GPS Update ===");
    Serial.print("Lat: "); Serial.println(currentGPS.latitude, 6);
    Serial.print("Lng: "); Serial.println(currentGPS.longitude, 6);
    Serial.print("Speed: "); Serial.println(currentGPS.speed);
    Serial.print("Sats: "); Serial.println(currentGPS.satellites);
  }
}

void checkNFCCard() {
  uint8_t uid[] = { 0, 0, 0, 0, 0, 0, 0 };
  uint8_t uidLength;
  
  // Add timeout to prevent blocking (100ms max)
  boolean success = nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength, 100);
  
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
  Serial.println("Web request: /");
  String html = "<!DOCTYPE html><html><head><title>TapSakay Hardware</title><meta name='viewport' content='width=device-width, initial-scale=1'></head><body>";
  html += "<h1>🚌 TapSakay Hardware Module</h1>";
  html += "<div style='background:#f5f5f5;padding:20px;margin:10px;border-radius:10px'>";
  html += "<h2>📍 GPS Status</h2>";
  html += "<p>GPS: " + String(currentGPS.valid ? "Connected" : "No Signal") + "</p>";
  html += "<p>Lat: " + String(currentGPS.latitude, 6) + "</p>";
  html += "<p>Lng: " + String(currentGPS.longitude, 6) + "</p>";
  html += "<p>Speed: " + String(currentGPS.speed) + " km/h</p>";
  html += "</div>";
  html += "<div style='background:#f5f5f5;padding:20px;margin:10px;border-radius:10px'>";
  html += "<h2>📱 NFC Status</h2>";
  html += "<p>NFC: " + String(nfc.getFirmwareVersion() != 0 ? "Ready" : "Error") + "</p>";
  html += "<p>Last Card: " + (lastScannedUID.isEmpty() ? "None" : lastScannedUID) + "</p>";
  html += "</div>";
  html += "<p><a href='/gps'>GPS JSON</a> | <a href='/nfc'>NFC JSON</a></p>";
  html += "</body></html>";
  
  server.send(200, "text/html", html);
  Serial.println("Response sent");
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
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

void handleNFC() {
  StaticJsonDocument<200> doc;
  
  // Check if NFC is initialized
  uint32_t versiondata = nfc.getFirmwareVersion();
  doc["ready"] = versiondata != 0;
  doc["uid"] = lastScannedUID;
  doc["status"] = versiondata != 0 ? "NFC ready" : "NFC not found";
  doc["last_read"] = lastNFCRead;
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

void handleNFCRead() {
  StaticJsonDocument<200> doc;
  
  // Check if we have a recent card read (within last 3 seconds)
  bool recentRead = (millis() - lastNFCRead < 3000) && lastScannedUID.length() > 0;
  
  doc["uid"] = recentRead ? lastScannedUID : "";
  doc["detected"] = recentRead;
  doc["message"] = recentRead ? "Card detected" : "No card detected";
  doc["timestamp"] = lastNFCRead;
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
  
  // Clear the UID after successful read to prevent re-use
  if (recentRead) {
    lastScannedUID = "";
    Serial.println("NFC UID cleared after read");
  }
}
