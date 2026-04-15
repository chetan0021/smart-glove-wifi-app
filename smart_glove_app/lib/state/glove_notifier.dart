import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_states.dart';
import '../models/glove_data.dart';
import '../services/ws_manager.dart';
import '../services/tts_service.dart';
import '../services/preferences_service.dart';

class GloveNotifier extends ChangeNotifier {
  final WsManager _wsManager;
  final TtsService _ttsService;
  final PreferencesService _prefsService;

  GloveNotifier(this._wsManager, this._ttsService, this._prefsService);

  // ── State ───────────────────────────────────────────────────────────────────
  ConnectionStatus _status = ConnectionStatus.disconnected;
  GloveData? _latestData;
  String? _errorMessage;
  bool _voiceEnabled = true;

  ConnectionStatus get status => _status;
  GloveData? get latestData => _latestData;
  String? get errorMessage => _errorMessage;
  bool get voiceEnabled => _voiceEnabled;
  bool get isConnected => _status == ConnectionStatus.connected;

  // ── Subscriptions ───────────────────────────────────────────────────────────
  StreamSubscription<GloveData>? _dataSub;

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _voiceEnabled = await _prefsService.getVoiceEnabled();
    await _ttsService.init();
    
    // Auto-connect on startup since they might already be on the Wi-Fi
    await connect();
  }

  // ── Connect ─────────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_status == ConnectionStatus.connecting || _status == ConnectionStatus.connected) return;

    _status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      await _wsManager.connect();

      await _dataSub?.cancel();
      _dataSub = _wsManager.gloveDataStream.listen((data) {
        _latestData = data;
        
        // If we get data but somehow status isn't connected, fix it
        if (_status != ConnectionStatus.connected) {
          _status = ConnectionStatus.connected;
          _errorMessage = null;
        }
        
        notifyListeners();
        _handleTts(data.status);
      }, onDone: () {
        _handleDisconnect();
      }, onError: (_) {
        _handleDisconnect();
      });

      _status = ConnectionStatus.connected;
      _errorMessage = null;
      notifyListeners();
      
    } catch (e) {
      _setError('Ensure you are connected to "SmartGlove_AP" WiFi network.\n\nDetails: ${e.toString()}');
    }
  }

  void _handleDisconnect() {
     _status = ConnectionStatus.disconnected;
     _latestData = null;
     notifyListeners();
  }

  // ── Disconnect ──────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _dataSub?.cancel();
    _dataSub = null;
    await _wsManager.disconnect();
    _handleDisconnect();
  }

  // ── Voice ───────────────────────────────────────────────────────────────────

  Future<void> toggleVoice(bool enabled) async {
    _voiceEnabled = enabled;
    await _prefsService.setVoiceEnabled(enabled);
    if (!enabled) await _ttsService.stop();
    notifyListeners();
  }

  void _handleTts(GloveStatus status) {
    if (!_voiceEnabled) return;
    switch (status) {
      case GloveStatus.helpNeeded:
        _ttsService.setVolume(1.0).then((_) => _ttsService.speak('Help needed'));
        break;
      case GloveStatus.warning:
        _ttsService.setVolume(0.8).then((_) => _ttsService.speak('Warning alert'));
        break;
      case GloveStatus.normal:
        _ttsService.setVolume(0.5).then((_) => _ttsService.speak('Normal'));
        break;
      case GloveStatus.unknown:
        break;
    }
  }

  // ── Error ───────────────────────────────────────────────────────────────────

  void _setError(String msg) {
    _errorMessage = msg;
    _status = ConnectionStatus.error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _wsManager.dispose();
    super.dispose();
  }
}
