enum GloveStatus { helpNeeded, warning, normal, unknown }

enum RelayStatus { on, off, unknown }

class GloveData {
  final GloveStatus status;
  final RelayStatus relayStatus;
  final DateTime timestamp;

  const GloveData({
    required this.status,
    required this.relayStatus,
    required this.timestamp,
  });

  /// Parses a raw UTF-8 string from the BLE characteristic.
  /// Expected format: "HELP NEEDED", "WARNING", "NORMAL"
  /// Relay status is parsed from the optional second segment after "|"
  /// (e.g. "NORMAL|ON"). Unrecognised values map to unknown — never throws.
  factory GloveData.fromRaw(String raw) {
    final segments = raw.split('|');
    final statusSegment = segments[0].trim().toUpperCase();
    final relaySegment =
        segments.length > 1 ? segments[1].trim().toUpperCase() : '';

    final GloveStatus status;
    switch (statusSegment) {
      case 'HELP NEEDED':
        status = GloveStatus.helpNeeded;
        break;
      case 'WARNING':
        status = GloveStatus.warning;
        break;
      case 'NORMAL':
        status = GloveStatus.normal;
        break;
      default:
        status = GloveStatus.unknown;
    }

    final RelayStatus relayStatus;
    switch (relaySegment) {
      case 'ON':
        relayStatus = RelayStatus.on;
        break;
      case 'OFF':
        relayStatus = RelayStatus.off;
        break;
      default:
        relayStatus = RelayStatus.unknown;
    }

    return GloveData(
      status: status,
      relayStatus: relayStatus,
      timestamp: DateTime.now(),
    );
  }

  /// Returns a copy with an updated timestamp.
  GloveData copyWith({DateTime? timestamp}) {
    return GloveData(
      status: status,
      relayStatus: relayStatus,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
