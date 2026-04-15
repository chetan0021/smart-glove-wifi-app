import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_states.dart';
import '../models/device_status.dart';
import '../models/glove_data.dart';
import '../state/glove_notifier.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GloveNotifier>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<GloveNotifier>();
    final connected = notifier.isConnected;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'SmartGlove',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          _WifiStatusButton(status: notifier.status),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: connected
            ? _ConnectedBody(notifier: notifier)
            : _DisconnectedBody(notifier: notifier),
      ),
    );
  }
}

// ── WiFi Status AppBar Button ──────────────────────────────────────────────────

class _WifiStatusButton extends StatelessWidget {
  final ConnectionStatus status;
  const _WifiStatusButton({required this.status});

  @override
  Widget build(BuildContext context) {
    final isConnected = status == ConnectionStatus.connected;
    final isConnecting = status == ConnectionStatus.connecting;
    final color = isConnected
        ? Colors.green
        : isConnecting
            ? Colors.orange
            : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isConnecting
            ? const SizedBox(
                key: ValueKey('spinner'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.orange),
              )
            : Icon(
                isConnected ? Icons.wifi : Icons.wifi_off,
                color: color,
                size: 26,
                key: ValueKey(status),
              ),
      ),
    );
  }
}

// ── Connected Body ────────────────────────────────────────────────────────────

class _ConnectedBody extends StatelessWidget {
  final GloveNotifier notifier;
  const _ConnectedBody({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Device name banner
          const _InfoBanner(
            icon: Icons.wifi,
            color: Colors.green,
            message: 'Connected to SmartGlove_AP',
          ),
          const SizedBox(height: 16),

          // Status card
          _StatusCard(notifier: notifier),
          const SizedBox(height: 16),

          // Relay card
          _RelayCard(notifier: notifier),
          const SizedBox(height: 16),

          // Timestamp card
          _TimestampCard(notifier: notifier),
          const SizedBox(height: 16),

          // Voice toggle
          _VoiceToggleCard(notifier: notifier),
          const SizedBox(height: 24),

          // Disconnect
          ElevatedButton.icon(
            onPressed: () => notifier.disconnect(),
            icon: const Icon(Icons.wifi_off),
            label: const Text('Disconnect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Disconnected Body ─────────────────────────────────────────────────────────

class _DisconnectedBody extends StatelessWidget {
  final GloveNotifier notifier;
  const _DisconnectedBody({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final isError = notifier.status == ConnectionStatus.error;
    final isConnecting = notifier.status == ConnectionStatus.connecting;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.router,
                  size: 56, color: Colors.blueAccent),
            ),
            const SizedBox(height: 28),
            Text(
              isError
                  ? 'Connection Failed'
                  : isConnecting
                      ? 'Connecting...'
                      : 'Not Connected',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (isError) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  notifier.errorMessage ?? 'An error occurred.',
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
              const SizedBox(height: 24),
            ] else if (!isConnecting) ...[
               Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Column(
                  children: [
                    Text('How to Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 12),
                    Text('1. Go to your phone\'s WiFi settings'),
                    Text('2. Connect to the "SmartGlove_AP" network'),
                    Text('3. Return to this app and tap below'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
            
            ElevatedButton.icon(
              onPressed: isConnecting ? null : () => notifier.connect(),
              icon: Icon(isError ? Icons.refresh : Icons.cable),
              label: Text(isConnecting ? 'Connecting...' : 'Connect to Glove'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _InfoBanner({required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Status Card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final GloveNotifier notifier;
  const _StatusCard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final data = notifier.latestData;
    final status = data?.status ?? GloveStatus.unknown;
    final ds = DeviceStatus.fromGloveStatus(status);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      color: ds.cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          children: [
            Icon(ds.icon, size: 56, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              data == null ? 'Awaiting Data...' : ds.label,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Current Status',
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Relay Card ────────────────────────────────────────────────────────────────

class _RelayCard extends StatelessWidget {
  final GloveNotifier notifier;
  const _RelayCard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final relay = notifier.latestData?.relayStatus ?? RelayStatus.unknown;
    final String label;
    final Color color;
    switch (relay) {
      case RelayStatus.on:
        label = 'ON';
        color = Colors.green;
        break;
      case RelayStatus.off:
        label = 'OFF';
        color = Colors.red;
        break;
      case RelayStatus.unknown:
        label = '—';
        color = Colors.grey;
        break;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.power, size: 32),
        title: const Text('Relay Status', style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color),
          ),
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }
}

// ── Timestamp Card ────────────────────────────────────────────────────────────

class _TimestampCard extends StatelessWidget {
  final GloveNotifier notifier;
  const _TimestampCard({required this.notifier});

  String _format(DateTime? dt) {
    if (dt == null) return 'No data yet';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.access_time_rounded, size: 32),
        title: const Text('Last Updated', style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          _format(notifier.latestData?.timestamp),
          style: const TextStyle(fontSize: 15, color: Colors.black54),
        ),
      ),
    );
  }
}

// ── Voice Toggle Card ─────────────────────────────────────────────────────────

class _VoiceToggleCard extends StatelessWidget {
  final GloveNotifier notifier;
  const _VoiceToggleCard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        secondary: Icon(
          notifier.voiceEnabled ? Icons.volume_up : Icons.volume_off,
          size: 32,
        ),
        title: const Text('Voice Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(notifier.voiceEnabled ? 'Enabled' : 'Disabled'),
        value: notifier.voiceEnabled,
        onChanged: notifier.toggleVoice,
      ),
    );
  }
}
