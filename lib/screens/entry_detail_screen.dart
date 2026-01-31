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

  const EntryDetailScreen({
    super.key,
    required this.entry,
    required this.config,
    required this.cloudService,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  final Map<String, Uint8List?> _imageCache = {};
  final Map<String, bool> _loadingImages = {};
  final Map<String, Uint8List?> _videoThumbnailCache = {};
  final Map<String, bool> _loadingVideoThumbnails = {};

  @override
  void initState() {
    super.initState();
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
        ),
      ),
    );
  }

  String _getAgeDisplayText() {
    // 检查是否是孕期记录（在出生日期之前且配置了受孕日期）
    final isPregnancyPeriod = widget.config.conceptionDate != null &&
        widget.entry.date
            .isBefore(widget.config.childBirthDate ?? DateTime.now());

    if (isPregnancyPeriod) {
      // 孕期记录：显示孕周和天数
      final totalDays =
          widget.entry.date.difference(widget.config.conceptionDate!).inDays;
      final weeks = totalDays ~/ 7;
      final days = totalDays % 7;
      return '孕期 $weeks 周 $days 天';
    } else if (widget.config.childBirthDate != null &&
        widget.entry.date.isBefore(widget.config.childBirthDate!)) {
      // 出生前记录但未配置受孕日期：显示出生前 X 月 X 天
      final diff = widget.config.childBirthDate!.difference(widget.entry.date);
      final totalDays = diff.inDays;
      final months = totalDays ~/ 30; // 近似计算
      final days = totalDays % 30;
      return '出生前 $months 月 $days 天';
    } else {
      // 出生后记录：显示年龄
      return widget.entry.getAgeLabel(widget.config.childBirthDate);
    }
  }

  void _showFullScreenVideo(String videoPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenVideoPlayer(
          videoPath: videoPath,
          webdavService: widget.cloudService,
        ),
      ),
    );
  }

  Future<void> _editEntry() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.entry.date,
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

    if (pickedDate != null && pickedDate != widget.entry.date) {
      try {
        // 计算新的年龄月份
        final ageInMonths = widget.config.childBirthDate != null
            ? AgeCalculator.calculateAgeInMonths(
                widget.config.childBirthDate!, pickedDate)
            : 0;

        // 创建更新后的entry
        final updatedEntry = DiaryEntry(
          id: widget.entry.id,
          title: widget.entry.title,
          description: widget.entry.description,
          date: pickedDate,
          imagePaths: widget.entry.imagePaths,
          imageThumbnails: widget.entry.imageThumbnails,
          videoPaths: widget.entry.videoPaths,
          videoThumbnails: widget.entry.videoThumbnails,
          ageInMonths: ageInMonths,
        );

        // 保存到WebDAV
        await widget.cloudService.saveDiaryEntry(updatedEntry);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日期修改成功')),
        );
        // 返回上一页，让列表页面刷新
        Navigator.pop(context, updatedEntry);
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
            icon: const Icon(Icons.edit),
            onPressed: _editEntry,
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
                    Navigator.pop(context);
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
                        '${widget.entry.date.year}-${widget.entry.date.month.toString().padLeft(2, '0')}-${widget.entry.date.day.toString().padLeft(2, '0')}',
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
            if (widget.entry.title.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                widget.entry.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
            if (widget.entry.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                widget.entry.description,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
            if (widget.entry.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                '照片',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.entry.imagePaths.length} 张照片',
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
            if (widget.entry.videoPaths.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                '视频',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.entry.videoPaths.length} 个视频',
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
                itemCount: widget.entry.videoPaths.length,
                itemBuilder: (context, index) {
                  final path = widget.entry.videoPaths[index];
                  final thumbnailPath = widget.entry.videoThumbnails[index];
                  final thumbnail = _videoThumbnailCache[thumbnailPath];
                  final isLoading =
                      _loadingVideoThumbnails[thumbnailPath] ?? false;

                  return GestureDetector(
                    onTap: () => _showFullScreenVideo(path),
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
