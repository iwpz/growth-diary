import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class BatchVideoEditorScreen extends StatefulWidget {
  final List<String> videoPaths;
  final List<DateTime> originalDates;

  const BatchVideoEditorScreen({
    super.key,
    required this.videoPaths,
    required this.originalDates,
  });

  @override
  State<BatchVideoEditorScreen> createState() => _BatchVideoEditorScreenState();
}

class _BatchVideoEditorScreenState extends State<BatchVideoEditorScreen> {
  final Trimmer _trimmer = Trimmer();
  int _currentIndex = 0;
  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _isPlaying = false;
  bool _progressVisibility = false;

  // 存储每个视频的编辑状态
  final List<Map<String, dynamic>> _videoStates = [];

  // 存储视频缩略图
  final List<String?> _thumbnails = [];

  @override
  void initState() {
    super.initState();
    // 初始化每个视频的状态和缩略图
    for (int i = 0; i < widget.videoPaths.length; i++) {
      _videoStates.add({
        'isEdited': false,
        'startValue': 0.0,
        'endValue': 0.0,
        'trimmedPath': null,
      });
      _thumbnails.add(null);
    }

    // 异步生成缩略图
    _generateThumbnails();

    _loadCurrentVideo();
  }

  Future<void> _generateThumbnails() async {
    for (int i = 0; i < widget.videoPaths.length; i++) {
      try {
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: widget.videoPaths[i],
          thumbnailPath: (await getTemporaryDirectory()).path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 200,
          quality: 75,
        );

        if (mounted) {
          setState(() {
            _thumbnails[i] = thumbnailPath;
          });
        }
      } catch (e) {
        // 生成缩略图失败，使用默认占位符
        debugPrint('生成视频缩略图失败: $e');
      }
    }
  }

  void _loadCurrentVideo() async {
    await _trimmer.loadVideo(videoFile: File(widget.videoPaths[_currentIndex]));
    // 恢复之前保存的状态
    final state = _videoStates[_currentIndex];
    setState(() {
      _startValue = state['startValue'];
      _endValue = state['endValue'];
    });
  }

  @override
  void dispose() {
    _trimmer.dispose();

    // 清理所有缩略图文件
    for (final thumbnailPath in _thumbnails) {
      if (thumbnailPath != null) {
        try {
          File(thumbnailPath).deleteSync();
        } catch (e) {
          // 忽略删除失败的错误
        }
      }
    }

    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _saveCurrentVideo() async {
    setState(() {
      _progressVisibility = true;
    });

    try {
      _trimmer.saveTrimmedVideo(
        startValue: _startValue,
        endValue: _endValue,
        onSave: (String? trimmedPath) {
          if (trimmedPath != null) {
            // 保留原始文件的创建时间
            final originalFile = File(widget.videoPaths[_currentIndex]);
            final trimmedFile = File(trimmedPath);

            // 复制文件的修改时间
            final originalStat = originalFile.statSync();
            trimmedFile.setLastModifiedSync(originalStat.modified);

            // 保存编辑状态
            _videoStates[_currentIndex]['isEdited'] = true;
            _videoStates[_currentIndex]['trimmedPath'] = trimmedPath;
          }
          setState(() {
            _progressVisibility = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _progressVisibility = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频剪辑失败: $e')),
        );
      }
    }
  }

  void _switchToVideo(int index) async {
    if (index == _currentIndex) return;

    // 保存当前视频的状态
    _videoStates[_currentIndex]['startValue'] = _startValue;
    _videoStates[_currentIndex]['endValue'] = _endValue;

    setState(() {
      _currentIndex = index;
    });

    _loadCurrentVideo();
  }

  void _removeVideo(int index) {
    if (widget.videoPaths.length <= 1) {
      // 如果只剩一个视频，不允许移除
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需要保留一个视频')),
      );
      return;
    }

    setState(() {
      // 删除缩略图文件
      if (_thumbnails[index] != null) {
        try {
          File(_thumbnails[index]!).deleteSync();
        } catch (e) {
          // 忽略删除失败的错误
        }
      }

      widget.videoPaths.removeAt(index);
      widget.originalDates.removeAt(index);
      _videoStates.removeAt(index);
      _thumbnails.removeAt(index);

      // 调整当前索引
      if (_currentIndex >= index && _currentIndex > 0) {
        _currentIndex--;
      }

      // 重新加载当前视频
      _loadCurrentVideo();
    });
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃编辑'),
        content: const Text('确定要放弃所有视频编辑吗？未保存的更改将会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _finishEditing() {
    // 收集所有编辑结果
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.videoPaths.length; i++) {
      final state = _videoStates[i];
      if (state['isEdited'] && state['trimmedPath'] != null) {
        results.add({
          'path': state['trimmedPath'],
          'originalDate': widget.originalDates[i],
        });
      } else {
        results.add({
          'path': widget.videoPaths[i],
          'originalDate': widget.originalDates[i],
        });
      }
    }

    Navigator.of(context).pop(results);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop || !mounted) return;

        final shouldPop = await _onWillPop();
        if (shouldPop) {
          // 返回取消信号
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop(null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title:
              Text('编辑视频 (${_currentIndex + 1}/${widget.videoPaths.length})'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (!mounted) return;

              final shouldPop = await _onWillPop();
              if (shouldPop) {
                // 返回取消信号
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop(null);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (!mounted) return;

                final shouldPop = await _onWillPop();
                if (shouldPop) {
                  // 返回取消信号
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop(null);
                }
              },
              child: Text(
                '放弃',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
            TextButton(
              onPressed: _finishEditing,
              child: Text(
                '完成',
                style: TextStyle(
                  color: Colors.pink.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // 视频播放器
            Expanded(
              flex: 2,
              child: VideoViewer(trimmer: _trimmer),
            ),

            // 进度条和控制
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // 进度条
                  TrimViewer(
                    trimmer: _trimmer,
                    viewerHeight: 50,
                    viewerWidth: MediaQuery.of(context).size.width,
                    maxVideoLength: const Duration(seconds: 10),
                    onChangeStart: (value) =>
                        setState(() => _startValue = value),
                    onChangeEnd: (value) => setState(() => _endValue = value),
                    onChangePlaybackState: (value) =>
                        setState(() => _isPlaying = value),
                  ),

                  // 时间显示
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(
                          Duration(seconds: _startValue.toInt()))),
                      Text(_formatDuration(
                          Duration(seconds: _endValue.toInt()))),
                    ],
                  ),

                  // 控制按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: () async {
                          final playbackState =
                              await _trimmer.videoPlaybackControl(
                            startValue: _startValue,
                            endValue: _endValue,
                          );
                          setState(() => _isPlaying = playbackState);
                        },
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _saveCurrentVideo,
                        child: const Text('应用剪辑'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 视频列表
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.videoPaths.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentIndex;
                  final isEdited = _videoStates[index]['isEdited'];

                  return Container(
                    width: 100,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        // 视频缩略图
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                            image: _thumbnails[index] != null
                                ? DecorationImage(
                                    image: FileImage(File(_thumbnails[index]!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _thumbnails[index] == null
                              ? const Center(
                                  child: Icon(Icons.video_file, size: 32),
                                )
                              : null,
                        ),

                        // 编辑状态指示器
                        if (isEdited)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),

                        // 点击切换视频
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => _switchToVideo(index),
                            ),
                          ),
                        ),

                        // 移除按钮
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _removeVideo(index),
                            color: Colors.red,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 进度指示器
            if (_progressVisibility) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
