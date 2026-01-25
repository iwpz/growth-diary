import 'dart:convert';
import 'dart:io';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../models/diary_entry.dart';
import '../models/app_config.dart';

class WebDAVService {
  webdav.Client? _client;
  AppConfig? _config;

  Future<void> initialize(AppConfig config) async {
    _config = config;
    if (config.webdavUrl.isNotEmpty && config.username.isNotEmpty) {
      _client = webdav.newClient(
        config.webdavUrl,
        user: config.username,
        password: config.password,
        debug: true,
      );
      _client!.setConnectTimeout(8000);
      _client!.setSendTimeout(8000);
      _client!.setReceiveTimeout(8000);
      
      // Create base directories if they don't exist
      try {
        await _client!.mkdir('growth_diary');
      } catch (e) {
        // Directory might already exist
      }
      try {
        await _client!.mkdir('growth_diary/entries');
      } catch (e) {
        // Directory might already exist
      }
      try {
        await _client!.mkdir('growth_diary/media');
      } catch (e) {
        // Directory might already exist
      }
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    if (_client == null) return;
    
    try {
      final jsonString = jsonEncode(config.toJson());
      await _client!.writeFromString(
        jsonString,
        'growth_diary/config.json',
      );
    } catch (e) {
      print('Error saving config: $e');
      rethrow;
    }
  }

  Future<AppConfig?> loadConfig() async {
    if (_client == null) return null;
    
    try {
      final content = await _client!.read('growth_diary/config.json');
      final jsonData = jsonDecode(content);
      return AppConfig.fromJson(jsonData);
    } catch (e) {
      print('Error loading config: $e');
      return null;
    }
  }

  Future<void> saveDiaryEntry(DiaryEntry entry) async {
    if (_client == null) return;
    
    try {
      final jsonString = jsonEncode(entry.toJson());
      await _client!.writeFromString(
        jsonString,
        'growth_diary/entries/${entry.id}.json',
      );
    } catch (e) {
      print('Error saving diary entry: $e');
      rethrow;
    }
  }

  Future<List<DiaryEntry>> loadAllEntries() async {
    if (_client == null) return [];
    
    try {
      final files = await _client!.readDir('growth_diary/entries');
      final entries = <DiaryEntry>[];
      
      for (var file in files) {
        if (file.name != null && file.name!.endsWith('.json')) {
          try {
            final content = await _client!.read('growth_diary/entries/${file.name}');
            final jsonData = jsonDecode(content);
            entries.add(DiaryEntry.fromJson(jsonData));
          } catch (e) {
            print('Error loading entry ${file.name}: $e');
          }
        }
      }
      
      // Sort by date descending
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    } catch (e) {
      print('Error loading entries: $e');
      return [];
    }
  }

  Future<String> uploadMedia(File file, String fileName) async {
    if (_client == null) throw Exception('WebDAV client not initialized');
    
    try {
      final path = 'growth_diary/media/$fileName';
      await _client!.writeFromFile(file.path, path);
      return path;
    } catch (e) {
      print('Error uploading media: $e');
      rethrow;
    }
  }

  Future<void> deleteEntry(String entryId) async {
    if (_client == null) return;
    
    try {
      await _client!.remove('growth_diary/entries/$entryId.json');
    } catch (e) {
      print('Error deleting entry: $e');
      rethrow;
    }
  }

  bool get isInitialized => _client != null;
}
