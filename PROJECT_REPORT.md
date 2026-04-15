# SmartGlove System Architecture & Working Report

## 1. Executive Summary
The SmartGlove project is an IoT-based assistive technology system designed to capture hand gestures in real-time and broadcast them to a mobile application dashboard. It utilizes a highly robust, dual-layered communication architecture: **ESP-NOW** for ultra-fast, long-range hardware-to-hardware communication, and **Pure WiFi with WebSockets** for seamless hardware-to-mobile integration. 

This architecture was specifically chosen to bypass the hardware limitations and connection bottlenecks often found when running Bluetooth Low Energy (BLE) and WiFi on the same radio antenna.

---

## 2. Hardware Layer & Data Transmission
The hardware consists of two separate ESP32 microcontrollers communicating wirelessly over the 2.4GHz ISM band.

### A. Transmitter ESP32 (The Glove)
- **Role:** Sensor Acquisition & Data Transmission.
- **Hardware Config:** An analog flex sensor connected to GPIO 36.
- **Data Flow & Processing:** 
  - The Transmitter continuously reads raw analog voltages representing the physical bend of the glove's flex sensor.
  - **Raw Data Measured:** `val` (0 to 4095 representing ADC voltage on a 11dB attenuation scale).
  - It classifies the raw ADC reading into distinct numerical states mapping to real-world urgency levels:
    - `val > 2900` → State 2 (Fully bent)
    - `val < 2500` → State 0 (Straight)
    - `between`    → State 1 (Mid-bend)
- **Data Transmitted (ESP-NOW Payload):**
  A strict C-struct named `Message` is sent wirelessly over ESP-NOW containing exactly two integers:
  ```c
  typedef struct {
    int state;       // 0=NORMAL, 1=WARNING, 2=HELP NEEDED
    int relayState;  // 0=OFF, 1=ON (Command for the receiver's relay)
  } Message;
  ```

### B. Receiver ESP32 (The Gateway)
- **Role:** IoT Gateway, Physical Actuation, & Mobile Web Server.
- **Hardware Config:** A 16x2 I2C LCD Display (SDA: 21, SCL: 22) and an active-low Relay Module (GPIO 23).
- **Processing Stage:** 
  - Acts as an ESP-NOW peer, actively listening for the `Message` struct.
  - Upon receiving the struct, it triggers local physical data actuations: 
    - **Display Data:** It prints the string equivalent (e.g., `"HELP NEEDED"`) and the relay command (`"Relay: ON"`) to the physical 16x2 LCD screen to alert immediate bystanders.
    - **Relay Data:** It toggles the GPIO pin HIGH or LOW depending on `incomingData.relayState`.
- **Data Transmitted (WebSocket Payload):**
  - The Receiver translates the integer-based C-struct into a human and machine-readable `UTF-8` String payload format.
  - **Payload Format Supported:** A pipe-delimited string representing `"STATUS|RELAY"`.
  - **Exact Data Variations Broadcasted via WebSocket:**
    - `"NORMAL|OFF"`
    - `"WARNING|OFF"`
    - `"HELP NEEDED|ON"`

---

## 3. The Software Layer (Flutter Mobile App)
The mobile application acts as the digital dashboard for end-users, caregivers, or operators. It connects instantly to the Receiver's dedicated WiFi hotspot (`SmartGlove_AP`).

### A. Connectivity Protocol
- The Flutter application establishes a permanent, full-duplex TCP socket connection to the Receiver ESP32's static IP via WebSockets (`ws://192.168.4.1:81`).

### B. Mobile Data Parsing & Structural Typing
When the mobile app receives the plain text payload (e.g., `"HELP NEEDED|ON"`), it is intercepted by `WsManager` and fed into a custom parser (`GloveData.fromRaw()`). 

- **Data Types Generated:** The parser converts the raw strings into strongly-typed Dart Enums to prevent UI errors.
  1. `GloveStatus`: Contains mappings for `helpNeeded`, `warning`, `normal`, and `unknown`.
  2. `RelayStatus`: Contains mappings for `on`, `off`, and `unknown`.
  3. `DateTime`: Automatically tags the incoming data with the exact millisecond timestamp it arrived.

### C. Data Representation in the UI
The received data controls all aspects of the `dashboard_screen.dart` user interface:
- **Connection Data:** A top-right indicator shows instantaneous `Connected` (Green), `Connecting` (Orange), or `Disconnected` (Grey) states based on WebSocket pinging.
- **Metric Data:** Massive color-coded cards dynamically shift logic based on `GloveStatus`:
  - **Green Card:** System Normal
  - **Yellow Card:** Warning Alert
  - **Red Card:** Help Needed Alert
- **Timestamp Data:** Calculates and lists exactly how long ago the last data packet successfully arrived (e.g., "Just now" vs "5m ago").

### D. Voice Alert Data (TTS Integration)
- The structured `GloveStatus` data object is passed into the `TtsService`.
- Depending on the severity of the data, the phone acts autonomously:
  - **Help Needed:** Sets phone volume to 100% (1.0) and audibly states *"Help needed"*.
  - **Warning:** Sets volume to 80% (0.8) and states *"Warning alert"*.
  - **Normal:** Sets volume to 50% (0.5) and states *"Normal"*.

---

## 4. Conclusion & Advantages of this Open Architecture
By utilizing this structured data-pipe from **Analog Voltage** → **Integer C-Struct** → **Pipe-Delimited String** → **Typed Dart Objects**:
1. **Zero Interference:** ESP-NOW and standard WiFi native to the ESP32 share the same fundamental 802.11 physical layer, locking both to Channel 1 completely solves dropped packets.
2. **Platform & Data Agnostic:** WebSockets passing simple delimited UTF-8 text guarantees any operating system (Android, iOS, Windows, macOS) can flawlessly ingest the data.
3. **Impeccable Reliability:** The exact state of the flex-sensor reaches the mobile device's UI text-to-speech engine in single-digit milliseconds.
