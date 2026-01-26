import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:exif/exif.dart';
import '../models/app_config.dart';
import '../models/diary_entry.dart';
import '../services/webdav_service.dart';
import '../utils/age_calculator.dart';

class NewEntryScreen extends StatefulWidget {
  final AppConfig config;
  final WebDAVService webdavService;
  final DiaryEntry? existingEntry;

  const NewEntryScreen({
    super.key,
    required this.config,
    required this.webdavService,
    this.existingEntry,
  });

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // 编辑现有记录的功能暂时移除，因为新界面不支持
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

  int _calculateAgeInMonths(DateTime date) {
    final birthDate = widget.config.childBirthDate!;
    return AgeCalculator.calculateAgeInMonths(birthDate, date);
  }

  Future<String?> _showDescriptionDialog() async {
    String description = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加描述（可选）'),
        content: TextField(
          onChanged: (value) => description = value,
          decoration: const InputDecoration(hintText: '请输入描述'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(description),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showTextDialog() async {
    String text = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入文本记录'),
        content: TextField(
          onChanged: (value) => text = value,
          decoration: const InputDecoration(hintText: '请输入文本'),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _addImageEntry() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isEmpty) return;

      final String? description = await _showDescriptionDialog();
      if (description == null) return;

      setState(() => _isLoading = true);

      // 使用第一张图片的EXIF拍摄日期或创建日期作为记录日期
      final firstImage = File(images.first.path);
      DateTime date;
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

      final List<String> imagePaths = [];
      final List<String> imageThumbnails = [];
      for (var xfile in images) {
        final file = File(xfile.path);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
        final paths = await widget.webdavService
            .uploadImageWithThumbnails(file, fileName);
        final pathList = paths.split('|');
        if (pathList.length >= 3) {
          imagePaths.add(pathList[0]); // 原图
          imageThumbnails.add(pathList[2]); // 小号缩略图
        } else {
          imagePaths.add(paths);
          imageThumbnails.add(paths); // 如果没有缩略图，使用原图
        }
      }

      final entry = DiaryEntry(
        id: null,
        date: date,
        title: description.isNotEmpty ? description : '图片记录',
        description: description,
        imagePaths: imagePaths,
        videoPaths: [],
        imageThumbnails: imageThumbnails,
        videoThumbnails: [],
        ageInMonths: _calculateAgeInMonths(date),
      );

      await widget.webdavService.saveDiaryEntry(entry);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加图片记录失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addVideoEntry() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      final String? description = await _showDescriptionDialog();
      if (description == null) return;

      setState(() => _isLoading = true);

      final file = File(video.path);
      final stat = await file.stat();
      final date = stat.changed;

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final paths =
          await widget.webdavService.uploadVideoWithThumbnails(file, fileName);
      final pathList = paths.split('|');
      final uploadedPath = pathList[0];
      final thumbnailPath = pathList.length >= 3 ? pathList[2] : paths;

      final entry = DiaryEntry(
        id: null,
        date: date,
        title: description.isNotEmpty ? description : '视频记录',
        description: description,
        imagePaths: [],
        videoPaths: [uploadedPath],
        imageThumbnails: [],
        videoThumbnails: [thumbnailPath],
        ageInMonths: _calculateAgeInMonths(date),
      );

      await widget.webdavService.saveDiaryEntry(entry);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加视频记录失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addTextEntry() async {
    try {
      final String? text = await _showTextDialog();
      if (text == null || text.isEmpty) return;

      setState(() => _isLoading = true);

      final date = DateTime.now();

      final entry = DiaryEntry(
        id: null,
        date: date,
        title: text,
        description: '',
        imagePaths: [],
        videoPaths: [],
        ageInMonths: _calculateAgeInMonths(date),
      );

      await widget.webdavService.saveDiaryEntry(entry);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加文本记录失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建记录'),
        backgroundColor: Colors.pink.shade100,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _addImageEntry,
                    icon: const Icon(Icons.photo),
                    label: const Text('添加图片'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade50,
                      foregroundColor: Colors.pink.shade700,
                      minimumSize: const Size(double.infinity, 60),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addVideoEntry,
                    icon: const Icon(Icons.videocam),
                    label: const Text('添加视频'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade50,
                      foregroundColor: Colors.purple.shade700,
                      minimumSize: const Size(double.infinity, 60),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addTextEntry,
                    icon: const Icon(Icons.text_fields),
                    label: const Text('添加文本'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      minimumSize: const Size(double.infinity, 60),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
