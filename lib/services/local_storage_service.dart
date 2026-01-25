import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';

class LocalStorageService {
  static const String _configKey = 'app_config';

  Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<AppConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configString = prefs.getString(_configKey);
    if (configString != null) {
      return AppConfig.fromJson(jsonDecode(configString));
    }
    return null;
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
  }
}
