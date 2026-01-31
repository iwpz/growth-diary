import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:media_store_plus/media_store_plus.dart';
import '../services/cloud_storage_service.dart';

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

  Future<void> _shareVideo() async {
    try {
      final tempFile = await widget.webdavService
          .saveToTempFile(widget.videoPath, null); // 视频文件应该已经存在于临时目录中
      if (tempFile != null) {
        await Share.shareXFiles([XFile(tempFile.path)]);
      }
    } catch (e) {
      debugPrint('Error sharing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享视频失败')),
        );
      }
    }
  }

  Future<void> _downloadVideo() async {
    try {
      final videoData =
          await widget.webdavService.downloadMedia(widget.videoPath);
      if (videoData != null) {
        await MediaStore.ensureInitialized();
        final mediaStore = MediaStore();

        // 设置应用文件夹为 Growth Diary
        MediaStore.appFolder = 'Growth Diary';

        final fileName = widget.videoPath.split('/').last;

        // 保存视频到下载目录的 Growth Diary 文件夹
        final result = await mediaStore.saveFile(
          tempFilePath: await _saveVideoToTempFile(videoData),
          dirType: DirType.download,
          dirName: DirName.download,
        );

        if (result != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('视频已保存到下载目录: Growth Diary/$fileName')),
          );
        } else {
          throw Exception('保存失败');
        }
      }
    } catch (e) {
      debugPrint('Error downloading video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存视频失败，请检查存储权限')),
        );
      }
    }
  }

  Future<String> _saveVideoToTempFile(Uint8List data) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_video.mp4');
    await tempFile.writeAsBytes(data);
    return tempFile.path;
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
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: _shareVideo,
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: _downloadVideo,
                      ),
                    ],
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
