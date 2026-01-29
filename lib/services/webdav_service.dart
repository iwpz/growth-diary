import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:image/image.dart' as img;
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/diary_entry.dart';
import '../models/app_config.dart';

class WebDAVService {
  webdav.Client? _client;

  Future<void> initialize(AppConfig config) async {
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
        // Ignore if directory already exists (409 Conflict)
        debugPrint('mkdir growth_diary: $e');
      }
      try {
        await _client!.mkdir('growth_diary/entries');
      } catch (e) {
        // Ignore if directory already exists (409 Conflict)
        debugPrint('mkdir growth_diary/entries: $e');
      }
      try {
        await _client!.mkdir('growth_diary/media');
      } catch (e) {
        // Ignore if directory already exists (409 Conflict)
        debugPrint('mkdir growth_diary/media: $e');
      }
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    if (_client == null) return;

    try {
      final jsonString = jsonEncode(config.toJson());
      await _client!.write(
        'growth_diary/config.json',
        utf8.encode(jsonString),
      );
    } catch (e) {
      debugPrint('Error saving config: $e');
      rethrow;
    }
  }

  Future<AppConfig?> loadConfig() async {
    if (_client == null) return null;

    try {
      final content = await _client!.read('growth_diary/config.json');
      final jsonData = jsonDecode(utf8.decode(content));
      return AppConfig.fromJson(jsonData);
    } catch (e) {
      debugPrint('Error loading config: $e');
      return null;
    }
  }

  Future<void> saveDiaryEntry(DiaryEntry entry) async {
    if (_client == null) return;

    try {
      final jsonString = jsonEncode(entry.toJson());
      await _client!.write(
        'growth_diary/entries/${entry.id}.json',
        utf8.encode(jsonString),
      );
    } catch (e) {
      debugPrint('Error saving diary entry: $e');
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
            final content =
                await _client!.read('growth_diary/entries/${file.name}');
            final jsonData = jsonDecode(utf8.decode(content));
            entries.add(DiaryEntry.fromJson(jsonData));
          } catch (e) {
            debugPrint('Error loading entry ${file.name}: $e');
          }
        }
      }

      // Sort by date descending
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    } catch (e) {
      debugPrint('Error loading entries: $e');
      return [];
    }
  }

  Future<Uint8List?> downloadMedia(String path) async {
    if (_client == null) return null;

    try {
      final data = await _client!.read(path);
      return Uint8List.fromList(data);
    } catch (e) {
      debugPrint('Error downloading media: $e');
      return null;
    }
  }

  Future<String> uploadMedia(File file, String fileName) async {
    if (_client == null) throw Exception('WebDAV client not initialized');

    try {
      final path = 'growth_diary/media/$fileName';
      await _client!.writeFromFile(file.path, path);
      return path;
    } catch (e) {
      debugPrint('Error uploading media: $e');
      rethrow;
    }
  }

  Future<String> uploadImageWithThumbnails(File file, String fileName) async {
    if (_client == null) throw Exception('WebDAV client not initialized');

    try {
      // 上传原图
      final originalPath = 'growth_diary/media/$fileName';
      await _client!.writeFromFile(file.path, originalPath);

      // 生成中号缩略图 (用于详情页)
      final image = img.decodeImage(await file.readAsBytes());
      if (image != null) {
        final mediumThumbnail = img.copyResize(image, width: 400);
        final mediumData = img.encodeJpg(mediumThumbnail, quality: 85);
        final mediumFileName = '${fileName}_medium.jpg';
        final mediumPath = 'growth_diary/media/$mediumFileName';
        await _client!.write(mediumPath, mediumData);

        // 生成小号缩略图 (用于时间轴)
        final smallThumbnail = img.copyResize(image, width: 200);
        final smallData = img.encodeJpg(smallThumbnail, quality: 80);
        final smallFileName = '${fileName}_small.jpg';
        final smallPath = 'growth_diary/media/$smallFileName';
        await _client!.write(smallPath, smallData);

        return '$originalPath|$mediumPath|$smallPath';
      }

      return originalPath;
    } catch (e) {
      debugPrint('Error uploading image with thumbnails: $e');
      rethrow;
    }
  }

  Future<String> uploadVideoWithThumbnails(File file, String fileName) async {
    if (_client == null) throw Exception('WebDAV client not initialized');

    try {
      // 上传原视频
      final originalPath = 'growth_diary/media/$fileName';
      await _client!.writeFromFile(file.path, originalPath);

      // 生成缩略图
      Uint8List? thumbnail = await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400, // 中号缩略图
        quality: 75,
      );

      if (thumbnail == null) {
        // 生成默认缩略图
        final defaultImage = img.Image(width: 400, height: 300);
        img.fillRect(defaultImage,
            x1: 0,
            y1: 0,
            x2: 400,
            y2: 300,
            color: img.ColorUint8.rgba(0, 0, 0, 255)); // 黑色
        thumbnail = img.encodeJpg(defaultImage, quality: 75);
      }

      final mediumFileName = '${fileName}_medium.jpg';
      final mediumPath = 'growth_diary/media/$mediumFileName';
      await _client!.write(mediumPath, thumbnail);

      // 生成小号缩略图
      final image = img.decodeImage(thumbnail);
      if (image != null) {
        final smallThumbnail = img.copyResize(image, width: 200);
        final smallData = img.encodeJpg(smallThumbnail, quality: 70);
        final smallFileName = '${fileName}_small.jpg';
        final smallPath = 'growth_diary/media/$smallFileName';
        await _client!.write(smallPath, smallData);

        return '$originalPath|$mediumPath|$smallPath';
      }

      return originalPath;
    } catch (e) {
      debugPrint('Error uploading video with thumbnails: $e');
      rethrow;
    }
  }

  Future<void> deleteEntry(DiaryEntry entry) async {
    if (_client == null) return;

    try {
      // 删除所有相关的媒体文件
      final allMediaPaths = [
        ...entry.imagePaths,
        ...entry.videoPaths,
        ...entry.imageThumbnails,
        ...entry.videoThumbnails,
      ];

      for (final path in allMediaPaths) {
        try {
          await _client!.remove(path);
          debugPrint('Deleted media file: $path');
        } catch (e) {
          debugPrint('Error deleting media file $path: $e');
          // 继续删除其他文件，即使某个文件删除失败
        }
      }

      // 删除条目JSON文件
      await _client!.remove('growth_diary/entries/${entry.id}.json');
      debugPrint('Deleted entry: ${entry.id}');
    } catch (e) {
      debugPrint('Error deleting entry: $e');
      rethrow;
    }
  }

  bool get isInitialized => _client != null;
}
