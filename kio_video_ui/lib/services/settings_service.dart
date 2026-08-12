import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _geminiKeyPref = 'gemini_api_key';
  
  late SharedPreferences _prefs;
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  String get geminiApiKey => _prefs.getString(_geminiKeyPref) ?? '';
  
  bool get hasApiKey => geminiApiKey.isNotEmpty;
  
  Future<void> setGeminiApiKey(String key) async {
    await _prefs.setString(_geminiKeyPref, key);
  }
}
