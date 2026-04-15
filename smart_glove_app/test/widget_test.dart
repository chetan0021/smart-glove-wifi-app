import 'package:flutter_test/flutter_test.dart';
import 'package:smart_glove_app/models/glove_data.dart';
import 'package:smart_glove_app/models/app_states.dart';
import 'package:smart_glove_app/models/device_status.dart';
import 'package:flutter/material.dart';

void main() {
  group('GloveData.fromRaw', () {
    test('parses HELP NEEDED', () {
      final d = GloveData.fromRaw('HELP NEEDED');
      expect(d.status, GloveStatus.helpNeeded);
      expect(d.relayStatus, RelayStatus.unknown);
    });

    test('parses WARNING', () {
      final d = GloveData.fromRaw('WARNING');
      expect(d.status, GloveStatus.warning);
    });

    test('parses NORMAL', () {
      final d = GloveData.fromRaw('NORMAL');
      expect(d.status, GloveStatus.normal);
    });

    test('parses relay segment', () {
      final d = GloveData.fromRaw('NORMAL|ON');
      expect(d.status, GloveStatus.normal);
      expect(d.relayStatus, RelayStatus.on);
    });

    test('parses relay OFF', () {
      final d = GloveData.fromRaw('WARNING|OFF');
      expect(d.relayStatus, RelayStatus.off);
    });

    test('handles garbage without throwing', () {
      final d = GloveData.fromRaw('???garbage???');
      expect(d.status, GloveStatus.unknown);
      expect(d.relayStatus, RelayStatus.unknown);
    });

    test('handles empty string without throwing', () {
      final d = GloveData.fromRaw('');
      expect(d.status, GloveStatus.unknown);
    });

    test('trims whitespace', () {
      final d = GloveData.fromRaw('  NORMAL  |  ON  ');
      expect(d.status, GloveStatus.normal);
      expect(d.relayStatus, RelayStatus.on);
    });
  });

  group('ConnectionStatus enum', () {
    test('ConnectionStatus has all values', () {
      expect(ConnectionStatus.values.length, 4);
    });
  });

  group('DeviceStatus.fromGloveStatus', () {
    test('helpNeeded → red', () {
      final ds = DeviceStatus.fromGloveStatus(GloveStatus.helpNeeded);
      expect(ds.cardColor, Colors.red);
      expect(ds.label, 'HELP NEEDED');
    });

    test('warning → orange', () {
      final ds = DeviceStatus.fromGloveStatus(GloveStatus.warning);
      expect(ds.cardColor, Colors.orange);
    });

    test('normal → green', () {
      final ds = DeviceStatus.fromGloveStatus(GloveStatus.normal);
      expect(ds.cardColor, Colors.green);
    });

    test('unknown → grey, never throws', () {
      final ds = DeviceStatus.fromGloveStatus(GloveStatus.unknown);
      expect(ds.cardColor, Colors.grey);
    });

    test('all enum values handled without throwing', () {
      for (final status in GloveStatus.values) {
        expect(() => DeviceStatus.fromGloveStatus(status), returnsNormally);
      }
    });
  });
}
