# SmartGlove (WiFi + ESP-NOW + Flutter)

The SmartGlove project has been entirely migrated from Bluetooth Low Energy (BLE) to a highly stable **WiFi (SoftAP + WebSockets) & ESP-NOW** architecture to resolve hardware-level 2.4GHz interference.

## Architecture

1. **Transmitter ESP32 (Glove):** Reads an analog flex sensor and broadcasts gestures via `ESP-NOW`.
2. **Receiver ESP32 (Gateway):** Catches ESP-NOW packets and simultaneously hosts a WiFi Access Point (`SmartGlove_AP`). It broadcasts updates via a WebSockets server on port 81.
3. **Flutter App:** An Android/iOS mobile application that connects to the `SmartGlove_AP` WiFi network and subscribes to the WebSocket to provide an instantaneous, zero-latency dashboard.

---

## 🛠️ Hardware Requirements & Setup

### Components
- **2x ESP32 Development Boards**
- **1x Flex Sensor** (analog input pin 36)
- **1x 16x2 I2C LCD Display** (SDA: 21, SCL: 22)
- **1x Relay Module** (connected to pin 23)

### Arduino Library Dependencies
Before compiling the code in Arduino IDE, ensure these libraries are installed via the Library Manager:
- `LiquidCrystal I2C` (by Frank de Brabander)
- `WebSockets` (by Markus Sattler)

### Flashing the Code
1. Compile and flash `EspnowRecieverTest.ino` to your **Receiver ESP32**.
2. Open the Serial Monitor for the Receiver to confirm its WiFi MAC Address (printed out at startup).
3. Copy that MAC Address into `EspnowTransmitterTest.ino` inside the `receiverMAC[]` array.
4. Compile and flash `EspnowTransmitterTest.ino` to the **Transmitter ESP32 (connected to the glove)**.

---

## 📱 Mobile App (Flutter)

### Setup & Requirements
The application utilizes Flutter. Ensure that you have the Flutter SDK installed.

1. Navigate to the `smart_glove_app` directory:
   ```bash
   cd smart_glove_app
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

### Connecting the App
Since this does not use Bluetooth, connecting is extremely straightforward with zero permission issues:
1. Open your phone's **WiFi Settings**.
2. Connect to the open network named **`SmartGlove_AP`**.
3. Open the SmartGlove Flutter application.
4. The dashboard will automatically connect via WebSockets and start streaming data instantly.
