/*
 * ============================================================
 *  SmartGlove — TRANSMITTER (Flex Sensor ESP32)
 *  Reads flex sensor, classifies gesture into 3 states,
 *  and sends via ESP-NOW to the Receiver ESP32.
 *
 *  State mapping (aligned with Receiver + Flutter app):
 *    0 → NORMAL      (finger straight)
 *    1 → WARNING     (mid-bend)
 *    2 → HELP NEEDED (fully bent)
 *
 *  WIRING:
 *    Flex sensor  → GPIO 36 (VP)
 *    GND          → GND
 *  ============================================================
 */

#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>

#define FLEX_PIN 36

// ── Target receiver MAC address ──────────────────────────────
// ⚠️  This is the Receiver ESP32's WIFI MAC (for ESP-NOW).
//     NOT the BLE MAC (which the Flutter phone sees for scanning).
//     The Receiver prints its WiFi MAC on Serial at startup:
//       "[WiFi] MAC Address: XX:XX:XX:XX:XX:XX"
//     Paste that value here.
uint8_t receiverMAC[] = {0xD4, 0xE9, 0xF4, 0xC4, 0x22, 0x90};  // WiFi/ESP-NOW MAC

typedef struct {
  int state;       // 0=NORMAL, 1=WARNING, 2=HELP NEEDED
  int relayState;  // 0=OFF, 1=ON (mirrors what receiver will set)
} Message;

Message data;
int lastSentState = -1;

// ── ESP-NOW send callback ─────────────────────────────────────
// NOTE: ESP32 Arduino core v3.x (IDF v5.x) changed the send callback
// signature — first arg is now wifi_tx_info_t* instead of uint8_t*.
void onSent(const wifi_tx_info_t *txInfo, esp_now_send_status_t status) {
  Serial.print("[ESP-NOW] Send status: ");
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "SUCCESS ✓" : "FAILED ✗");
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("==============================================");
  Serial.println("  SmartGlove TRANSMITTER — Starting up");
  Serial.println("==============================================");

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();  // Required for stable MAC read
  delay(100);
  
  // ── FORCE WIFI CHANNEL 1 ────────────────────────────────────
  // ESP-NOW and BLE conflict if the radio changes channels.
  // We force both transmitter and receiver to Channel 1.
  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);

  Serial.print("[WiFi] Transmitter MAC Address: ");
  Serial.println(WiFi.macAddress());

  analogSetAttenuation(ADC_11db);
  Serial.println("[ADC] Attenuation set to 11dB (0–3.3V range)");

  // Init ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("[ESP-NOW] ERROR: init failed! Halting.");
    while (true) delay(1000);
  }
  Serial.println("[ESP-NOW] Initialized OK");

  esp_now_register_send_cb(onSent);

  // Register peer (Receiver)
  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, receiverMAC, 6);
  peerInfo.channel = 1;  // Match forced channel
  peerInfo.encrypt = false;

  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("[ESP-NOW] ERROR: Failed to add peer! Check receiver MAC.");
    while (true) delay(1000);
  }

  Serial.print("[ESP-NOW] Peer registered → MAC: ");
  for (int i = 0; i < 6; i++) {
    if (i > 0) Serial.print(":");
    Serial.printf("%02X", receiverMAC[i]);
  }
  Serial.println();
  Serial.println("----------------------------------------------");
  Serial.println("  Setup complete. Reading flex sensor...");
  Serial.println("==============================================");
}

void loop() {
  int val = analogRead(FLEX_PIN);

  // ── 3-state classification ──────────────────────────────────
  //  Tune these thresholds for your flex sensor's actual range.
  if (val > 2900) {
    data.state = 2;       // HELP NEEDED — fully bent
    data.relayState = 1;  // Relay ON
  } else if (val < 2500) {
    data.state = 0;       // NORMAL — straight
    data.relayState = 0;
  } else {
    data.state = 1;       // WARNING — mid-bend
    data.relayState = 0;
  }

  // ── Debug: print raw ADC value every loop ──────────────────
  Serial.printf("[FLEX] ADC=%4d  →  State=%d", val, data.state);

  // ── Send only when state changes ────────────────────────────
  if (data.state != lastSentState) {
    String label;
    if (data.state == 2)      label = "HELP NEEDED";
    else if (data.state == 1) label = "WARNING";
    else                      label = "NORMAL";

    Serial.printf("  [STATE CHANGED] Sending: %s\n", label.c_str());
    esp_now_send(receiverMAC, (uint8_t *)&data, sizeof(data));
    lastSentState = data.state;
  } else {
    Serial.println("  (no change)");
  }

  delay(200);
}