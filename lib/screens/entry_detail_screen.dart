import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../models/diary_entry.dart';
import '../models/app_config.dart';
import '../services/cloud_storage_service.dart';
import '../utils/age_calculator.dart';

class EntryDetailScreen extends StatefulWidget {
  final DiaryEntry entry;
  final AppConfig config;
  final CloudStorageService webdavService;

  const EntryDetailScreen({
    super.key,
    required this.entry,
    required this.config,
    required this.webdavService,
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
          final data = await widget.webdavService.downloadMedia(path);
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
          final data = await widget.webdavService.downloadMedia(path);
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
          webdavService: widget.webdavService,
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
          webdavService: widget.webdavService,
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
        await widget.webdavService.saveDiaryEntry(updatedEntry);

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
                  await widget.webdavService.deleteEntry(widget.entry);
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

class FullScreenImageView extends StatefulWidget {
  final List<String> imagePaths;
  final CloudStorageService webdavService;
  final int initialIndex;

  const FullScreenImageView({
    super.key,
    required this.imagePaths,
    required this.webdavService,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, Uint8List?> _fullImageCache = {};
  final Map<int, bool> _loadingFullImages = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadFullImage(widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFullImage(int index) async {
    if (index < 0 || index >= widget.imagePaths.length) return;

    if (!_fullImageCache.containsKey(index)) {
      setState(() {
        _loadingFullImages[index] = true;
      });
      try {
        final data =
            await widget.webdavService.downloadMedia(widget.imagePaths[index]);
        if (data != null && mounted) {
          setState(() {
            _fullImageCache[index] = data;
            _loadingFullImages[index] = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading full image ${widget.imagePaths[index]}: $e');
        if (mounted) {
          setState(() {
            _loadingFullImages[index] = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.imagePaths.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          _loadFullImage(index);
        },
        itemCount: widget.imagePaths.length,
        itemBuilder: (context, index) {
          final imageData = _fullImageCache[index];
          final isLoading = _loadingFullImages[index] ?? false;

          if (isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          } else if (imageData != null) {
            return InteractiveViewer(
              child: Center(
                child: Image.memory(
                  imageData,
                  fit: BoxFit.contain,
                ),
              ),
            );
          } else {
            return const Center(
              child: Icon(
                Icons.image,
                color: Colors.white,
                size: 100,
              ),
            );
          }
        },
      ),
    );
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoPath;
  final CloudStorageService webdavService;

  const FullScreenVideoPlayer({
    super.key,
    required this.videoPath,
    required this.webdavService,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 从WebDAV下载视频数据
      final videoData =
          await widget.webdavService.downloadMedia(widget.videoPath);
      if (videoData == null) {
        throw Exception('无法下载视频文件');
      }

      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_video.mp4');
      await tempFile.writeAsBytes(videoData);

      // 创建视频控制器
      _controller = VideoPlayerController.file(tempFile);

      // 初始化控制器
      await _controller!.initialize();

      // 设置循环播放
      _controller!.setLooping(true);

      // 监听播放状态变化
      _controller!.addListener(_onVideoStateChanged);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频加载失败: $e')),
        );
      }
    }
  }

  void _onVideoStateChanged() {
    if (!mounted) return;

    final wasPlaying = _isPlaying;
    _isPlaying = _controller!.value.isPlaying;

    // 如果播放状态发生变化，更新UI
    if (wasPlaying != _isPlaying) {
      setState(() {});
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 视频播放器
          if (_isInitialized && _controller != null)
            GestureDetector(
              onTap: _toggleControls,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            const Center(
              child: Icon(
                Icons.videocam_off,
                color: Colors.white,
                size: 100,
              ),
            ),

          // 控制层
          if (_showControls && _isInitialized && _controller != null)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Column(
                children: [
                  // 顶部栏
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    title: const Text(
                      '视频播放',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                  const Spacer(),

                  // 底部控制栏
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 进度条
                        VideoProgressIndicator(
                          _controller!,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.pink,
                            bufferedColor: Colors.white30,
                            backgroundColor: Colors.white12,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 时间和控制按钮
                        Row(
                          children: [
                            // 当前时间
                            Text(
                              _formatDuration(_controller!.value.position),
                              style: const TextStyle(color: Colors.white),
                            ),

                            const Spacer(),

                            // 播放/暂停按钮
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: _togglePlayPause,
                            ),

                            const Spacer(),

                            // 总时长
                            Text(
                              _formatDuration(_controller!.value.duration),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 加载中指示器
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
