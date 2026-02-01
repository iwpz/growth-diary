import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/diary_entry.dart';
import '../models/app_config.dart';
import '../services/cloud_storage_service.dart';
import '../utils/age_calculator.dart';
import '../components/full_screen_image_view.dart';
import '../components/full_screen_video_player.dart';

class EntryDetailScreen extends StatefulWidget {
  final DiaryEntry entry;
  final AppConfig config;
  final CloudStorageService cloudService;
  final void Function(EntryDetailResult, DiaryEntry)? onEntryUpdated;
  final void Function(AppConfig)? onConfigChanged;

  const EntryDetailScreen({
    super.key,
    required this.entry,
    required this.config,
    required this.cloudService,
    this.onEntryUpdated,
    this.onConfigChanged,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late DiaryEntry _currentEntry;
  final Map<String, Uint8List?> _imageCache = {};
  final Map<String, bool> _loadingImages = {};
  final Map<String, Uint8List?> _videoThumbnailCache = {};
  final Map<String, bool> _loadingVideoThumbnails = {};

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
    _loadImages();
    _loadVideoThumbnails();
  }

  Future<void> _loadImages() async {
    for (var path in widget.entry.imageThumbnails) {
      if (!_imageCache.containsKey(path)) {
        setState(() {
          _loadingImages[path] = true;
        });
        try {
          final data = await widget.cloudService.downloadMedia(path);
          if (data != null && mounted) {
            setState(() {
              _imageCache[path] = data;
              _loadingImages[path] = false;
            });
          }
        } catch (e) {
          debugPrint('Error loading image thumbnail $path: $e');
          if (mounted) {
            setState(() {
              _loadingImages[path] = false;
            });
          }
        }
      }
    }
  }

  Future<void> _loadVideoThumbnails() async {
    for (var path in widget.entry.videoThumbnails) {
      if (!_videoThumbnailCache.containsKey(path)) {
        setState(() {
          _loadingVideoThumbnails[path] = true;
        });
        try {
          final data = await widget.cloudService.downloadMedia(path);
          if (data != null && mounted) {
            setState(() {
              _videoThumbnailCache[path] = data;
              _loadingVideoThumbnails[path] = false;
            });
          }
        } catch (e) {
          debugPrint('Error loading video thumbnail $path: $e');
          if (mounted) {
            setState(() {
              _loadingVideoThumbnails[path] = false;
            });
          }
        }
      }
    }
  }

  void _showFullScreenImage(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(
          imagePaths: widget.entry.imagePaths,
          webdavService: widget.cloudService,
          initialIndex: initialIndex,
          onSetAsCoverImage:
              widget.onConfigChanged != null ? _setAsCoverImage : null,
        ),
      ),
    );
  }

  void _setAsCoverImage(String imagePath) {
    final updatedConfig = widget.config.copyWith(babyCoverImagePath: imagePath);
    widget.onConfigChanged!(updatedConfig);
  }

  String _getAgeDisplayText() {
    // 检查是否是孕期记录（在出生日期之前且配置了受孕日期）
    final isPregnancyPeriod = widget.config.conceptionDate != null &&
        _currentEntry.date
            .isBefore(widget.config.childBirthDate ?? DateTime.now());

    if (isPregnancyPeriod) {
      // 孕期记录：显示孕周和天数
      final totalDays =
          _currentEntry.date.difference(widget.config.conceptionDate!).inDays;
      final weeks = totalDays ~/ 7;
      final days = totalDays % 7;
      return '孕期 $weeks 周 $days 天';
    } else if (widget.config.childBirthDate != null &&
        _currentEntry.date.isBefore(widget.config.childBirthDate!)) {
      // 出生前记录但未配置受孕日期：显示出生前 X 月 X 天
      final diff = widget.config.childBirthDate!.difference(_currentEntry.date);
      final totalDays = diff.inDays;
      final months = totalDays ~/ 30; // 近似计算
      final days = totalDays % 30;
      return '出生前 $months 月 $days 天';
    } else {
      // 出生后记录：显示年龄
      return _currentEntry.getAgeLabel(widget.config);
    }
  }

  void _showFullScreenVideo(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenVideoPlayer(
          videoPaths: _currentEntry.videoPaths,
          webdavService: widget.cloudService,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _editDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _currentEntry.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.pink,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _currentEntry.date) {
      try {
        // 计算新的年龄月份
        final ageInMonths = widget.config.childBirthDate != null
            ? AgeCalculator.calculateAgeInMonths(
                widget.config.childBirthDate!, pickedDate)
            : 0;

        // 创建更新后的entry
        final updatedEntry = DiaryEntry(
          id: _currentEntry.id,
          title: _currentEntry.title,
          description: _currentEntry.description,
          date: pickedDate,
          imagePaths: _currentEntry.imagePaths,
          imageThumbnails: _currentEntry.imageThumbnails,
          videoPaths: _currentEntry.videoPaths,
          videoThumbnails: _currentEntry.videoThumbnails,
          ageInMonths: ageInMonths,
        );

        // 保存到WebDAV
        await widget.cloudService.saveDiaryEntry(updatedEntry);

        if (!mounted) return;

        // 更新当前状态
        setState(() {
          _currentEntry = updatedEntry;
        });

        // 通知首页有更新
        widget.onEntryUpdated
            ?.call(EntryDetailResult.updated(updatedEntry), widget.entry);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日期修改成功')),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修改失败: $e')),
        );
      }
    }
  }

  Future<void> _editDescription() async {
    final TextEditingController controller =
        TextEditingController(text: _currentEntry.description);

    final String? newDescription = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑描述'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '输入描述...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (newDescription != null && newDescription != _currentEntry.description) {
      try {
        // 创建更新后的entry
        final updatedEntry = DiaryEntry(
          id: _currentEntry.id,
          title: _currentEntry.title,
          description: newDescription,
          date: _currentEntry.date,
          imagePaths: _currentEntry.imagePaths,
          imageThumbnails: _currentEntry.imageThumbnails,
          videoPaths: _currentEntry.videoPaths,
          videoThumbnails: _currentEntry.videoThumbnails,
          ageInMonths: _currentEntry.ageInMonths,
        );

        // 保存到WebDAV
        await widget.cloudService.saveDiaryEntry(updatedEntry);

        if (!mounted) return;

        // 更新当前状态
        setState(() {
          _currentEntry = updatedEntry;
        });

        // 通知首页有更新
        widget.onEntryUpdated
            ?.call(EntryDetailResult.updated(updatedEntry), widget.entry);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('描述修改成功')),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修改失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _editDate,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editDescription,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认删除'),
                  content: const Text('确定要删除这条记录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child:
                          const Text('删除', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await widget.cloudService.deleteEntry(widget.entry);
                  if (context.mounted) {
                    Navigator.pop(context, EntryDetailResult.deleted());
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('删除失败: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getAgeDisplayText(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_currentEntry.date.year}-${_currentEntry.date.month.toString().padLeft(2, '0')}-${_currentEntry.date.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.child_care,
                    size: 60,
                    color: Colors.pink.shade200,
                  ),
                ],
              ),
            ),
            if (_currentEntry.title.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                _currentEntry.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
            if (_currentEntry.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                _currentEntry.description,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
            if (_currentEntry.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '${_currentEntry.imagePaths.length} 张照片',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: widget.entry.imagePaths.length,
                itemBuilder: (context, index) {
                  final thumbnailPath = widget.entry.imageThumbnails[index];
                  final imageData = _imageCache[thumbnailPath];
                  final isLoading = _loadingImages[thumbnailPath] ?? false;

                  return GestureDetector(
                    onTap: () => _showFullScreenImage(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : imageData != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    imageData,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                    ),
                  );
                },
              ),
            ],
            if (_currentEntry.videoPaths.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '${_currentEntry.videoPaths.length} 个视频',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _currentEntry.videoPaths.length,
                itemBuilder: (context, index) {
                  final thumbnailPath = _currentEntry.videoThumbnails[index];
                  final thumbnail = _videoThumbnailCache[thumbnailPath];
                  final isLoading =
                      _loadingVideoThumbnails[thumbnailPath] ?? false;

                  return GestureDetector(
                    onTap: () => _showFullScreenVideo(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          // 缩略图
                          Positioned.fill(
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : thumbnail != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          thumbnail,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.videocam,
                                          size: 40,
                                          color: Colors.purple,
                                        ),
                                      ),
                          ),
                          // 视频播放图标覆盖层
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
