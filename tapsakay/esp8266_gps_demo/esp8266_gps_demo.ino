/*
 * TapSakay Hardware Module - ESP8266 + NEO-6M GPS
 * 
 * Features:
 * - WiFi Access Point for direct connection
 * - Real-time GPS data streaming via WebSocket
 * - HTTP API endpoints for status and GPS data
 * - Mock GPS data when no signal available
 * 
 * Wiring:
 * GPS VCC → 3V3
 * GPS GND → GND
 * GPS TX  → D5 (GPIO14)
 * GPS RX  → D6 (GPIO12)
 */

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <WebSocketsServer.h>
#include <TinyGPS++.h>
#include <ArduinoJson.h>
#include <SoftwareSerial.h>

// WiFi Configuration
const char* ssid = "TapSakay-Hardware";
const char* password = "tapsakay123";

// GPS Configuration
#define GPS_RX D5  // GPIO14 - Connect to GPS TX
#define GPS_TX D6  // GPIO12 - Connect to GPS RX
SoftwareSerial gpsSerial(GPS_RX, GPS_TX);
TinyGPSPlus gps;

// Web Server & WebSocket
ESP8266WebServer server(80);
WebSocketsServer webSocket = WebSocketsServer(81);

// GPS data structure
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

// Timing variables
unsigned long lastGPSSend = 0;
const unsigned long GPS_SEND_INTERVAL = 2000; // Send every 2 seconds
unsigned long lastMockSend = 0;
const unsigned long MOCK_SEND_INTERVAL = 10000; // Send mock data every 10 seconds if no GPS

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== TapSakay Hardware Module Starting ===");
  
  // Initialize GPS
  gpsSerial.begin(9600);
  Serial.println("GPS Serial initialized at 9600 baud");
  
  // Initialize GPS data
  currentGPS.lastUpdate = millis();
  
  // Setup WiFi Access Point
  WiFi.softAP(ssid, password);
  IPAddress myIP = WiFi.softAPIP();
  Serial.print("Access Point started. IP: ");
  Serial.println(myIP);
  Serial.print("SSID: ");
  Serial.println(ssid);
  Serial.print("Password: ");
  Serial.println(password);
  
  // Setup WebSocket server
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);
  Serial.println("WebSocket server started on port 81");
  
  // Setup HTTP endpoints
  server.on("/", handleRoot);
  server.on("/status", handleStatus);
  server.on("/gps", handleGPS);
  server.on("/api/gps", handleAPIGPS);
  server.onNotFound(handleNotFound);
  server.begin();
  Serial.println("HTTP server started on port 80");
  
  Serial.println("=== System Ready ===");
}

void loop() {
  // Handle web server clients
  server.handleClient();
  webSocket.loop();
  
  // Read GPS data
  while (gpsSerial.available() > 0) {
    if (gps.encode(gpsSerial.read())) {
      updateGPSData();
    }
  }
  
  // Send GPS data periodically
  if (millis() - lastGPSSend > GPS_SEND_INTERVAL) {
    if (currentGPS.valid) {
      sendGPSData();
      lastGPSSend = millis();
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
    
    // Print to serial for debugging
    Serial.print("GPS Update: ");
    Serial.print(currentGPS.latitude, 6);
    Serial.print(", ");
    Serial.print(currentGPS.longitude, 6);
    Serial.print(" Sats: ");
    Serial.print(currentGPS.satellites);
    Serial.print(" Speed: ");
    Serial.print(currentGPS.speed, 1);
    Serial.println(" km/h");
  }
}

void sendGPSData() {
  DynamicJsonDocument doc(1024);
  
  doc["type"] = "gps";
  doc["lat"] = currentGPS.latitude;
  doc["lng"] = currentGPS.longitude;
  doc["alt"] = currentGPS.altitude;
  doc["speed"] = currentGPS.speed;
  doc["satellites"] = currentGPS.satellites;
  doc["valid"] = currentGPS.valid;
  doc["timestamp"] = currentGPS.lastUpdate;
  doc["mock"] = currentGPS.isMock;
  
  String jsonStr;
  serializeJson(doc, jsonStr);
  webSocket.broadcastTXT(jsonStr);
  
  Serial.println("GPS data sent via WebSocket");
}

void sendMockGPSData() {
  // Mock location around Manila area with small random variations
  static double baseLat = 14.5995;
  static double baseLng = 120.9842;
  
  currentGPS.latitude = baseLat + (random(-1000, 1000) / 100000.0);
  currentGPS.longitude = baseLng + (random(-1000, 1000) / 100000.0);
  currentGPS.altitude = 10.0 + (random(0, 100) / 10.0);
  currentGPS.speed = random(0, 60);
  currentGPS.satellites = random(4, 12);
  currentGPS.valid = true;
  currentGPS.lastUpdate = millis();
  currentGPS.isMock = true;
  
  sendGPSData();
  Serial.println("Mock GPS data sent");
}

void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.printf("[%u] Disconnected\n", num);
      break;
      
    case WStype_CONNECTED: {
      IPAddress ip = webSocket.remoteIP(num);
      Serial.printf("[%u] Connected from %d.%d.%d.%d\n", num, ip[0], ip[1], ip[2], ip[3]);
      
      // Send current GPS data immediately on connection
      if (currentGPS.valid) {
        sendGPSData();
      }
      break;
    }
      
    case WStype_TEXT:
      Serial.printf("[%u] Text: %s\n", num, payload);
      
      // Handle commands
      DynamicJsonDocument doc(256);
      if (deserializeJson(doc, payload) == DeserializationError::Ok) {
        String command = doc["type"] | "";
        
        if (command == "request_gps") {
          if (currentGPS.valid) {
            sendGPSData();
          } else {
            sendMockGPSData();
          }
        } else if (command == "ping") {
          DynamicJsonDocument pong(64);
          pong["type"] = "pong";
          pong["timestamp"] = millis();
          String response;
          serializeJson(pong, response);
          webSocket.sendTXT(num, response);
        }
      }
      break;
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
    body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
    .connected { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
    .warning { background: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
    .info { background: #d1ecf1; color: #0c5460; border: 1px solid #bee5eb; }
    h1 { color: #333; }
    .data { font-family: monospace; background: #f8f9fa; padding: 10px; border-radius: 5px; margin: 10px 0; }
    button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; margin: 5px; }
    button:hover { background: #0056b3; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🚌 TapSakay Hardware Module</h1>
    
    <div class="status connected">✓ WiFi Access Point Active</div>
    <div class="status info">✓ GPS Module Connected</div>
    
    <h2>System Status</h2>
    <div id="status" class="data">Loading...</div>
    
    <h2>GPS Data</h2>
    <div id="gps" class="data">Waiting for GPS signal...</div>
    
    <h2>Controls</h2>
    <button onclick="requestGPS()">Request GPS</button>
    <button onclick="ping()">Ping Device</button>
    
    <h2>WebSocket Log</h2>
    <div id="log" class="data" style="max-height: 200px; overflow-y: auto;"></div>
  </div>
  
  <script>
    let ws;
    
    function connectWS() {
      ws = new WebSocket('ws://' + location.hostname + ':81');
      
      ws.onopen = () => {
        addLog('Connected to WebSocket');
      };
      
      ws.onmessage = (e) => {
        const data = JSON.parse(e.data);
        
        if (data.type === 'gps') {
          document.getElementById('gps').innerHTML = 
            'Latitude: ' + data.lat.toFixed(6) + '<br>' +
            'Longitude: ' + data.lng.toFixed(6) + '<br>' +
            'Speed: ' + data.speed.toFixed(1) + ' km/h<br>' +
            'Satellites: ' + data.satellites + '<br>' +
            'Status: ' + (data.mock ? 'Mock Data' : 'Real GPS') + '<br>' +
            'Last Update: ' + new Date(data.timestamp).toLocaleTimeString();
        } else if (data.type === 'pong') {
          addLog('Pong received');
        }
      };
      
      ws.onclose = () => {
        addLog('WebSocket disconnected');
        setTimeout(connectWS, 5000);
      };
      
      ws.onerror = (e) => {
        addLog('WebSocket error: ' + e);
      };
    }
    
    function addLog(message) {
      const log = document.getElementById('log');
      const time = new Date().toLocaleTimeString();
      log.innerHTML = '[' + time + '] ' + message + '<br>' + log.innerHTML;
    }
    
    function updateStatus() {
      fetch('/status')
        .then(r => r.json())
        .then(d => {
          document.getElementById('status').innerHTML = 
            'Device: ' + d.device + '<br>' +
            'Uptime: ' + d.uptime + 's<br>' +
            'Free Heap: ' + d.freeHeap + ' bytes<br>' +
            'WiFi Clients: ' + d.wifiClients + '<br>' +
            'GPS Status: ' + (d.gpsValid ? 'Active' : 'Waiting');
        })
        .catch(e => addLog('Status update failed: ' + e));
    }
    
    function requestGPS() {
      ws.send(JSON.stringify({type: 'request_gps'}));
      addLog('GPS requested');
    }
    
    function ping() {
      ws.send(JSON.stringify({type: 'ping'}));
      addLog('Ping sent');
    }
    
    // Initialize
    connectWS();
    updateStatus();
    setInterval(updateStatus, 5000);
  </script>
</body>
</html>
  )";
  
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

void handleAPIGPS() {
  // Same as handleGPS but with /api prefix for consistency
  handleGPS();
}

void handleNotFound() {
  String message = "File Not Found\n\n";
  message += "URI: " + server.uri() + "\n";
  message += "Method: " + (server.method() == HTTP_GET) ? "GET" : "POST";
  message += "\nArguments: " + server.args();
  message += "\n";
  
  for (uint8_t i = 0; i < server.args(); i++) {
    message += " " + server.argName(i) + ": " + server.arg(i) + "\n";
  }
  
  server.send(404, "text/plain", message);
}
