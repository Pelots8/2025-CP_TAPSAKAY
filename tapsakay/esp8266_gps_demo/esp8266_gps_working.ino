/*
 * TapSakay Hardware Module - ESP8266 + NEO-6M GPS (Working Version)
 * 
 * Simple version with minimal HTML for quick demo
 * 
 * Wiring:
 * GPS VCC → 3V3
 * GPS GND → GND  
 * GPS TX  → D5 (GPIO14)
 * GPS RX  → D6 (GPIO12)
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

// WiFiManager for WiFi configuration
WiFiManager wifiManager;

// GPS Configuration - Use GPIO numbers directly
#define GPS_RX 14  // GPIO14 - Connect to GPS TX (D5 on NodeMCU)
#define GPS_TX 12  // GPIO12 - Connect to GPS RX (D6 on NodeMCU)
SoftwareSerial gpsSerial(GPS_RX, GPS_TX);
TinyGPSPlus gps;

// Web Server
ESP8266WebServer server(80);

// GPS data
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
const unsigned long MOCK_SEND_INTERVAL = 10000;

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== TapSakay Hardware Module Starting ===");
  
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
  
  // Send mock data if no GPS signal
  if (!currentGPS.valid && (millis() - lastMockSend > MOCK_SEND_INTERVAL)) {
    sendMockGPSData();
    lastMockSend = millis();
  }
  
  // Check for GPS timeout
  if (currentGPS.valid && (millis() - currentGPS.lastUpdate > 30000)) {
    currentGPS.valid = false;
    Serial.println("GPS signal lost - switching to mock data");
  }
}

void updateGPSData() {
  if (gps.location.isUpdated() && gps.location.isValid()) {
    currentGPS.latitude = gps.location.lat();
    currentGPS.longitude = gps.location.lng();
    currentGPS.altitude = gps.altitude.meters();
    currentGPS.speed = gps.speed.kmph();
    currentGPS.satellites = gps.satellites.value();
    currentGPS.valid = true;
    currentGPS.lastUpdate = millis();
    currentGPS.isMock = false;
    
    Serial.print("GPS: ");
    Serial.print(currentGPS.latitude, 6);
    Serial.print(", ");
    Serial.print(currentGPS.longitude, 6);
    Serial.print(" Sats: ");
    Serial.println(currentGPS.satellites);
  }
}

void sendMockGPSData() {
  // Mock location around Manila area
  currentGPS.latitude = 14.5995 + (random(-1000, 1000) / 100000.0);
  currentGPS.longitude = 120.9842 + (random(-1000, 1000) / 100000.0);
  currentGPS.altitude = 10.0 + (random(0, 100) / 10.0);
  currentGPS.speed = random(0, 60);
  currentGPS.satellites = random(4, 12);
  currentGPS.valid = true;
  currentGPS.lastUpdate = millis();
  currentGPS.isMock = true;
  
  Serial.println("Mock GPS generated");
}

// Simple HTML page without JavaScript
void handleRoot() {
  String html = "<!DOCTYPE html><html><head>";
  html += "<title>TapSakay Hardware</title>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<style>";
  html += "body{font-family:Arial;margin:20px;background:#f5f5f5}";
  html += ".container{max-width:600px;margin:0 auto;background:white;padding:20px;border-radius:10px}";
  html += ".status{padding:10px;margin:10px 0;border-radius:5px}";
  html += ".connected{background:#d4edda;color:#155724}";
  html += ".info{background:#d1ecf1;color:#0c5460}";
  html += "h1{color:#333}";
  html += ".data{font-family:monospace;background:#f8f9fa;padding:10px;border-radius:5px;margin:10px 0}";
  html += "</style></head><body>";
  html += "<div class='container'>";
  html += "<h1>🚌 TapSakay Hardware Module</h1>";
  html += "<div class='status connected'>✓ WiFi Active</div>";
  html += "<div class='status info'>✓ GPS Connected</div>";
  
  // Status section
  html += "<h2>System Status</h2>";
  html += "<div class='data'>";
  html += "Device: ESP8266<br>";
  html += "Uptime: " + String(millis() / 1000) + "s<br>";
  html += "Free Heap: " + String(ESP.getFreeHeap()) + " bytes<br>";
  html += "WiFi Clients: " + String(WiFi.softAPgetStationNum()) + "<br>";
  html += "GPS Status: " + String(currentGPS.valid ? (currentGPS.isMock ? "Mock Data" : "Active") : "Waiting");
  html += "</div>";
  
  // GPS section
  html += "<h2>GPS Data</h2>";
  html += "<div class='data'>";
  html += "Latitude: " + String(currentGPS.latitude, 6) + "<br>";
  html += "Longitude: " + String(currentGPS.longitude, 6) + "<br>";
  html += "Speed: " + String(currentGPS.speed, 1) + " km/h<br>";
  html += "Satellites: " + String(currentGPS.satellites) + "<br>";
  html += "Altitude: " + String(currentGPS.altitude, 1) + " m<br>";
  html += "Status: " + String(currentGPS.isMock ? "Mock Data" : "Real GPS") + "<br>";
  html += "Last Update: " + String(currentGPS.lastUpdate / 1000) + "s";
  html += "</div>";
  
  // API endpoints
  html += "<h2>API Endpoints</h2>";
  html += "<div class='data'>";
  html += "<a href='/status'>GET /status</a> - System status<br>";
  html += "<a href='/gps'>GET /gps</a> - GPS data (JSON)";
  html += "</div>";
  
  // Auto-refresh every 5 seconds
  html += "<meta http-equiv='refresh' content='5'>";
  html += "</div></body></html>";
  
  server.send(200, "text/html", html);
}

void handleStatus() {
  DynamicJsonDocument doc(256);
  doc["device"] = "ESP8266";
  doc["type"] = "tapsakay";
  doc["version"] = "1.0.0";
  doc["uptime"] = millis() / 1000;
  doc["freeHeap"] = ESP.getFreeHeap();
  doc["wifiClients"] = WiFi.softAPgetStationNum();
  doc["gpsValid"] = currentGPS.valid;
  doc["gpsMock"] = currentGPS.isMock;
  
  String jsonStr;
  serializeJson(doc, jsonStr);
  server.send(200, "application/json", jsonStr);
}

void handleGPS() {
  DynamicJsonDocument doc(512);
  doc["latitude"] = currentGPS.latitude;
  doc["longitude"] = currentGPS.longitude;
  doc["altitude"] = currentGPS.altitude;
  doc["speed"] = currentGPS.speed;
  doc["satellites"] = currentGPS.satellites;
  doc["valid"] = currentGPS.valid;
  doc["mock"] = currentGPS.isMock;
  doc["lastUpdate"] = currentGPS.lastUpdate;
  
  String jsonStr;
  serializeJson(doc, jsonStr);
  server.send(200, "application/json", jsonStr);
}
