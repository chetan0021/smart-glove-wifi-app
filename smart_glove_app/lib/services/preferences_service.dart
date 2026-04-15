import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _voiceKey = 'voice_enabled';

  Future<bool> getVoiceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_voiceKey) ?? true;
  }

  Future<void> setVoiceEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceKey, value);
  }
}
