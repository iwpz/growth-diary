import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:exif/exif.dart';
import '../models/app_config.dart';
import '../models/diary_entry.dart';
import '../services/webdav_service.dart';
import '../services/entry_creation_service.dart';
import '../utils/age_calculator.dart';
import 'entry_detail_screen.dart';
import 'settings_screen.dart';
import 'diary_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  AppConfig config;
  final WebDAVService webdavService;

  HomeScreen({
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
  bool _isExpanded = false;
  final ImagePicker _picker = ImagePicker();
  late final EntryCreationService _entryService;
  bool _isUploading = false;
  int _totalFiles = 0;
  int _uploadedFiles = 0;
  String _uploadMessage = '';

  late AppConfig config;

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

  @override
  void initState() {
    super.initState();
    config = widget.config;
    _entryService = EntryCreationService(widget.webdavService);
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

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
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

  Future<Map<String, dynamic>?> _showDateAndDescriptionDialog(
      DateTime initialDate) async {
    DateTime selectedDate = initialDate;
    String description = '';

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false, // 必须选择日期，不能取消
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('选择日期并添加描述'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('检测到文件日期可能有误，请选择正确的日期'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  // 计算 firstDate：优先使用 conceptionDate，否则使用 childBirthDate 减去 280 天，最后使用 2000 年
                  final firstDate = config.conceptionDate ??
                      (config.childBirthDate
                          ?.subtract(const Duration(days: 280))) ??
                      DateTime(2000);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate.isBefore(firstDate)
                        ? firstDate
                        : selectedDate,
                    firstDate: firstDate,
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
                child: Text(
                    '选择日期: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => description = value,
                decoration: const InputDecoration(hintText: '请输入描述（可选）'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: selectedDate != initialDate
                  ? () => Navigator.of(context)
                      .pop({'date': selectedDate, 'description': description})
                  : null,
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addImage() async {
    print('Add image button pressed');
    _toggleExpanded(); // 关闭菜单
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isEmpty) return;

      // 获取第一张图片的日期
      DateTime detectedDate = DateTime.now();
      if (images.isNotEmpty) {
        final firstImage = File(images.first.path);
        try {
          final exifData =
              await readExifFromBytes(await firstImage.readAsBytes());
          final dateTimeOriginal = exifData['EXIF DateTimeOriginal'];
          final imageDateTime = exifData['Image DateTime'];
          if (dateTimeOriginal != null) {
            detectedDate = _parseExifDate(dateTimeOriginal.toString());
          } else if (imageDateTime != null) {
            detectedDate = _parseExifDate(imageDateTime.toString());
          } else {
            final stat = await firstImage.stat();
            detectedDate = stat.changed;
          }
        } catch (e) {
          final stat = await firstImage.stat();
          detectedDate = stat.changed;
        }
      }

      // 检查日期是否早于阈值日期（受孕日或出生前280天）
      String? description;
      DateTime? selectedDate;
      DateTime? thresholdDate;
      if (config.conceptionDate != null) {
        thresholdDate = config.conceptionDate;
      } else if (config.childBirthDate != null) {
        thresholdDate =
            config.childBirthDate!.subtract(const Duration(days: 280));
      }

      if (thresholdDate != null && detectedDate.isBefore(thresholdDate)) {
        final result = await _showDateAndDescriptionDialog(detectedDate);
        if (result == null) return; // 用户取消
        selectedDate = result['date'] as DateTime;
        description = result['description'] as String;
      } else {
        description = await _showDescriptionDialog();
        if (description == null) return;
      }

      setState(() {
        _isUploading = true;
        _totalFiles = images.length;
        _uploadedFiles = 0;
        _uploadMessage = '正在上传图片...';
      });

      await _entryService.createImageEntry(images, description, config,
          (uploaded, total) {
        setState(() {
          _uploadedFiles = uploaded;
        });
      }, selectedDate);

      setState(() {
        _isUploading = false;
      });

      _loadEntries();
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加图片记录失败: $e')),
      );
    }
  }

  Future<void> _addVideo() async {
    print('Add video button pressed');
    _toggleExpanded(); // 关闭菜单
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      // 获取视频的日期
      DateTime detectedDate = DateTime.now();
      final videoFile = File(video.path);
      final stat = await videoFile.stat();
      detectedDate = stat.changed;

      // 检查日期是否早于阈值日期（受孕日或出生前280天）
      String? description;
      DateTime? selectedDate;
      DateTime? thresholdDate;
      if (config.conceptionDate != null) {
        thresholdDate = config.conceptionDate;
      } else if (config.childBirthDate != null) {
        thresholdDate =
            config.childBirthDate!.subtract(const Duration(days: 280));
      }

      if (thresholdDate != null && detectedDate.isBefore(thresholdDate)) {
        final result = await _showDateAndDescriptionDialog(detectedDate);
        if (result == null) return; // 用户取消
        selectedDate = result['date'] as DateTime;
        description = result['description'] as String;
      } else {
        description = await _showDescriptionDialog();
        if (description == null) return;
      }

      setState(() {
        _isUploading = true;
        _totalFiles = 1;
        _uploadedFiles = 0;
        _uploadMessage = '正在上传视频...';
      });

      await _entryService.createVideoEntry(video, description, config,
          (uploaded, total) {
        setState(() {
          _uploadedFiles = uploaded;
        });
      }, selectedDate);

      setState(() {
        _isUploading = false;
      });

      _loadEntries();
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加视频记录失败: $e')),
      );
    }
  }

  Future<void> _addDiary() async {
    print('Add diary button pressed');
    _toggleExpanded(); // 关闭菜单
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryEditorScreen(
          config: config,
          webdavService: widget.webdavService,
        ),
      ),
    ).then((_) => _loadEntries());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${config.childName}的成长日记'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    config: config,
                    webdavService: widget.webdavService,
                    onConfigChanged: (newConfig) {
                      setState(() {
                        config = newConfig;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_uploadMessage),
                        Text('$_uploadedFiles / $_totalFiles'),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_entries.isEmpty)
            _buildEmptyState()
          else
            _buildTimeline(),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 视频按钮 - 向上展开
                if (_isExpanded)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: FloatingActionButton(
                      heroTag: 'video_fab',
                      onPressed: _addVideo,
                      backgroundColor: Colors.pink.shade200,
                      foregroundColor: Colors.white,
                      mini: true,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.videocam),
                    ),
                  ),
                // 图片按钮 - 向上展开
                if (_isExpanded)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: FloatingActionButton(
                      heroTag: 'image_fab',
                      onPressed: _addImage,
                      backgroundColor: Colors.pink.shade300,
                      foregroundColor: Colors.white,
                      mini: true,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.photo),
                    ),
                  ),
                // 日记按钮 - 向上展开
                if (_isExpanded)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: FloatingActionButton(
                      heroTag: 'diary_fab',
                      onPressed: _addDiary,
                      backgroundColor: Colors.pink.shade400,
                      foregroundColor: Colors.white,
                      mini: true,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.book),
                    ),
                  ),
                // 主按钮
                FloatingActionButton(
                  heroTag: 'main_fab',
                  onPressed: _toggleExpanded,
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: Icon(_isExpanded ? Icons.close : Icons.add),
                ),
              ],
            ),
          ),
        ],
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
    int preBirthItemCount = _getPreBirthItemCount();
    bool hasPreBirth = preBirthItemCount > 0;
    int postBirthItemCount = _getPostBirthItemCount();

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 1 +
            postBirthItemCount +
            1 +
            preBirthItemCount, // current month + post + birth label + pre
        itemBuilder: (context, index) {
          if (index == 0) return _buildCurrentMonthSeparator();
          index -= 1;

          if (index < postBirthItemCount) {
            return _buildPostBirthItemAtIndex(index);
          }
          index -= postBirthItemCount;

          if (index == 0)
            return _buildBirthDateLabel(showBottomLine: hasPreBirth);
          index -= 1;

          return _buildPreBirthItemAtIndex(index);
        },
      ),
    );
  }

  Widget _buildGroupSeparator(DiaryEntry representativeEntry, bool isFirstGroup,
      bool isLastGroup, bool isPregnancyPeriod, AppConfig config) {
    final groupValue = representativeEntry.getGroupKey(config);
    final displayValue = isPregnancyPeriod
        ? groupValue
        : (groupValue < 0 ? -groupValue : groupValue);
    final displayText = isPregnancyPeriod
        ? '$displayValue'
        : (groupValue < 0 ? '前$displayValue' : '$displayValue');
    final labelText = isPregnancyPeriod
        ? '孕期 $displayValue 周'
        : representativeEntry.getSimplifiedAgeLabel(config.childBirthDate);

    return Row(
      children: [
        // Timeline indicator for group
        SizedBox(
          width: 60,
          child: Column(
            children: [
              // Top line (only if not first group)
              if (!isFirstGroup)
                Container(
                  width: 2,
                  height: 24,
                  color: Colors.pink.shade200,
                ),

              // Group circle
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.pink.shade300, Colors.pink.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    displayText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Bottom line (only if not last group)
              Container(
                width: 2,
                height: 24,
                color: Colors.pink.shade200,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Group label
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.pink.shade200,
                width: 1,
              ),
            ),
            child: Text(
              labelText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(DiaryEntry entry, bool isFirst, bool isLast,
      bool isFirstInGroup, bool isLastInGroup) {
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
                if (!isLastInGroup)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.pink.shade200,
                    ),
                  )
                else if (!isLast)
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
              padding: const EdgeInsets.only(bottom: 24),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EntryDetailScreen(
                        entry: entry,
                        config: config,
                        webdavService: widget.webdavService,
                      ),
                    ),
                  ).then((_) => _loadEntries());
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
                        // Date
                        // Title
                        if (entry.title.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            entry.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        // Description
                        if (entry.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            entry.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        // Media info
                        if (entry.imagePaths.isNotEmpty ||
                            entry.videoPaths.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (entry.imagePaths.isNotEmpty) ...[
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
                              ],
                              if (entry.videoPaths.isNotEmpty) ...[
                                if (entry.imagePaths.isNotEmpty)
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
                        Text(
                          '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
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

  Widget _buildBirthDateLabel({bool showBottomLine = true}) {
    final birthDate = config.childBirthDate;
    if (birthDate == null) return const SizedBox.shrink();

    return Row(
      children: [
        // Timeline indicator for birth date
        SizedBox(
          width: 60,
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade300, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.child_care,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),

              // Bottom line (only if showBottomLine)
              if (showBottomLine)
                Container(
                  width: 2,
                  height: 24,
                  color: Colors.blue.shade200,
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Birth date label
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.blue.shade200,
                width: 1,
              ),
            ),
            child: Text(
              '出生日期: ${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentMonthSeparator() {
    final currentDate = DateTime.now();
    final birthDate = config.childBirthDate;
    if (birthDate == null) {
      return const SizedBox.shrink(); // Or some default
    }
    final currentAgeInMonths =
        AgeCalculator.calculateAgeInMonths(birthDate, currentDate);
    final ageLabel =
        AgeCalculator.formatDetailedAgeLabel(birthDate, currentDate);

    return Row(
      children: [
        // Timeline indicator for current month
        SizedBox(
          width: 60,
          child: Column(
            children: [
              // Month circle
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.pink.shade300, Colors.pink.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$currentAgeInMonths',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Bottom line
              Container(
                width: 2,
                height: 24,
                color: Colors.pink.shade200,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Age label
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.pink.shade200,
                width: 1,
              ),
            ),
            child: Text(
              ageLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _getItemCountForEntries(List<DiaryEntry> entries,
      bool skipCurrentMonthSeparator, AppConfig config) {
    if (entries.isEmpty) return 0;

    final groupGroups = <int, List<DiaryEntry>>{};
    for (final entry in entries) {
      final groupKey = entry.getGroupKey(config);
      groupGroups.putIfAbsent(groupKey, () => []).add(entry);
    }

    final sortedGroups = groupGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final currentDate = DateTime.now();
    final birthDate = config.childBirthDate;
    final currentGroup =
        birthDate != null && !entries.any((e) => e.date.isBefore(birthDate))
            ? AgeCalculator.calculateAgeInMonths(birthDate, currentDate)
            : null;

    int count = 0;
    int groupIndex = 0;
    for (final group in sortedGroups) {
      final entriesInGroup = groupGroups[group]!;
      final isFirstGroup = groupIndex == 0;
      final skipSeparator =
          skipCurrentMonthSeparator && isFirstGroup && group == currentGroup;
      if (!skipSeparator) {
        count += 1; // separator
      }
      count += entriesInGroup.length;
      groupIndex++;
    }

    return count;
  }

  int _getPreBirthItemCount() {
    final birthDate = config.childBirthDate;
    if (birthDate == null) return 0;
    final preBirthEntries =
        _entries.where((e) => e.date.isBefore(birthDate)).toList();
    return _getItemCountForEntries(preBirthEntries, false, config);
  }

  int _getPostBirthItemCount() {
    final birthDate = config.childBirthDate;
    final postBirthEntries = _entries
        .where((e) => birthDate == null || !e.date.isBefore(birthDate))
        .toList();
    return _getItemCountForEntries(postBirthEntries, true, config);
  }

  Widget _buildItemAtIndexForEntries(List<DiaryEntry> entries, int index,
      bool skipCurrentMonthSeparator, AppConfig config) {
    final groupGroups = <int, List<DiaryEntry>>{};
    for (final entry in entries) {
      final groupKey = entry.getGroupKey(config);
      groupGroups.putIfAbsent(groupKey, () => []).add(entry);
    }

    final sortedGroups = groupGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final currentDate = DateTime.now();
    final birthDate = config.childBirthDate;
    final currentGroup =
        birthDate != null && !entries.any((e) => e.date.isBefore(birthDate))
            ? AgeCalculator.calculateAgeInMonths(birthDate, currentDate)
            : null;

    int currentIndex = 0;
    int groupIndex = 0;

    for (final group in sortedGroups) {
      final entriesInGroup = groupGroups[group]!;
      final isFirstGroup = groupIndex == 0;
      final isLastGroup = groupIndex == sortedGroups.length - 1;
      final skipSeparator =
          skipCurrentMonthSeparator && isFirstGroup && group == currentGroup;

      if (!skipSeparator) {
        if (currentIndex == index) {
          final isPregnancyPeriod = config.conceptionDate != null &&
              entriesInGroup.first.date.isBefore(birthDate ?? DateTime.now());
          return _buildGroupSeparator(entriesInGroup.first, isFirstGroup,
              isLastGroup, isPregnancyPeriod, config);
        }
        currentIndex++;
      }
      groupIndex++;

      for (final entry in entriesInGroup) {
        if (currentIndex == index) {
          final entryIndex = entries.indexOf(entry);
          final isFirst = entryIndex == 0;
          final isLast = entryIndex == entries.length - 1 &&
              entry.date.isBefore(birthDate ?? DateTime.now());
          final isFirstInGroup = entriesInGroup.first == entry;
          final isLastInGroup = entriesInGroup.last == entry;

          return _buildTimelineItem(
              entry, isFirst, isLast, isFirstInGroup, isLastInGroup);
        }
        currentIndex++;
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildPreBirthItemAtIndex(int index) {
    final birthDate = config.childBirthDate!;
    final preBirthEntries = _entries
        .where((e) => e.date.isBefore(birthDate))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return _buildItemAtIndexForEntries(preBirthEntries, index, false, config);
  }

  Widget _buildPostBirthItemAtIndex(int index) {
    final birthDate = config.childBirthDate;
    final postBirthEntries = _entries
        .where((e) => birthDate == null || !e.date.isBefore(birthDate))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return _buildItemAtIndexForEntries(postBirthEntries, index, true, config);
  }
}
