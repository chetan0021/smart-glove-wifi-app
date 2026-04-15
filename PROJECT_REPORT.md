# SmartGlove System Architecture & Working Report

## 1. Executive Summary
The SmartGlove project is an IoT-based assistive technology system designed to capture hand gestures in real-time and broadcast them to a mobile application dashboard. It utilizes a highly robust, dual-layered communication architecture: **ESP-NOW** for ultra-fast, long-range hardware-to-hardware communication, and **Pure WiFi with WebSockets** for seamless hardware-to-mobile integration. 

This architecture was specifically chosen to bypass the hardware limitations and connection bottlenecks often found when running Bluetooth Low Energy (BLE) and WiFi on the same radio antenna.

---

## 2. System Components & Hardware Layer
The hardware consists of two separate ESP32 microcontrollers communicating wirelessly over the 2.4GHz ISM band.

### A. Transmitter ESP32 (The Glove)
- **Role:** Sensor Acquisition & Data Transmission.
- **Components:** An analog flex sensor connected to GPIO 36.
- **Working Mechanism:** 
  - The Transmitter continuously reads analog voltages representing the physical bend of the glove's flex sensor.
  - It classifies the raw Analog-to-Digital (ADC) readings into three distinct states:
    1. **NORMAL** (straight finger)
    2. **WARNING** (half-bent)
    3. **HELP NEEDED** (fully bent)
  - Whenever the state changes, it packages the state into a fixed data struct and instantly broadcasts it to the Receiver ESP32 using the proprietary **ESP-NOW** protocol.

### B. Receiver ESP32 (The Gateway)
- **Role:** IoT Gateway, Actuation, & Mobile Server.
- **Components:** A 16x2 I2C LCD Display and a Relay Module.
- **Processing Stage:** 
  - The Receiver acts as an ESP-NOW peer, blindly listening for packets from the Transmitter.
  - Upon receiving a state change (e.g., `HELP NEEDED`), it triggers local hardware actuations: updating the LCD screen to alert bystanders and switching a physical Relay.
- **Networking Stage (The WiFi Access Point):**
  - Crucially, the Receiver isolates the mobile device from the ESP-NOW layer. It stands up its own discrete WiFi network, broadcasting an SSID called **`SmartGlove_AP`** (SoftAP Mode).
  - It runs a **WebSocket Server** on Port 81.
  - To prevent radio layer interference across the ESP32's single antenna, the ESP-NOW protocol and the `SmartGlove_AP` WiFi hotspot are strictly locked to **WiFi Channel 1**.

---

## 3. The Software & Mobile Application Layer (Flutter)
The mobile application acts as the digital dashboard for end-users, caregivers, or operators. It is built using the Flutter framework natively compiled for smartphones.

### A. Connectivity Protocol (WebSockets)
Instead of relying on fragile native Bluetooth scanning (which requires GPS location permissions and suffers from GATT caching bugs across Android updates), the mobile phone connects directly to the `SmartGlove_AP` WiFi network.
- The Flutter application utilizes the lightweight, full-duplex `web_socket_channel` library to establish a permanent TCP socket connection to the Receiver ESP32's static IP (`ws://192.168.4.1:81`).

### B. Data Parsing & State Management
- Data is transmitted over the WebSocket as simple, pipe-delimited UTF-8 strings (e.g., `"HELP NEEDED|ON"`).
- A unified State Notifier (`GloveNotifier`) inside the Flutter application instantly parses this raw string into structured Dart Enum objects (`GloveData`).
- The entire mobile UI reacts synchronously: updating visual cards (Green/Orange/Red metrics), calculating timestamp metrics, and updating the connection status indicator at the top right of the dashboard.

### C. Voice Alerts (TTS Integration)
- For accessibility, the mobile application incorporates an invisible `TtsService` (Text-to-Speech).
- Depending on the structured `GloveData` received via WebSocket, the phone will autonomously speak alerts out loud (e.g., dynamically adjusting volume and stating *"Help needed"* or *"System Normal"*).

---

## 4. Conclusion & Advantages of this Architecture
By migrating from Bluetooth to a **WiFi Access Point + WebSocket** topology:
1. **Zero Interference:** ESP-NOW and standard WiFi native to the ESP32 share the same fundamental 802.11 physical layer. Locking them both to Channel 1 completely solves dropped packets.
2. **Platform Agnostic:** WebSockets over local WiFi require exactly zero specialized permissions on modern Android and iOS devices, unlike BLE.
3. **Impeccable Latency:** WebSocket connections remain persistently open, allowing the Gateway ESP32 to push critical `"HELP NEEDED"` alerts to the phone in low single-digit milliseconds. 
