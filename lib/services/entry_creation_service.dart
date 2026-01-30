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

  Future<List<DiaryEntry>> createImageEntry(
      List<XFile> images, String description, AppConfig config,
      [UploadProgressCallback? onProgress, DateTime? overrideDate]) async {
    if (images.isEmpty) return [];

    // 如果指定了overrideDate，所有图片都使用这个日期
    if (overrideDate != null) {
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

      final entry = DiaryEntry(
        id: overrideDate.millisecondsSinceEpoch.toString(),
        date: overrideDate,
        title: description,
        description: description,
        imagePaths: imagePaths,
        videoPaths: [],
        imageThumbnails: imageThumbnails,
        videoThumbnails: [],
        ageInMonths: _calculateAgeInMonths(overrideDate, config),
      );

      await webdavService.saveDiaryEntry(entry);
      return [entry];
    }

    // 按日期分组图片
    final Map<String, List<Map<String, dynamic>>> dateGroups = {};

    for (var i = 0; i < images.length; i++) {
      final xfile = images[i];
      final file = File(xfile.path);

      // 提取图片日期
      DateTime imageDate = DateTime.now();
      try {
        final exifData = await readExifFromBytes(await file.readAsBytes());
        final dateTimeOriginal = exifData['EXIF DateTimeOriginal'];
        final imageDateTime = exifData['Image DateTime'];
        if (dateTimeOriginal != null) {
          imageDate = _parseExifDate(dateTimeOriginal.toString());
        } else if (imageDateTime != null) {
          imageDate = _parseExifDate(imageDateTime.toString());
        } else {
          final stat = await file.stat();
          imageDate = stat.changed;
        }
      } catch (e) {
        final stat = await file.stat();
        imageDate = stat.changed;
      }

      // 使用日期的YYYY-MM-DD格式作为分组键
      final dateKey =
          '${imageDate.year}-${imageDate.month.toString().padLeft(2, '0')}-${imageDate.day.toString().padLeft(2, '0')}';

      if (!dateGroups.containsKey(dateKey)) {
        dateGroups[dateKey] = [];
      }

      dateGroups[dateKey]!.add({
        'file': file,
        'date': imageDate,
        'index': i,
      });
    }

    // 为每个日期组创建entry
    final List<DiaryEntry> entries = [];
    int totalProcessed = 0;

    for (final dateKey in dateGroups.keys) {
      final imageDataList = dateGroups[dateKey]!;
      final List<String> imagePaths = [];
      final List<String> imageThumbnails = [];

      // 使用该组第一张图片的日期作为entry日期
      final entryDate = imageDataList.first['date'] as DateTime;
      final photoTimestampId = entryDate.millisecondsSinceEpoch.toString();

      // 上传该组的所有图片
      for (final imageData in imageDataList) {
        final file = imageData['file'] as File;
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

        totalProcessed++;
        onProgress?.call(totalProcessed, images.length);
      }

      final entry = DiaryEntry(
        id: photoTimestampId,
        date: entryDate,
        title: description,
        description: description,
        imagePaths: imagePaths,
        videoPaths: [],
        imageThumbnails: imageThumbnails,
        videoThumbnails: [],
        ageInMonths: _calculateAgeInMonths(entryDate, config),
      );

      await webdavService.saveDiaryEntry(entry);
      entries.add(entry);
    }

    return entries;
  }

  Future<List<DiaryEntry>> createVideoEntry(
      XFile video, String description, AppConfig config,
      [UploadProgressCallback? onProgress, DateTime? overrideDate]) async {
    // 确定记录日期
    DateTime date = DateTime.now();
    String? videoTimestampId;
    final videoFile = File(video.path);
    final stat = await videoFile.stat();
    if (overrideDate != null) {
      date = overrideDate;
      videoTimestampId = date.millisecondsSinceEpoch.toString();
    } else {
      date = stat.changed;
      videoTimestampId = stat.changed.millisecondsSinceEpoch.toString();
    }

    // 上传视频
    final fileName = _generateFileName(videoFile, stat);
    final paths =
        await webdavService.uploadVideoWithThumbnails(videoFile, fileName);
    final pathList = paths.split('|');
    final uploadedPath = pathList[0];
    final thumbnailPath = pathList.length >= 3 ? pathList[2] : paths;

    onProgress?.call(1, 1);

    final entry = DiaryEntry(
      id: videoTimestampId,
      date: date,
      title: description,
      description: description,
      imagePaths: [],
      videoPaths: [uploadedPath],
      imageThumbnails: [],
      videoThumbnails: [thumbnailPath],
      ageInMonths: _calculateAgeInMonths(date, config),
    );

    await webdavService.saveDiaryEntry(entry);

    return [entry];
  }

  Future<DiaryEntry> createDiaryEntry(
      String title, String content, AppConfig config,
      {DateTime? customDate}) async {
    final date = customDate ?? DateTime.now();
    final publicationTime = DateTime.now();

    // 如果有自定义日期，使用自定义日期 + 发布时间戳作为ID
    // 否则只使用发布时间戳
    final id = customDate != null
        ? '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${publicationTime.millisecondsSinceEpoch}'
        : publicationTime.millisecondsSinceEpoch.toString();

    final entry = DiaryEntry(
      id: id,
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
