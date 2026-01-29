import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:exif/exif.dart';
import 'package:crypto/crypto.dart';
import '../models/app_config.dart';
import '../models/diary_entry.dart';
import '../services/webdav_service.dart';
import '../utils/age_calculator.dart';

typedef UploadProgressCallback = void Function(int uploaded, int total);

class EntryCreationService {
  final WebDAVService webdavService;

  EntryCreationService(this.webdavService);

  String _generateFileName(File file, FileStat stat) {
    final extension = path.extension(file.path);
    final isLargeVideo = stat.size > 10 * 1024 * 1024; // 10MB

    final bytes = file.readAsBytesSync();
    Digest hash;

    if (isLargeVideo) {
      // 对于大视频，取前1MB内容 + 文件大小 + 修改时间
      final prefix =
          bytes.length > 1024 * 1024 ? bytes.sublist(0, 1024 * 1024) : bytes;
      final sizeStr = stat.size.toString();
      final mtimeStr = stat.modified.millisecondsSinceEpoch.toString();
      final combined = prefix + sizeStr.codeUnits + mtimeStr.codeUnits;
      hash = sha256.convert(combined);
    } else {
      // 对于其他文件，使用整个文件的SHA256
      hash = sha256.convert(bytes);
    }

    return '${hash.toString()}$extension';
  }

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

  Future<DiaryEntry> createImageEntry(
      List<XFile> images, String description, AppConfig config,
      [UploadProgressCallback? onProgress, DateTime? overrideDate]) async {
    // 确定记录日期
    DateTime date = DateTime.now();
    if (overrideDate != null) {
      date = overrideDate;
    } else if (images.isNotEmpty) {
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
    }

    // 上传图片
    final List<String> imagePaths = [];
    final List<String> imageThumbnails = [];
    for (var i = 0; i < images.length; i++) {
      final xfile = images[i];
      final file = File(xfile.path);
      final stat = await file.stat();
      final fileName = _generateFileName(file, stat);
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
      onProgress?.call(i + 1, images.length);
    }

    // 生成标题
    String title = description;

    final entry = DiaryEntry(
      id: null,
      date: date,
      title: title,
      description: description,
      imagePaths: imagePaths,
      videoPaths: [],
      imageThumbnails: imageThumbnails,
      videoThumbnails: [],
      ageInMonths: _calculateAgeInMonths(date, config),
    );

    await webdavService.saveDiaryEntry(entry);

    return entry;
  }

  Future<DiaryEntry> createVideoEntry(
      XFile video, String description, AppConfig config,
      [UploadProgressCallback? onProgress, DateTime? overrideDate]) async {
    // 确定记录日期
    DateTime date = DateTime.now();
    final videoFile = File(video.path);
    final stat = await videoFile.stat();
    if (overrideDate != null) {
      date = overrideDate;
    } else {
      date = stat.changed;
    }

    // 上传视频
    final fileName = _generateFileName(videoFile, stat);
    final paths =
        await webdavService.uploadVideoWithThumbnails(videoFile, fileName);
    final pathList = paths.split('|');
    final uploadedPath = pathList[0];
    final thumbnailPath = pathList.length >= 3 ? pathList[2] : paths;

    onProgress?.call(1, 1);

    // 生成标题
    String title = description;

    final entry = DiaryEntry(
      id: null,
      date: date,
      title: title,
      description: description,
      imagePaths: [],
      videoPaths: [uploadedPath],
      imageThumbnails: [],
      videoThumbnails: [thumbnailPath],
      ageInMonths: _calculateAgeInMonths(date, config),
    );

    await webdavService.saveDiaryEntry(entry);

    return entry;
  }

  Future<DiaryEntry> createDiaryEntry(
      String title, String content, AppConfig config) async {
    final date = DateTime.now();

    final entry = DiaryEntry(
      id: null,
      date: date,
      title: title,
      description: content,
      imagePaths: [],
      videoPaths: [],
      ageInMonths: _calculateAgeInMonths(date, config),
    );

    await webdavService.saveDiaryEntry(entry);

    return entry;
  }
}
