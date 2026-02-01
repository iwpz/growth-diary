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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content
        Expanded(
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
              elevation: 0,
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 12,
                  bottom: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    if (widget.entry.description.isNotEmpty) ...[
                      Text(
                        widget.entry.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Media Grid
                    if (widget.entry.imagePaths.isNotEmpty ||
                        widget.entry.videoPaths.isNotEmpty) ...[
                      _buildMediaGrid(),
                      const SizedBox(height: 6),
                    ],

                    // Footer info
                    Row(
                      children: [
                        Text(
                          '${widget.entry.date.year}-${widget.entry.date.month.toString().padLeft(2, '0')}-${widget.entry.date.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const Spacer(),
                        if (widget.entry.imagePaths.isNotEmpty ||
                            widget.entry.videoPaths.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.entry.imagePaths.isNotEmpty) ...[
                                  Icon(
                                    Icons.photo,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.entry.imagePaths.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                if (widget.entry.videoPaths.isNotEmpty) ...[
                                  if (widget.entry.imagePaths.isNotEmpty)
                                    const SizedBox(width: 8),
                                  Icon(
                                    Icons.videocam,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.entry.videoPaths.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaGrid() {
    final allThumbnails = [
      ...widget.entry.imageThumbnails
          .map((path) => {'path': path, 'isVideo': false}),
      ...widget.entry.videoThumbnails
          .map((path) => {'path': path, 'isVideo': true}),
    ];

    if (allThumbnails.isEmpty) return const SizedBox.shrink();

    // Determine layout based on count
    final count = allThumbnails.length;
    final displayCount = count > 9 ? 9 : count;
    final displayList = allThumbnails.take(displayCount).toList();

    // Single item - large view
    if (count == 1) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _buildThumbnailItem(
          (displayList[0]['path'] as String).replaceAll('small', 'medium'),
          displayList[0]['isVideo'] as bool,
        ),
      );
    }

    // Grid view
    int crossAxisCount = 3;
    if (count == 2 || count == 4) {
      crossAxisCount = 2;
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final item = displayList[index];
        final remaining = count - displayCount;

        // Show +N on the last item if there are more
        if (index == displayCount - 1 && remaining > 0) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnailItem(
                  crossAxisCount == 2
                      ? (item['path'] as String).replaceAll('small', 'medium')
                      : item['path'] as String,
                  item['isVideo'] as bool),
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                alignment: Alignment.center,
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }

        return _buildThumbnailItem(
            item['path'] as String, item['isVideo'] as bool);
      },
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
