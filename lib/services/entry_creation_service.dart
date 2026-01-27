import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:exif/exif.dart';
import '../models/app_config.dart';
import '../models/diary_entry.dart';
import '../services/webdav_service.dart';
import '../utils/age_calculator.dart';

class EntryCreationService {
  final WebDAVService webdavService;

  EntryCreationService(this.webdavService);

  DateTime _parseExifDate(String exifDate) {
    // EXIF日期格式: "YYYY:MM:DD HH:MM:SS"
    final parts = exifDate.split(' ');
    if (parts.length == 2) {
      final dateParts = parts[0].split(':');
      final timeParts = parts[1].split(':');
      if (dateParts.length == 3 && timeParts.length == 3) {
        return DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
          int.parse(timeParts[2]),
        );
      }
    }
    // 如果解析失败，返回当前时间
    return DateTime.now();
  }

  int _calculateAgeInMonths(DateTime date, AppConfig config) {
    final birthDate = config.childBirthDate!;
    return AgeCalculator.calculateAgeInMonths(birthDate, date);
  }

  Future<DiaryEntry> createMediaEntry(
      List<XFile> media, String description, AppConfig config) async {
    // 分离图片和视频
    final List<XFile> images = media
        .where((file) => file.mimeType?.startsWith('image/') ?? false)
        .toList();
    final List<XFile> videos = media
        .where((file) => file.mimeType?.startsWith('video/') ?? false)
        .toList();

    // 确定记录日期
    DateTime date = DateTime.now();
    if (images.isNotEmpty) {
      // 使用第一张图片的EXIF拍摄日期或创建日期作为记录日期
      final firstImage = File(images.first.path);
      try {
        final exifData =
            await readExifFromBytes(await firstImage.readAsBytes());
        final dateTimeOriginal = exifData['EXIF DateTimeOriginal'];
        final imageDateTime = exifData['Image DateTime'];
        if (dateTimeOriginal != null) {
          date = _parseExifDate(dateTimeOriginal.toString());
        } else if (imageDateTime != null) {
          date = _parseExifDate(imageDateTime.toString());
        } else {
          final stat = await firstImage.stat();
          date = stat.changed;
        }
      } catch (e) {
        final stat = await firstImage.stat();
        date = stat.changed;
      }
    } else if (videos.isNotEmpty) {
      // 使用第一个视频的文件修改日期
      final firstVideo = File(videos.first.path);
      final stat = await firstVideo.stat();
      date = stat.changed;
    }

    // 上传图片
    final List<String> imagePaths = [];
    final List<String> imageThumbnails = [];
    for (var xfile in images) {
      final file = File(xfile.path);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final paths =
          await webdavService.uploadImageWithThumbnails(file, fileName);
      final pathList = paths.split('|');
      if (pathList.length >= 3) {
        imagePaths.add(pathList[0]); // 原图
        imageThumbnails.add(pathList[2]); // 小号缩略图
      } else {
        imagePaths.add(paths);
        imageThumbnails.add(paths); // 如果没有缩略图，使用原图
      }
    }

    // 上传视频
    final List<String> videoPaths = [];
    final List<String> videoThumbnails = [];
    for (var xfile in videos) {
      final file = File(xfile.path);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final paths =
          await webdavService.uploadVideoWithThumbnails(file, fileName);
      final pathList = paths.split('|');
      final uploadedPath = pathList[0];
      final thumbnailPath = pathList.length >= 3 ? pathList[2] : paths;
      videoPaths.add(uploadedPath);
      videoThumbnails.add(thumbnailPath);
    }

    // 生成标题
    String title = description;
    if (title.isEmpty) {
      if (images.isNotEmpty && videos.isNotEmpty) {
        title = '图片和视频记录';
      } else if (images.isNotEmpty) {
        title = '图片记录';
      } else if (videos.isNotEmpty) {
        title = '视频记录';
      }
    }

    final entry = DiaryEntry(
      id: null,
      date: date,
      title: title,
      description: description,
      imagePaths: imagePaths,
      videoPaths: videoPaths,
      imageThumbnails: imageThumbnails,
      videoThumbnails: videoThumbnails,
      ageInMonths: _calculateAgeInMonths(date, config),
    );

    await webdavService.saveDiaryEntry(entry);

    return entry;
  }

  Future<DiaryEntry> createTextEntry(String text, AppConfig config) async {
    final date = DateTime.now();

    final entry = DiaryEntry(
      id: null,
      date: date,
      title: text,
      description: '',
      imagePaths: [],
      videoPaths: [],
      ageInMonths: _calculateAgeInMonths(date, config),
    );

    await webdavService.saveDiaryEntry(entry);

    return entry;
  }
}
