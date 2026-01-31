import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileCache {
  Directory? _cacheDir;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/media_cache');
    debugPrint('Cache directory: ${_cacheDir!.path}');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
      debugPrint('Created cache directory');
    } else {
      debugPrint('Cache directory already exists');
    }

    _initialized = true;
    debugPrint('FileCache initialized');
  }

  Future<Uint8List?> get(String key) async {
    if (!_initialized || _cacheDir == null) return null;

    final cacheFileName = _generateCacheFileName(key);
    final cacheFile = File('${_cacheDir!.path}/$cacheFileName');

    final exists = await cacheFile.exists();

    if (exists) {
      try {
        final data = await cacheFile.readAsBytes();
        return data;
      } catch (e) {
        debugPrint('Error reading cache file for key: $key, error: $e');
        // 如果读取失败，删除损坏的缓存文件
        await cacheFile.delete();
        return null;
      }
    }
    debugPrint('Cache miss for key: $key');
    return null;
  }

  Future<void> put(String key, Uint8List data) async {
    if (!_initialized || _cacheDir == null) {
      debugPrint('Cache not initialized, cannot put key: $key');
      return;
    }

    final cacheFileName = _generateCacheFileName(key);
    final cacheFile = File('${_cacheDir!.path}/$cacheFileName');

    try {
      await cacheFile.writeAsBytes(data);

      // 验证文件是否真的写入了
      final existsAfterWrite = await cacheFile.exists();
      debugPrint('File exists after write: $existsAfterWrite');
    } catch (e) {
      debugPrint('Error writing cache file for key: $key, error: $e');
      // 忽略写入错误
    }
  }

  Future<void> clear() async {
    if (!_initialized || _cacheDir == null) return;

    try {
      final files = await _cacheDir!.list().toList();
      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    } catch (e) {
      // 忽略清理错误
    }
  }

  String _generateCacheFileName(String key) {
    return md5.convert(utf8.encode(key)).toString();
  }
}
