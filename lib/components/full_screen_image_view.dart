import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_store_plus/media_store_plus.dart';
import '../services/cloud_storage_service.dart';

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

  Future<void> _shareImage() async {
    final imageData = _fullImageCache[_currentIndex];
    if (imageData != null) {
      try {
        final tempFile = await widget.webdavService
            .saveToTempFile(widget.imagePaths[_currentIndex], imageData);
        if (tempFile != null) {
          await Share.shareXFiles([XFile(tempFile.path)]);
        }
      } catch (e) {
        debugPrint('Error sharing image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('分享图片失败')),
          );
        }
      }
    }
  }

  Future<void> _downloadImage() async {
    final imageData = _fullImageCache[_currentIndex];
    if (imageData != null) {
      try {
        await MediaStore.ensureInitialized();
        final mediaStore = MediaStore();

        // 设置应用文件夹为 Growth Diary
        MediaStore.appFolder = 'Growth Diary';

        final fileName = widget.imagePaths[_currentIndex].split('/').last;

        // 保存图片到下载目录的 Growth Diary 文件夹
        final result = await mediaStore.saveFile(
          tempFilePath: await _saveImageToTempFile(imageData),
          dirType: DirType.download,
          dirName: DirName.download,
        );

        if (result != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('图片已保存到下载目录: Growth Diary/$fileName')),
          );
        } else {
          throw Exception('保存失败');
        }
      } catch (e) {
        debugPrint('Error downloading image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存图片失败，请检查存储权限')),
          );
        }
      }
    }
  }

  Future<String> _saveImageToTempFile(Uint8List data) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_image.jpg');
    await tempFile.writeAsBytes(data);
    return tempFile.path;
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
            icon: const Icon(Icons.share),
            onPressed: _shareImage,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadImage,
          ),
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
              panEnabled: true,
              scaleEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
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
