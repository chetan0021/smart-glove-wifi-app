# Implementation Plan: Smart Glove BLE App

## Overview

Incremental Flutter implementation for Android and iOS. Each task builds on the previous, starting from project scaffolding through services, state, UI, and property-based tests. All code is wired together before the final checkpoint.

## Tasks

- [x] 1. Project setup — pubspec, permissions, and folder structure
  - Add dependencies to `pubspec.yaml`: `flutter_blue_plus`, `flutter_tts`, `shared_preferences`, `provider`, `glados` (dev)
  - Create folder skeleton: `lib/services/`, `lib/models/`, `lib/state/`, `lib/screens/`, `lib/widgets/`
  - Add Android BLE permissions to `AndroidManifest.xml`: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`
  - Add iOS BLE usage descriptions to `Info.plist`: `NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription`
  - _Requirements: 1.1, 5.1_

- [ ] 2. Data models
  - [x] 2.1 Implement `GloveStatus`, `RelayStatus` enums and `GloveData` model in `lib/models/glove_data.dart`
    - Implement `GloveData.fromRaw(String raw)`: split on `|`, trim+uppercase, map to enums, never throw — unknown values map to `unknown` variants
    - Implement `GloveData.copyWith({DateTime? timestamp})`
    - _Requirements: 3.2, 3.3_
  - [ ]* 2.2 Write property test for `GloveData.fromRaw` (Property 5)
    - **Property 5: GloveData parse round-trip**
    - Use `glados` to generate random strings (valid formats, missing relay segment, extra whitespace, garbage)
    - Assert `status` and `relayStatus` are non-null and no exception is thrown
    - **Validates: Requirements 3.2, 3.3**
  - [x] 2.3 Implement `ScannerState` and `DashboardState` enums in `lib/models/app_states.dart`
    - `ScannerState { idle, scanning, connecting, error }`
    - `DashboardState { connected, reconnecting, disconnected, error }`
    - _Requirements: 1.1, 5.4_
  - [x] 2.4 Implement `DeviceStatus` UI helper in `lib/models/device_status.dart`
    - `DeviceStatus.fromGloveStatus(GloveStatus)` returns red/orange/green/grey and label — never throws
    - _Requirements: 2.2, 2.3, 2.4_
  - [ ]* 2.5 Write property test for `DeviceStatus.fromGloveStatus` (Property 3)
    - **Property 3: Status-to-color mapping is total and correct**
    - Use `glados` to generate any `GloveStatus` enum value
    - Assert correct color returned and no exception thrown
    - **Validates: Requirements 2.2, 2.3, 2.4**

- [ ] 3. Services
  - [x] 3.1 Implement `PreferencesService` in `lib/services/preferences_service.dart`
    - `getVoiceEnabled()` and `setVoiceEnabled(bool)` backed by `shared_preferences`
    - _Requirements: 6.4_
  - [ ]* 3.2 Write property test for `PreferencesService` round-trip (Property 7)
    - **Property 7: Voice toggle persistence round-trip**
    - Use `glados` to generate any `bool`; write then read back and assert equality
    - **Validates: Requirements 6.4**
  - [x] 3.3 Implement `TtsService` in `lib/services/tts_service.dart`
    - `init()`, `speak(String)`, `stop()`, `setVolume(double)` wrapping `flutter_tts`
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - [ ]* 3.4 Write unit tests for `TtsService`
    - Mock `flutter_tts`; verify `speak` and `stop` are called with correct arguments
    - _Requirements: 4.1, 4.2, 4.4_
  - [x] 3.5 Implement `BleManager` in `lib/services/ble_manager.dart`
    - `startScan()` / `stopScan()` using `flutter_blue_plus`
    - `scanResults` stream filtered to devices named exactly "SmartGlove"
    - `connect(BluetoothDevice)` / `disconnect()`
    - `subscribeToCharacteristic(BluetoothDevice)` subscribing to UUID `abcd1234-5678-1234-5678-abcdef123456`; emits parsed `GloveData` on `gloveDataStream`; surfaces error if characteristic not found
    - `connectionState` stream re-exported from `flutter_blue_plus`
    - `enableAutoReconnect(BluetoothDevice)` / `disableAutoReconnect()` — `_reconnectLoop` with exponential back-off (1 s, 2 s, 4 s, max 30 s)
    - Boolean getters: `isScanning`, `isConnecting`, `isConnected`
    - _Requirements: 1.1, 1.2, 1.4, 3.1, 3.2, 3.4, 5.1, 5.2, 5.3_
  - [ ]* 3.6 Write property test for scan filter (Property 1)
    - **Property 1: Scan results filter to SmartGlove only**
    - Use `glados` to generate random lists of device names; assert filtered output contains only "SmartGlove" entries
    - **Validates: Requirements 1.2**
  - [ ]* 3.7 Write unit tests for `BleManager`
    - Mock `flutter_blue_plus`; verify scan filter, connect/disconnect calls, reconnect loop initiation, characteristic-not-found error path
    - _Requirements: 1.1, 1.2, 3.1, 3.4, 5.2, 5.3_

- [ ] 4. Checkpoint — Ensure all tests pass
  - Run `flutter test`; ensure all model and service tests pass. Ask the user if questions arise.

- [ ] 5. State notifiers
  - [x] 5.1 Implement `ScannerNotifier` in `lib/state/scanner_notifier.dart`
    - Owns `ScannerState`; exposes `devices`, `errorMessage`, `connectingDevice`
    - `startScan()` → state = scanning; subscribes to `BleManager.scanResults`
    - `stopScan()` → state = idle
    - `connectTo(BluetoothDevice)` → state = connecting; on success emits connected device; on failure → state = error with message
    - `cancelConnection()` → aborts connect; state = scanning
    - `clearError()` → state = idle
    - Handles BLE-disabled and permission-denied errors with descriptive messages
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 1.6, 1.8, 1.9, 7.1, 7.8, 7.9, 7.10, 7.11, 7.12, 7.13, 7.14, 7.15, 7.16, 7.20_
  - [ ]* 5.2 Write unit tests for `ScannerNotifier` state transitions
    - Test: idle → scanning → connecting → error → idle cycle
    - Test: BLE-disabled and permission-denied error messages
    - Test: `cancelConnection` restores scanning state
    - _Requirements: 1.1, 1.8, 1.9, 7.11, 7.12, 7.13_
  - [ ]* 5.3 Write property test for devices-disabled-during-connecting (Property 2)
    - **Property 2: All devices disabled during connecting**
    - Use `glados` to generate random lists of N devices; assert all items non-interactive when `ScannerState == connecting`
    - **Validates: Requirements 1.6, 7.14**
  - [x] 5.4 Implement `DashboardNotifier` in `lib/state/dashboard_notifier.dart`
    - `init(BluetoothDevice)`: subscribes to `gloveDataStream` and `connectionState`; calls `enableAutoReconnect`
    - On new `GloveData`: updates `latestData`, calls `TtsService.speak` if `voiceEnabled` and status is HELP_NEEDED or WARNING
    - On connection lost: state = reconnecting; on reconnect success: re-subscribe, state = connected
    - On unrecoverable error: state = error
    - `disconnect()`: `disableAutoReconnect()` → `BleManager.disconnect()` → state = disconnected
    - `toggleVoice(bool)`: updates `voiceEnabled`, persists via `PreferencesService`, calls `TtsService.stop()` if disabling
    - Loads initial voice state from `PreferencesService` in `init`
    - _Requirements: 2.1, 2.5, 2.6, 2.7, 3.3, 4.1, 4.2, 4.3, 4.4, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4_
  - [ ]* 5.5 Write unit tests for `DashboardNotifier`
    - Test: data updates, voice toggle on/off, disconnect flow, reconnect state transitions
    - _Requirements: 4.1, 4.2, 4.4, 5.2, 5.4, 6.2, 6.3_
  - [ ]* 5.6 Write property test for TTS fires iff voice enabled (Property 6)
    - **Property 6: TTS fires if and only if voice is enabled**
    - Use `glados` to generate any `GloveStatus` × `bool` voiceEnabled combination
    - Assert `TtsService.speak` called iff `voiceEnabled == true`
    - **Validates: Requirements 4.1, 4.2, 4.4**

- [ ] 6. ScannerScreen UI and wiring
  - [x] 6.1 Implement `ScannerScreen` in `lib/screens/scanner_screen.dart`
    - Consumes `ScannerNotifier` via `context.watch<ScannerNotifier>()`
    - `idle` state: "Start Scanning" button visible
    - `scanning` state: device list + "Stop Scanning" button; never show both scan buttons simultaneously
    - `connecting` state: loading indicator on tapped device; all other items disabled; "Cancel" button visible
    - `error` state: descriptive message + recovery button ("Open Bluetooth Settings" / "Open App Settings" / "Retry")
    - On successful connect: show success popup then `Navigator.pushNamed(context, '/dashboard', arguments: device)`
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 1.7, 1.8, 1.9, 7.1, 7.8, 7.9, 7.11, 7.12, 7.13, 7.14, 7.15, 7.16, 7.20_
  - [ ]* 6.2 Write widget tests for `ScannerScreen`
    - Test: button visibility per `ScannerState` (never both scan buttons at once)
    - Test: loading indicator on connecting device, all others disabled
    - Test: error messages and recovery buttons rendered
    - _Requirements: 1.3, 1.5, 1.6, 1.8, 7.11, 7.12, 7.13_
  - [ ]* 6.3 Write property test for scan button mutual exclusion (Property 8)
    - **Property 8: Scan button mutual exclusion invariant**
    - Use `glados` to generate any `ScannerState`; render `ScannerScreen` and assert "Start Scanning" and "Stop Scanning" are never both visible
    - **Validates: Requirements 7.11, 7.12, 7.13**

- [ ] 7. DashboardScreen UI and wiring
  - [x] 7.1 Implement `DashboardScreen` in `lib/screens/dashboard_screen.dart`
    - Consumes `DashboardNotifier` via `context.watch<DashboardNotifier>()`
    - Calls `notifier.init(device)` in `initState`
    - Status card: rounded card with color from `DeviceStatus.fromGloveStatus`, large status label
    - Relay status: displays "ON", "OFF", or "—" for unknown — never empty
    - Signal indicator: connected/disconnected icon reflecting `DashboardState`
    - Timestamp: human-readable last-update time
    - Voice toggle switch with label; calls `notifier.toggleVoice`
    - Disconnect button: enabled when connected; shows loading indicator while disconnecting; disabled during disconnect
    - `reconnecting` state: signal indicator shows disconnected + reconnect spinner
    - `disconnected` / `error` state: error dialog with "Return to Scanner" button
    - Wrap in `PopScope(onPopInvoked: ...)` to intercept hardware back button and trigger `notifier.disconnect()`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 5.4, 5.5, 6.1, 6.2, 6.3, 7.4, 7.6, 7.17, 7.18, 7.19, 7.21, 7.22, 7.23_
  - [ ]* 7.2 Write widget tests for `DashboardScreen`
    - Test: correct card color per `GloveStatus`
    - Test: relay display is "ON", "OFF", or placeholder — never empty
    - Test: signal indicator reflects connection state
    - Test: voice toggle calls `toggleVoice`
    - Test: disconnect button disabled during disconnect operation
    - Test: error dialog with recovery button rendered in error/disconnected states
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.6, 7.17, 7.18, 7.21, 7.22, 7.23_
  - [ ]* 7.3 Write property test for relay display (Property 4)
    - **Property 4: Relay status display is always "ON", "OFF", or placeholder**
    - Use `glados` to generate any `RelayStatus` value; render relay widget and assert output is never empty or null
    - **Validates: Requirements 2.5**
  - [ ]* 7.4 Write property test for error recovery button (Property 10)
    - **Property 10: Every error state has a recovery action**
    - Use `glados` to generate any error state (`ScannerState.error`, `DashboardState.error`, `DashboardState.disconnected`)
    - Assert at least one visible, labeled action button is rendered
    - **Validates: Requirements 7.20, 7.21, 7.22, 7.23**

- [ ] 8. Navigation, app root, and final wiring
  - [x] 8.1 Implement `main.dart` and `app.dart`
    - Set up `MultiProvider` at root with `BleManager`, `TtsService`, `PreferencesService`, `ScannerNotifier`, `DashboardNotifier`
    - Define named routes: `/` → `ScannerScreen`, `/dashboard` → `DashboardScreen`
    - Pass `BluetoothDevice` argument from `ScannerScreen` to `DashboardScreen` via route arguments
    - _Requirements: 7.1, 7.2, 7.3_
  - [x] 8.2 Wire back-navigation and disconnect flow
    - Confirm `PopScope` on `DashboardScreen` calls `notifier.disconnect()` then `Navigator.pushReplacementNamed(context, '/')`
    - After navigating back to `ScannerScreen`, confirm `ScannerNotifier.startScan()` is called automatically so scanner is never idle on return
    - Confirm `Navigator.pushNamed` to `/dashboard` only fires when `BleManager.isConnected == true`
    - _Requirements: 7.4, 7.5, 7.6, 7.7_
  - [ ]* 8.3 Write property test for navigation guard (Property 9)
    - **Property 9: Navigation guard — Dashboard requires active connection**
    - Use `glados` to generate sequences of `ScannerNotifier` state transitions; assert navigation to `/dashboard` only occurs when `BleManager.isConnected == true`
    - **Validates: Requirements 7.3**

- [ ] 9. Final checkpoint — Ensure all tests pass
  - Run `flutter test`; ensure all unit, widget, and property-based tests pass. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical boundaries
- Property tests use the `glados` package with a minimum of 100 iterations per property
- Unit tests and property tests are complementary — both are needed for full coverage
