# Requirements Document

## Introduction

A Flutter mobile application that connects to an ESP32-based BLE device called "SmartGlove". The app scans for the device, establishes a BLE connection, reads characteristic data, displays status information on a dashboard, and announces alerts via text-to-speech. The app maintains the BLE connection in the background and supports voice toggle and timestamp display.

## Glossary

- **App**: The Flutter mobile application described in this document
- **SmartGlove**: The ESP32 BLE peripheral device with the advertised name "SmartGlove"
- **BLE_Manager**: The component responsible for scanning, connecting, and communicating over Bluetooth Low Energy
- **Scanner_Screen**: The UI screen that discovers and lists nearby BLE devices
- **Dashboard_Screen**: The UI screen displayed after a successful connection showing device status
- **TTS_Engine**: The text-to-speech component powered by flutter_tts
- **Status**: The operational state reported by the SmartGlove device — one of: HELP_NEEDED, WARNING, or NORMAL
- **Characteristic_UUID**: The BLE characteristic identifier `abcd1234-5678-1234-5678-abcdef123456` used to receive status data
- **Relay_Status**: A binary ON/OFF value reported by the SmartGlove device
- **Voice_Toggle**: A user-controlled switch that enables or disables TTS announcements

---

## Requirements

### Requirement 1: BLE Device Scanning

**User Story:** As a user, I want to scan for nearby BLE devices, so that I can find and connect to my SmartGlove device.

#### Acceptance Criteria

1. WHEN the Scanner_Screen is opened, THE BLE_Manager SHALL begin scanning for nearby BLE devices.
2. WHILE scanning is active, THE Scanner_Screen SHALL display only devices whose advertised name matches "SmartGlove".
3. WHILE scanning is active, THE Scanner_Screen SHALL display a visible stop/cancel button that halts scanning when tapped.
4. WHEN the user taps a discovered SmartGlove device, THE BLE_Manager SHALL initiate a connection to that device.
5. WHILE a connection attempt is in progress, THE Scanner_Screen SHALL disable the tapped device's connect button and display a loading indicator in its place.
6. WHILE a connection attempt is in progress, THE Scanner_Screen SHALL prevent the user from tapping any other device in the list.
7. WHEN a connection is successfully established, THE App SHALL display a connection success popup before navigating to the Dashboard_Screen.
8. IF BLE is unavailable or permissions are denied, THEN THE Scanner_Screen SHALL display a descriptive error message and a clearly labeled action button that guides the user to enable Bluetooth or grant permissions.
9. IF a connection attempt fails, THEN THE Scanner_Screen SHALL display an error message and restore the device list to its interactive state so the user can retry.

---

### Requirement 2: Dashboard Display

**User Story:** As a user, I want to see the current status of my SmartGlove device on a dashboard, so that I can monitor its state at a glance.

#### Acceptance Criteria

1. WHEN the Dashboard_Screen is displayed, THE Dashboard_Screen SHALL show the current Status value received from the SmartGlove device.
2. WHEN the Status is "HELP_NEEDED", THE Dashboard_Screen SHALL render the status card with a red background color.
3. WHEN the Status is "WARNING", THE Dashboard_Screen SHALL render the status card with an orange background color.
4. WHEN the Status is "NORMAL", THE Dashboard_Screen SHALL render the status card with a green background color.
5. THE Dashboard_Screen SHALL display the Relay_Status as either "ON" or "OFF".
6. THE Dashboard_Screen SHALL display a signal indicator reflecting the current BLE connection state as either connected or disconnected.
7. THE Dashboard_Screen SHALL display the timestamp of the last received data update in a human-readable format.
8. THE Dashboard_Screen SHALL use rounded cards, large text for the Status value, and a clean modern layout.

---

### Requirement 3: BLE Communication

**User Story:** As a user, I want the app to receive live data from my SmartGlove device over BLE, so that the dashboard always reflects the current device state.

#### Acceptance Criteria

1. WHEN a connection to the SmartGlove device is established, THE BLE_Manager SHALL subscribe to notifications on the characteristic identified by Characteristic_UUID `abcd1234-5678-1234-5678-abcdef123456`.
2. WHEN a notification is received on the Characteristic_UUID, THE BLE_Manager SHALL parse the payload as a UTF-8 string.
3. THE BLE_Manager SHALL expose the parsed string value to the Dashboard_Screen for display and TTS processing.
4. IF the characteristic identified by Characteristic_UUID is not found on the connected device, THEN THE App SHALL display an error message indicating the characteristic is unavailable.

---

### Requirement 4: Text-to-Speech Announcements

**User Story:** As a user, I want the app to speak status alerts aloud, so that I am notified of critical events without looking at the screen.

#### Acceptance Criteria

1. WHEN a Status value of "HELP_NEEDED" is received and the Voice_Toggle is enabled, THE TTS_Engine SHALL speak the phrase "Help needed" at maximum volume.
2. WHEN a Status value of "WARNING" is received and the Voice_Toggle is enabled, THE TTS_Engine SHALL speak the phrase "Warning alert".
3. WHEN a Status value of "NORMAL" is received and the Voice_Toggle is enabled, THE TTS_Engine MAY optionally speak a confirmation phrase.
4. WHILE the Voice_Toggle is disabled, THE TTS_Engine SHALL remain silent regardless of the received Status value.

---

### Requirement 5: Background BLE Connection Maintenance

**User Story:** As a user, I want the app to maintain the BLE connection in the background, so that I continue receiving alerts even when the app is not in the foreground.

#### Acceptance Criteria

1. WHILE the App is running in the background, THE BLE_Manager SHALL maintain the active BLE connection to the SmartGlove device.
2. WHEN the BLE connection to the SmartGlove device is lost, THE BLE_Manager SHALL automatically attempt to reconnect to the device.
3. WHEN a reconnection attempt succeeds, THE BLE_Manager SHALL re-subscribe to the Characteristic_UUID and resume data reception.
4. THE Dashboard_Screen SHALL update the signal indicator to reflect disconnected state during any reconnection attempt.
5. WHEN the user explicitly disconnects from the Dashboard_Screen, THE BLE_Manager SHALL cancel any active reconnection attempts before navigating away.

---

### Requirement 6: Voice Toggle Control

**User Story:** As a user, I want to enable or disable voice announcements, so that I can control when the app speaks aloud.

#### Acceptance Criteria

1. THE Dashboard_Screen SHALL display a toggle switch labeled to indicate voice on/off state.
2. WHEN the user toggles the Voice_Toggle to disabled, THE TTS_Engine SHALL stop any in-progress speech immediately.
3. WHEN the user toggles the Voice_Toggle to enabled, THE TTS_Engine SHALL resume announcing Status values on the next received update.
4. THE App SHALL persist the Voice_Toggle state across app restarts.

---

### Requirement 7: Screen Navigation and UX Guards

**User Story:** As a user, I want every screen transition and button state to be clearly defined, so that I never reach a dead end, encounter a broken button, or get stuck in an unrecoverable state.

#### Acceptance Criteria

**Screen Wiring — Forward Navigation**

1. WHEN the App is launched, THE App SHALL display the Scanner_Screen as the initial screen.
2. WHEN a BLE connection is successfully established on the Scanner_Screen, THE App SHALL navigate to the Dashboard_Screen and pass the connected device reference.
3. THE App SHALL not navigate to the Dashboard_Screen unless a confirmed, active BLE connection exists.

**Screen Wiring — Back Navigation and Disconnect**

4. WHEN the user taps the disconnect button on the Dashboard_Screen, THE BLE_Manager SHALL terminate the active BLE connection and THE App SHALL navigate back to the Scanner_Screen.
5. WHEN the App navigates back to the Scanner_Screen after a disconnect, THE BLE_Manager SHALL automatically restart scanning so the Scanner_Screen is never shown in an idle, non-scanning state.
6. WHEN the hardware back button is pressed on the Dashboard_Screen, THE App SHALL treat the action identically to tapping the disconnect button, terminating the connection and returning to the Scanner_Screen.
7. THE App SHALL not allow the user to navigate back to the Dashboard_Screen after a disconnect without establishing a new BLE connection.

**BLE Unavailable — Guided Recovery**

8. WHEN BLE is disabled on the device, THE Scanner_Screen SHALL display a message explaining that Bluetooth must be enabled and a clearly labeled button that opens the device Bluetooth settings.
9. WHEN BLE permissions are denied, THE Scanner_Screen SHALL display a message explaining the required permission and a clearly labeled button that opens the app permission settings.
10. IF the user returns to the Scanner_Screen after enabling Bluetooth or granting permissions, THEN THE BLE_Manager SHALL automatically restart scanning without requiring a manual action.

**Scanning State Guards**

11. WHILE scanning is active, THE Scanner_Screen SHALL display a visible "Stop Scanning" button.
12. WHILE scanning is not active and no error condition exists, THE Scanner_Screen SHALL display a visible "Start Scanning" button.
13. THE Scanner_Screen SHALL not display both the "Start Scanning" and "Stop Scanning" buttons simultaneously.

**Connection In-Progress Guards**

14. WHILE a connection attempt is in progress, THE Scanner_Screen SHALL disable all device list items to prevent duplicate connection attempts.
15. WHILE a connection attempt is in progress, THE Scanner_Screen SHALL display a loading indicator on the device entry being connected.
16. WHILE a connection attempt is in progress, THE Scanner_Screen SHALL display a cancel button that aborts the connection attempt and restores the device list to its interactive state.

**Dashboard Button Guards**

17. WHILE the BLE connection is active, THE Dashboard_Screen SHALL display the disconnect button in an enabled, tappable state.
18. WHILE a disconnect operation is in progress, THE Dashboard_Screen SHALL disable the disconnect button and display a loading indicator to prevent duplicate disconnect requests.
19. THE Dashboard_Screen SHALL not display any action button that has no valid action available in the current state.

**Error State Recovery**

20. IF a connection attempt fails, THEN THE Scanner_Screen SHALL display an error message with a "Retry" option that re-initiates scanning.
21. IF the characteristic identified by Characteristic_UUID is not found after connecting, THEN THE App SHALL display an error dialog with a "Disconnect" button that returns the user to the Scanner_Screen.
22. IF a fatal BLE error occurs on the Dashboard_Screen that cannot be recovered by reconnection, THEN THE App SHALL display an error dialog with a "Return to Scanner" button that navigates back to the Scanner_Screen.
23. THE App SHALL not display any error state without at least one clearly labeled recovery action button.
