/*
 * ============================================================
 *  SmartGlove — RECEIVER (WiFi AP + WebSockets Gateway ESP32)
 *
 *  Receives gesture state from Transmitter via ESP-NOW,
 *  controls relay + LCD, and broadcasts status via WebSockets
 *  to the Flutter SmartGlove app.
 *
 *  WiFi AP Details:
 *    SSID: SmartGlove_AP
 *    Pass: (None, open network to ensure easy connection)
 *    IP:   192.168.4.1
 *    WebSocket Port: 81
 *
 *  Notify format (aligned with Flutter GloveData.fromRaw):
 *    "NORMAL|OFF"
 *    "WARNING|OFF"
 *    "HELP NEEDED|ON"
 *
 *  WIRING:
 *    LCD SDA → GPIO 21
 *    LCD SCL → GPIO 22
 *    Relay   → GPIO 23 (LOW = relay ON for active-low relay)
 *  ============================================================
 */

#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <WebSocketsServer.h> // Make sure to install "WebSockets" by Markus Sattler in Arduino Library Manager

// ── Pin definitions ──────────────────────────────────────────
#define RELAY_PIN 23

// ── LCD ──────────────────────────────────────────────────────
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ── WebSocket Server ─────────────────────────────────────────
WebSocketsServer webSocket = WebSocketsServer(81);
bool clientConnected = false;

// ── Message struct (must match Transmitter) ──────────────────
typedef struct {
  int state;      // 0=NORMAL, 1=WARNING, 2=HELP NEEDED
  int relayState; // 0=OFF, 1=ON
} Message;

Message incomingData;
int lastState = -1;

// Format: "STATUS|RELAY" — e.g. "NORMAL|OFF"
String currentStatus = "NORMAL|OFF";

// ── WebSocket Event Callback ─────────────────────────────────
void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.printf("[WebSocket] [%u] Disconnected!\n", num);
      clientConnected = false;
      break;
    case WStype_CONNECTED:
      {
        IPAddress ip = webSocket.remoteIP(num);
        Serial.printf("[WebSocket] [%u] Connected from %d.%d.%d.%d\n", num, ip[0], ip[1], ip[2], ip[3]);
        clientConnected = true;
        
        // Push the immediate status when Flutter connects
        webSocket.sendTXT(num, currentStatus);
        Serial.printf("[WebSocket] Sent initial status: %s\n", currentStatus.c_str());
      }
      break;
    case WStype_TEXT:
      // We don't expect messages from flutter, but if we log them:
      Serial.printf("[WebSocket] [%u] Received text: %s\n", num, payload);
      break;
  }
}

// ── ESP-NOW receive callback ─────────────────────────────────
void onReceive(const esp_now_recv_info *info, const uint8_t *data, int len) {
  Serial.println("[ESP-NOW] ← Packet received");

  if (len != sizeof(incomingData)) {
    Serial.printf("[ESP-NOW] ERROR: packet size %d\n", len);
    return;
  }

  memcpy(&incomingData, data, sizeof(incomingData));

  // Only act on state change
  if (incomingData.state == lastState) {
    return;
  }

  lcd.clear();

  if (incomingData.state == 2) {
    // ── HELP NEEDED ──────────────────────────────────────
    digitalWrite(RELAY_PIN, LOW);   // Active-low relay → ON
    currentStatus = "HELP NEEDED|ON";

    lcd.setCursor(0, 0);
    lcd.print("HELP NEEDED");
    lcd.setCursor(0, 1);
    lcd.print("Relay: ON");

    Serial.println("[STATE] → HELP NEEDED  |  Relay: ON");

  } else if (incomingData.state == 1) {
    // ── WARNING ───────────────────────────────────────────
    digitalWrite(RELAY_PIN, HIGH);  // Relay OFF
    currentStatus = "WARNING|OFF";

    lcd.setCursor(0, 0);
    lcd.print("WARNING");
    lcd.setCursor(0, 1);
    lcd.print("Check Gesture");

    Serial.println("[STATE] → WARNING  |  Relay: OFF");

  } else {
    // ── NORMAL ────────────────────────────────────────────
    digitalWrite(RELAY_PIN, HIGH);  // Relay OFF
    currentStatus = "NORMAL|OFF";

    lcd.setCursor(0, 0);
    lcd.print("SYSTEM NORMAL");
    lcd.setCursor(0, 1);
    lcd.print("Relay: OFF");

    Serial.println("[STATE] → NORMAL  |  Relay: OFF");
  }

  lastState = incomingData.state;

  // Broadcast to all connected WebSockets
  webSocket.broadcastTXT(currentStatus);
  Serial.printf("[WebSocket] Broadcasted: %s\n", currentStatus.c_str());
}

// ── Setup ─────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n==============================================");
  Serial.println("  SmartGlove RECEIVER — Starting up");
  Serial.println("==============================================");

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH); 

  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("SmartGlove");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");

  // ── WiFi AP + ESP-NOW Setup ────────────────────────────────
  // Required: start WiFi as Access Point + Station simultaneously
  // AP so the phone can connect, STA so ESP-NOW works smoothly.
  WiFi.mode(WIFI_AP_STA);
  WiFi.disconnect();
  delay(100);

  // Lock to Channel 1
  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);

  // Setup Hotspot
  WiFi.softAP("SmartGlove_AP", "", 1, 0, 4); // SSID, No Password, Channel 1, Unhidden, Max 4 clients
  IPAddress IP = WiFi.softAPIP();
  
  String wifiMac = WiFi.macAddress();
  Serial.print("[WiFi] *** WIFI/ESP-NOW MAC (put this in Transmitter receiverMAC[]): ");
  Serial.println(wifiMac);
  Serial.print("[WiFi] Access Point Ready at IP: ");
  Serial.println(IP);

  if (esp_now_init() != ESP_OK) {
    Serial.println("[ESP-NOW] ERROR: init failed!");
    while (true) delay(1000);
  }
  esp_now_register_recv_cb(onReceive);
  Serial.println("[ESP-NOW] Initialized OK");

  // ── WebSocket Setup ────────────────────────────────────────
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);
  Serial.println("[WebSocket] Server started on port 81");

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("AP: SmartGlove");
  lcd.setCursor(0, 1);
  lcd.print("Waiting for App.");

  Serial.println("==============================================");
  Serial.println("  Setup complete. Waiting for ESP-NOW + App.");
  Serial.println("==============================================\n");
}

void loop() {
  webSocket.loop(); // Must run continuously to process sockets
}