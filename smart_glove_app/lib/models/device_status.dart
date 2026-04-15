import 'package:flutter/material.dart';
import 'glove_data.dart';

class DeviceStatus {
  final Color cardColor;
  final String label;
  final IconData icon;

  const DeviceStatus({
    required this.cardColor,
    required this.label,
    required this.icon,
  });

  static DeviceStatus fromGloveStatus(GloveStatus status) {
    switch (status) {
      case GloveStatus.helpNeeded:
        return const DeviceStatus(
          cardColor: Colors.red,
          label: 'HELP NEEDED',
          icon: Icons.warning_rounded,
        );
      case GloveStatus.warning:
        return const DeviceStatus(
          cardColor: Colors.orange,
          label: 'WARNING',
          icon: Icons.warning_amber_rounded,
        );
      case GloveStatus.normal:
        return const DeviceStatus(
          cardColor: Colors.green,
          label: 'NORMAL',
          icon: Icons.check_circle_rounded,
        );
      case GloveStatus.unknown:
        return const DeviceStatus(
          cardColor: Colors.grey,
          label: 'UNKNOWN',
          icon: Icons.help_outline_rounded,
        );
    }
  }
}
