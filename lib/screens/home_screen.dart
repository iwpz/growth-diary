import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/app_config.dart';
import '../models/diary_entry.dart';
import '../services/webdav_service.dart';
import 'entry_detail_screen.dart';
import 'new_entry_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppConfig config;
  final WebDAVService webdavService;

  const HomeScreen({
    super.key,
    required this.config,
    required this.webdavService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DiaryEntry> _entries = [];
  bool _isLoading = true;
  final Map<String, Uint8List?> _thumbnailCache = {};
  final Map<String, Future<Uint8List?>> _thumbnailFutures = {};

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final entries = await widget.webdavService.loadAllEntries();
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.config.childName}的成长日记'),
        backgroundColor: Colors.pink.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    config: widget.config,
                    webdavService: widget.webdavService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmptyState()
              : _buildTimeline(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewEntryScreen(
                config: widget.config,
                webdavService: widget.webdavService,
              ),
            ),
          );
          if (result == true) {
            _loadEntries();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('新建记录'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.baby_changing_station,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            '还没有记录',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '点击右下角按钮添加第一条记录',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          final isFirst = index == 0;
          final isLast = index == _entries.length - 1;

          return _buildTimelineItem(entry, isFirst, isLast);
        },
      ),
    );
  }

  Widget _buildTimelineItem(DiaryEntry entry, bool isFirst, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.pink.shade100,
                border: Border.all(
                  color: Colors.pink,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  '${entry.ageInMonths}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 100, // 固定高度而不是 Expanded
                color: Colors.pink.shade200,
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Content
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EntryDetailScreen(
                    entry: entry,
                    webdavService: widget.webdavService,
                  ),
                ),
              ).then((_) => _loadEntries());
            },
            child: Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.getAgeLabel(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink.shade700,
                          ),
                        ),
                        Text(
                          '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        entry.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    if (entry.imagePaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.photo,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.imagePaths.length} 张照片',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (entry.videoPaths.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.videocam,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.videoPaths.length} 个视频',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildThumbnailGrid(entry),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailGrid(DiaryEntry entry) {
    // 合并图片和视频缩略图，最多显示6个
    final allThumbnails = [
      ...entry.imageThumbnails.map((path) => {'path': path, 'isVideo': false}),
      ...entry.videoThumbnails.map((path) => {'path': path, 'isVideo': true}),
    ].take(6).toList();

    if (allThumbnails.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: allThumbnails.map((thumbnail) {
        final path = thumbnail['path'] as String;
        final isVideo = thumbnail['isVideo'] as bool;
        return SizedBox(
          width: 60,
          height: 60,
          child: _buildThumbnailItem(path, isVideo),
        );
      }).toList(),
    );
  }

  Widget _buildThumbnailItem(String path, bool isVideo) {
    return FutureBuilder<Uint8List?>(
      future: _getThumbnailData(path),
      builder: (context, snapshot) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade200,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (snapshot.hasData && snapshot.data != null)
                  Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                  )
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  const Center(
                    child: Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
                if (isVideo)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _getThumbnailData(String path) async {
    // 如果已经有缓存的数据，直接返回
    if (_thumbnailCache.containsKey(path)) {
      return _thumbnailCache[path];
    }

    // 如果已经有正在进行的 Future，返回它
    if (_thumbnailFutures.containsKey(path)) {
      return _thumbnailFutures[path];
    }

    // 创建新的 Future 并缓存
    final future = _loadThumbnailData(path);
    _thumbnailFutures[path] = future;

    try {
      final data = await future;
      _thumbnailCache[path] = data;
      return data;
    } finally {
      // 清理 Future 缓存，保留数据缓存
      _thumbnailFutures.remove(path);
    }
  }

  Future<Uint8List?> _loadThumbnailData(String path) async {
    try {
      final data = await widget.webdavService.downloadMedia(path);
      return data;
    } catch (e) {
      debugPrint('Error loading thumbnail $path: $e');
      return null;
    }
  }
}
