import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/diary_entry.dart';
import '../models/app_config.dart';
import '../services/cloud_storage_service.dart';
import '../screens/entry_detail_screen.dart';

class TimelineItem extends StatefulWidget {
  final DiaryEntry entry;
  final bool isFirst;
  final bool isLast;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final AppConfig config;
  final CloudStorageService webdavService;
  final void Function(EntryDetailResult, DiaryEntry) onEntryUpdated;
  final void Function(AppConfig)? onConfigChanged;
  final Map<String, Uint8List?> thumbnailCache;
  final Map<String, Future<Uint8List?>> thumbnailFutures;

  const TimelineItem({
    super.key,
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.config,
    required this.webdavService,
    required this.onEntryUpdated,
    this.onConfigChanged,
    required this.thumbnailCache,
    required this.thumbnailFutures,
  });

  @override
  State<TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<TimelineItem> {
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 60,
            child: Column(
              children: [
                // Top line (only if not first in month)
                Container(
                  width: 2,
                  height: 24,
                  color: Colors.pink.shade200,
                ),

                // Circle indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.pink.shade300,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),

                // Bottom line
                if (!widget.isLastInGroup)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.pink.shade200,
                    ),
                  )
                else if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      height: 48, // Connect to next month separator
                      color: Colors.pink.shade200,
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EntryDetailScreen(
                        entry: widget.entry,
                        config: widget.config,
                        cloudService: widget.webdavService,
                        onEntryUpdated: widget.onEntryUpdated,
                        onConfigChanged: widget.onConfigChanged,
                      ),
                    ),
                  ).then((result) => widget.onEntryUpdated(
                      result ?? const EntryDetailResult(), widget.entry));
                },
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description
                        if (widget.entry.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.entry.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        // Media info
                        if (widget.entry.imagePaths.isNotEmpty ||
                            widget.entry.videoPaths.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (widget.entry.imagePaths.isNotEmpty) ...[
                                Icon(
                                  Icons.photo,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.entry.imagePaths.length} 张照片',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                              if (widget.entry.videoPaths.isNotEmpty) ...[
                                if (widget.entry.imagePaths.isNotEmpty)
                                  const SizedBox(width: 12),
                                Icon(
                                  Icons.videocam,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.entry.videoPaths.length} 个视频',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildThumbnailGrid(),
                        ],
                        Text(
                          '${widget.entry.date.year}-${widget.entry.date.month.toString().padLeft(2, '0')}-${widget.entry.date.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailGrid() {
    // 合并图片和视频缩略图，最多显示6个
    final allThumbnails = [
      ...widget.entry.imageThumbnails
          .map((path) => {'path': path, 'isVideo': false}),
      ...widget.entry.videoThumbnails
          .map((path) => {'path': path, 'isVideo': true}),
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
    if (widget.thumbnailCache.containsKey(path)) {
      return widget.thumbnailCache[path];
    }

    // 如果已经有正在进行的 Future，返回它
    if (widget.thumbnailFutures.containsKey(path)) {
      return widget.thumbnailFutures[path];
    }

    // 创建新的 Future 并缓存
    final future = _loadThumbnailData(path);
    widget.thumbnailFutures[path] = future;

    try {
      final data = await future;
      if (mounted) {
        setState(() {
          widget.thumbnailCache[path] = data;
        });
      }
      return data;
    } finally {
      // 清理 Future 缓存，保留数据缓存
      widget.thumbnailFutures.remove(path);
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
