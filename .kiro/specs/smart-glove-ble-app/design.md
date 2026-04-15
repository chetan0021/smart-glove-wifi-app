# Design Document: Smart Glove BLE App

## Overview

A Flutter mobile application for Android and iOS that connects to an ESP32 BLE peripheral named "SmartGlove". The app scans for the device, establishes a BLE connection, subscribes to a characteristic for live status updates, displays a color-coded dashboard, and announces alerts via text-to-speech. The connection is maintained in the background with automatic reconnection.

**Key packages:**
- `flutter_blue_plus` — BLE scanning, connecting, characteristic subscription
- `flutter_tts` — text-to-speech announcements
- `shared_preferences` — voice toggle persistence
- `provider` — state management

---

## Architecture

The app follows a layered architecture with clear separation between services, state, and UI.

```
┌─────────────────────────────────────────────────────┐
│                     UI Layer                        │
│         ScannerScreen      DashboardScreen          │
└──────────────────┬──────────────────────────────────┘
                   │ watches / calls
┌──────────────────▼──────────────────────────────────┐
│                  State Layer                        │
│    ScannerNotifier          DashboardNotifier       │
└──────────┬───────────────────────┬──────────────────┘
           │                       │
┌──────────▼──────────┐  ┌─────────▼──────────────────┐
│     BleManager      │  │  TtsService                │
│  (scanning, conn,   │  │  PreferencesService        │
│   reconnect, subs)  │  └────────────────────────────┘
└─────────────────────┘
```

**State management: Provider**

Two `ChangeNotifier` classes (`ScannerNotifier`, `DashboardNotifier`) are provided at the app root via `MultiProvider`. Services (`BleManager`, `TtsService`, `PreferencesService`) are plain Dart classes injected into notifiers via constructor.

**Navigation: Named routes (Navigator 2.0 not required)**

Two named routes: `/` → `ScannerScreen`, `/dashboard` → `DashboardScreen`. The connected `BluetoothDevice` is passed as a route argument. The back button on `DashboardScreen` is intercepted via `PopScope` (Flutter 3.x) to trigger disconnect logic.

---

## Components and Interfaces

### BleManager

Responsible for all BLE operations. Exposes streams and methods consumed by `ScannerNotifier` and `DashboardNotifier`.

```dart
class BleManager {
  // Scanning
  Future<void> startScan();
  Future<void> stopScan();
  Stream<List<ScanResult>> get scanResults; // filtered to "SmartGlove"

  // Connection
  Future<void> connect(BluetoothDevice device);
  Future<void> disconnect();
  Stream<BluetoothConnectionState> get connectionState;

  // Characteristic subscription
  Future<void> subscribeToCharacteristic(BluetoothDevice device);
  Stream<GloveData> get gloveDataStream;

  // Reconnect
  void enableAutoReconnect(BluetoothDevice device);
  void disableAutoReconnect();

  // State
  bool get isScanning;
  bool get isConnecting;
  bool get isConnected;
}
```

Auto-reconnect runs in an isolated async loop (`_reconnectLoop`) that listens to `connectionState` and retries with exponential back-off (1 s, 2 s, 4 s, max 30 s). It is cancelled when the user explicitly disconnects.

### TtsService

Thin wrapper around `flutter_tts`.

```dart
class TtsService {
  Future<void> init();
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> setVolume(double volume); // 0.0–1.0
}
```

### PreferencesService

Wraps `shared_preferences` for voice toggle persistence.

```dart
class PreferencesService {
  Future<bool> getVoiceEnabled();
  Future<void> setVoiceEnabled(bool value);
}
```

### ScannerNotifier (`ChangeNotifier`)

Owns `ScannerState` and orchestrates `BleManager` for scanning and connecting.

```dart
class ScannerNotifier extends ChangeNotifier {
  ScannerState get state;
  List<ScanResult> get devices;
  String? get errorMessage;

  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connectTo(BluetoothDevice device);
  Future<void> cancelConnection();
  void clearError();
}
```

### DashboardNotifier (`ChangeNotifier`)

Owns `DashboardState`, listens to `BleManager.gloveDataStream` and `connectionState`, drives TTS.

```dart
class DashboardNotifier extends ChangeNotifier {
  DashboardState get state;
  GloveData? get latestData;
  bool get voiceEnabled;
  bool get isReconnecting;

  Future<void> init(BluetoothDevice device);
  Future<void> disconnect();
  Future<void> toggleVoice(bool enabled);
  void dispose();
}
```

---

## Data Models

### GloveData

Parsed from the UTF-8 BLE notification payload.

```dart
enum GloveStatus { helpNeeded, warning, normal, unknown }

enum RelayStatus { on, off, unknown }

class GloveData {
  final GloveStatus status;
  final RelayStatus relayStatus;
  final DateTime timestamp;

  /// Parses a raw UTF-8 string from the BLE characteristic.
  /// Expected format: "HELP NEEDED", "WARNING", "NORMAL"
  /// Relay status is parsed from the same string if present
  /// (e.g. "NORMAL|ON") or defaults to unknown if not included.
  factory GloveData.fromRaw(String raw);

  /// Returns a copy with updated timestamp.
  GloveData copyWith({DateTime? timestamp});
}
```

Parsing strategy for `fromRaw`:
1. Split on `|` — first segment is status, optional second segment is relay.
2. Trim and uppercase both segments before matching.
3. Unrecognised values map to `unknown` variants — never throw.

### ScannerState (enum)

```dart
enum ScannerState { idle, scanning, connecting, error }
```

### DashboardState (enum)

```dart
enum DashboardState { connected, reconnecting, disconnected, error }
```

### DeviceStatus (UI helper)

```dart
class DeviceStatus {
  final Color cardColor;
  final String label;
  final IconData icon;

  static DeviceStatus fromGloveStatus(GloveStatus status);
}
```

---

## Screen Wiring Diagram

```
App Launch
    │
    ▼
ScannerScreen (/)
  ├─ [idle]        → "Start Scanning" button visible
  ├─ [scanning]    → device list + "Stop Scanning" button
  │     └─ tap device → [connecting]
  ├─ [connecting]  → loading indicator on tapped item
  │                   all other items disabled
  │                   "Cancel" button visible
  │     ├─ success → success popup → navigate /dashboard
  │     └─ failure → [error] → error message + "Retry" button
  └─ [error]       → error message + recovery button
        └─ BLE off  → "Open Bluetooth Settings"
        └─ no perm  → "Open App Settings"
        └─ conn fail → "Retry" (restarts scan)

DashboardScreen (/dashboard)
  ├─ [connected]    → status card, relay, signal ✓, voice toggle, disconnect btn
  ├─ [reconnecting] → signal indicator = disconnected, reconnect spinner
  ├─ [disconnected] → error dialog + "Return to Scanner"
  └─ [error]        → error dialog + "Return to Scanner"

Back button / disconnect btn on Dashboard
    └─ disableAutoReconnect → disconnect → navigate / → startScan
```

---

## Error Handling Strategy

| Scenario | Detection | Recovery UI |
|---|---|---|
| BLE disabled | `FlutterBluePlus.adapterState` | Message + "Open Bluetooth Settings" button |
| Permissions denied | `flutter_blue_plus` permission error | Message + "Open App Settings" button |
| Connection attempt fails | `connect()` throws / timeout | Error message + "Retry" button (restarts scan) |
| Characteristic not found | `subscribeToCharacteristic` returns null | Error dialog + "Disconnect" button → Scanner |
| Connection lost (background) | `connectionState` stream emits disconnected | Auto-reconnect loop; signal indicator updates |
| Fatal BLE error on Dashboard | Unrecoverable exception in `DashboardNotifier` | Error dialog + "Return to Scanner" button |
| Malformed BLE payload | `GloveData.fromRaw` maps to `unknown` | No crash; dashboard shows "—" for unknown fields |

All error states expose at least one labeled recovery action (Requirement 7.23). No error is swallowed silently.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*


### Property Reflection

Reviewing all PROPERTY-classified criteria before writing final properties:

- **1.2** (filter to "SmartGlove") and **1.6** (all devices disabled during connecting) are distinct — both kept.
- **2.2, 2.3, 2.4** (status-to-color mapping) are three facets of the same mapping rule — consolidated into one property covering all GloveStatus values.
- **2.5** (relay display) is independent — kept.
- **2.7** (timestamp formatting) is independent — kept.
- **3.2** (UTF-8 parsing) feeds directly into **GloveData.fromRaw** round-trip — merged into a single parse round-trip property.
- **4.1, 4.2, 4.4** (TTS mapping) are all facets of the same status×voice-toggle → TTS-call rule — consolidated into one property.
- **6.4** (voice toggle persistence) is a classic round-trip property — kept.
- **7.3** (navigation guard) is an invariant — kept.
- **7.11–7.13** (mutually exclusive scan buttons) is an invariant — kept.
- **7.20–7.23** (every error has a recovery button) is an invariant — kept.

Final consolidated property list: 8 properties.

---

### Property 1: Scan results filter to SmartGlove only

*For any* list of BLE scan results with arbitrary device names, the filtered output exposed by `BleManager` SHALL contain only entries whose advertised name is exactly "SmartGlove".

**Validates: Requirements 1.2**

---

### Property 2: All devices disabled during connecting

*For any* list of N discovered devices, when `ScannerState` is `connecting`, every device list item in the `ScannerScreen` SHALL be non-interactive (taps ignored / buttons disabled).

**Validates: Requirements 1.6, 7.14**

---

### Property 3: Status-to-color mapping is total and correct

*For any* `GloveStatus` value, `DeviceStatus.fromGloveStatus` SHALL return red for `helpNeeded`, orange for `warning`, green for `normal`, and a defined fallback color for `unknown` — and SHALL never throw.

**Validates: Requirements 2.2, 2.3, 2.4**

---

### Property 4: Relay status display is always "ON" or "OFF"

*For any* `RelayStatus` value, the string rendered on the `DashboardScreen` for relay status SHALL be exactly "ON", "OFF", or a defined placeholder for `unknown` — and SHALL never be empty or null.

**Validates: Requirements 2.5**

---

### Property 5: GloveData parse round-trip

*For any* valid UTF-8 string in the format produced by the SmartGlove device (including strings with and without a relay segment, and strings with extra whitespace), `GloveData.fromRaw` SHALL produce a `GloveData` whose `status` and `relayStatus` fields are non-null and SHALL never throw an exception.

**Validates: Requirements 3.2, 3.3**

---

### Property 6: TTS fires if and only if voice is enabled

*For any* `GloveStatus` value and any voice toggle state, `DashboardNotifier` SHALL call `TtsService.speak` with the correct phrase when voice is enabled and SHALL NOT call `TtsService.speak` when voice is disabled.

**Validates: Requirements 4.1, 4.2, 4.4**

---

### Property 7: Voice toggle persistence round-trip

*For any* boolean voice toggle value, saving it via `PreferencesService.setVoiceEnabled` and then reading it back via `PreferencesService.getVoiceEnabled` SHALL return the same value.

**Validates: Requirements 6.4**

---

### Property 8: Scan button mutual exclusion invariant

*For any* `ScannerState` value, the `ScannerScreen` SHALL never render both the "Start Scanning" and "Stop Scanning" buttons as visible simultaneously.

**Validates: Requirements 7.11, 7.12, 7.13**

---

### Property 9: Navigation guard — Dashboard requires active connection

*For any* sequence of state transitions in `ScannerNotifier`, navigation to `/dashboard` SHALL only occur when `BleManager.isConnected` is `true` at the moment of navigation.

**Validates: Requirements 7.3**

---

### Property 10: Every error state has a recovery action

*For any* error state (`ScannerState.error`, `DashboardState.error`, `DashboardState.disconnected`), the rendered screen SHALL contain at least one visible, labeled action button that leads to a non-error state.

**Validates: Requirements 7.20, 7.21, 7.22, 7.23**

---

## Testing Strategy

### Dual Testing Approach

Unit tests cover specific examples, edge cases, and error conditions. Property-based tests verify universal invariants across generated inputs. Both are required for comprehensive coverage.

**Property-based testing library:** [`dart_test` + `fast_check` (Dart port)](https://pub.dev/packages/fast_check) or `glados` (Dart PBT library). Each property test runs a minimum of **100 iterations**.

Each property test is tagged with:
```
// Feature: smart-glove-ble-app, Property N: <property_text>
```

### Unit Tests

- `ScannerNotifier`: state transitions (idle → scanning → connecting → error → idle)
- `DashboardNotifier`: data updates, voice toggle, disconnect flow
- `BleManager`: mock `flutter_blue_plus` — verify scan filter, connect/disconnect calls, reconnect loop initiation
- `TtsService`: verify `speak` and `stop` are called correctly
- `PreferencesService`: mock `shared_preferences` — read/write round-trip
- Widget tests for `ScannerScreen`: button visibility per state, loading indicator, error messages
- Widget tests for `DashboardScreen`: color cards, relay display, signal indicator, voice toggle

### Property-Based Tests

| Property | Generator | Assertion |
|---|---|---|
| P1: Scan filter | Random list of `ScanResult` with arbitrary names | Output contains only "SmartGlove" entries |
| P2: Devices disabled during connecting | Random list of N devices | All items non-interactive when state == connecting |
| P3: Status-to-color mapping | Any `GloveStatus` enum value | Correct color returned, no throw |
| P4: Relay display | Any `RelayStatus` enum value | Output is "ON", "OFF", or defined placeholder |
| P5: GloveData parse round-trip | Random strings (valid formats + edge cases) | Non-null fields, no exception |
| P6: TTS fires iff voice enabled | Any `GloveStatus` × `bool` voiceEnabled | speak called iff voiceEnabled == true |
| P7: Voice toggle persistence | Any `bool` | Read-back equals written value |
| P8: Scan button mutual exclusion | Any `ScannerState` | Never both buttons visible |
| P9: Navigation guard | Any sequence of state transitions | Navigate only when isConnected == true |
| P10: Error recovery button | Any error state | At least one recovery button rendered |

### Integration Tests

- Full BLE scan → connect → dashboard flow on a real or emulated device
- Background connection maintenance (manual test on physical device)
- TTS output on device (manual verification)

### Test Configuration

```dart
// Example property test tag format
// Feature: smart-glove-ble-app, Property 1: scan results filter to SmartGlove only
test('P1: scan filter', () async {
  await Glados<List<String>>().test((names) {
    final results = names.map((n) => fakeScanResult(name: n)).toList();
    final filtered = bleManager.filterResults(results);
    expect(filtered.every((r) => r.device.name == 'SmartGlove'), isTrue);
  });
}, count: 100);
```
