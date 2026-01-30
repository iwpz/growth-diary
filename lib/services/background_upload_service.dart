import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import '../services/webdav_service.dart';
import '../services/entry_creation_service.dart';

// 上传任务状态枚举
enum UploadStatus {
  pending, // 等待开始
  uploading, // 正在上传
  paused, // 已暂停
  completed, // 已完成
  failed, // 失败
}

// 上传任务数据模型
class UploadTask {
  final String id;
  final List<String> mediaPaths;
  final String description;
  final AppConfig config;
  final DateTime? overrideDate;
  final DateTime createdAt;

  UploadStatus status;
  int uploadedCount; // 已上传的文件数量
  List<String> failedFiles; // 上传失败的文件列表
  String? errorMessage;

  UploadTask({
    required this.id,
    required this.mediaPaths,
    required this.description,
    required this.config,
    this.overrideDate,
    DateTime? createdAt,
    this.status = UploadStatus.pending,
    this.uploadedCount = 0,
    List<String>? failedFiles,
    this.errorMessage,
  })  : createdAt = createdAt ?? DateTime.now(),
        failedFiles = failedFiles ?? [];

  // 从JSON创建UploadTask
  factory UploadTask.fromJson(Map<String, dynamic> json) {
    return UploadTask(
      id: json['id'] as String,
      mediaPaths: (json['mediaPaths'] as List).cast<String>(),
      description: json['description'] as String,
      config: AppConfig.fromJson(json['config'] as Map<String, dynamic>),
      overrideDate: json['overrideDate'] != null
          ? DateTime.parse(json['overrideDate'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: UploadStatus.values[json['status'] as int],
      uploadedCount: json['uploadedCount'] as int,
      failedFiles: (json['failedFiles'] as List?)?.cast<String>() ?? [],
      errorMessage: json['errorMessage'] as String?,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaPaths': mediaPaths,
      'description': description,
      'config': config.toJson(),
      'overrideDate': overrideDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'status': status.index,
      'uploadedCount': uploadedCount,
      'failedFiles': failedFiles,
      'errorMessage': errorMessage,
    };
  }

  // 获取剩余需要上传的文件
  List<String> get remainingFiles {
    final allFiles = mediaPaths;
    final completedFiles = allFiles.sublist(0, uploadedCount);
    return allFiles
        .where((file) =>
            !completedFiles.contains(file) && !failedFiles.contains(file))
        .toList();
  }

  // 检查是否还有文件需要上传
  bool get hasRemainingFiles => remainingFiles.isNotEmpty;
}

class BackgroundUploadService {
  static const String notificationChannelId = 'upload_channel';
  static const String notificationChannelName = '上传进度';
  static const String _uploadTasksKey = 'upload_tasks'; // SharedPreferences key

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 上传完成回调
  static Function()? _onUploadCompleted;

  // 上传进度更新回调
  static Function()? _onUploadProgressUpdated;

  // 跟踪活跃的上传任务
  static final Map<String, UploadTask> _activeTasks = {};
  static final Map<String, bool> _activeUploads = {}; // 兼容性保留

  static Future<void> initialize() async {
    // 初始化通知插件
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notificationsPlugin.initialize(settings);
    if (initialized == null || !initialized) {
      print('❌ 通知插件初始化失败');
      return;
    }

    print('✅ 通知插件初始化成功');

    // 请求通知权限
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // 请求基本通知权限
      final granted = await androidPlugin.requestNotificationsPermission();
      print('📱 Android通知权限: ${granted == true ? '已授予' : '未授予'}');
    }

    // 创建通知渠道 - 使用更高的优先级确保可见性
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      notificationChannelName,
      description: '显示上传进度',
      importance: Importance.defaultImportance, // 从 low 改为 default
      showBadge: true, // 允许显示角标
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('✅ 通知渠道创建成功');

    // 恢复未完成的上传任务
    await _restorePendingUploads();

    print('Background upload service initialized');
  }

  // 设置上传完成回调
  static void setUploadCompletedCallback(Function() callback) {
    _onUploadCompleted = callback;
  }

  // 设置上传进度更新回调
  static void setUploadProgressCallback(Function() callback) {
    _onUploadProgressUpdated = callback;
  }

  static Future<void> _showProgressNotification(
    int uploaded,
    int total,
    String message, {
    bool isError = false,
  }) async {
    // 构建更详细的进度消息，总是包含进度信息
    String detailedMessage =
        total > 1 ? '$message ($uploaded/$total)' : '$message $uploaded/$total';

    print(
        '📱 显示通知: $detailedMessage, uploaded=$uploaded, total=$total, isError=$isError');

    final androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: '显示上传进度',
      importance:
          isError ? Importance.high : Importance.defaultImportance, // 错误时使用高优先级
      priority: isError ? Priority.high : Priority.defaultPriority, // 错误时使用高优先级
      showProgress: !isError && total > 1, // 只在多文件时显示进度条
      maxProgress: total,
      progress: uploaded,
      ongoing: !isError && uploaded < total,
      autoCancel: isError || uploaded >= total,
      color: isError ? const Color(0xFFE57373) : const Color(0xFFE91E63),
      // 确保文字可见
      styleInformation: const DefaultStyleInformation(true, true),
      // 添加更多可见性设置
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.progress,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0, // notification id
      '成长日记上传',
      detailedMessage,
      details,
    );
  }

  static Future<void> _showCompletionNotification(String message) async {
    // 先取消之前的进度通知
    await _notificationsPlugin.cancel(0);

    print('✅ 显示完成通知: $message');

    const androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: '显示上传进度',
      importance: Importance.high, // 完成通知使用更高优先级
      priority: Priority.high,
      showProgress: false, // 不显示进度条
      autoCancel: true, // 自动消失
      color: Color(0xFF4CAF50), // 绿色表示成功
      timeoutAfter: 5000, // 5秒后自动消失
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.status,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      1, // 使用不同的通知ID，避免与进度通知冲突
      '成长日记上传',
      message,
      details,
    );
  }

  static Future<String> startBackgroundUpload({
    required List<String> mediaPaths,
    required String description,
    required AppConfig config,
    DateTime? overrideDate,
  }) async {
    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();

    // 创建上传任务
    final task = UploadTask(
      id: uploadId,
      mediaPaths: mediaPaths,
      description: description,
      config: config,
      overrideDate: overrideDate,
      status: UploadStatus.uploading,
    );

    // 保存到内存和持久化存储
    _activeTasks[uploadId] = task;
    _activeUploads[uploadId] = true; // 兼容性保留
    await _saveUploadTask(task);

    // 在后台启动上传任务（异步，不阻塞UI）
    _performAsyncUpload(task);

    return uploadId;
  }

  static Future<void> _performAsyncUpload(UploadTask task) async {
    try {
      // 更新任务状态
      task.status = UploadStatus.uploading;
      await _saveUploadTask(task);

      // 显示初始通知
      await _showProgressNotification(
          task.uploadedCount,
          task.mediaPaths.length,
          task.hasRemainingFiles ? '继续上传...' : '开始上传...');

      final webdavService = WebDAVService();
      await webdavService.initialize(task.config);

      final entryService = EntryCreationService(webdavService);

      // 获取剩余需要上传的文件
      final remainingFiles = task.remainingFiles;

      if (remainingFiles.isEmpty) {
        // 所有文件都已上传完成
        task.status = UploadStatus.completed;
        await _saveUploadTask(task);
        await _showProgressNotification(
            task.mediaPaths.length, task.mediaPaths.length, '上传完成');
        return;
      }

      if (remainingFiles.length == 1 && _isVideoFile(remainingFiles.first)) {
        // 单个视频上传
        final videoFile = File(remainingFiles.first);
        if (!await videoFile.exists()) {
          throw Exception('视频文件不存在: ${remainingFiles.first}');
        }

        await entryService.createVideoEntry(
          XFile(videoFile.path),
          task.description,
          task.config,
          (uploaded, total) {
            task.uploadedCount = uploaded;
            print(
                'Video upload progress: uploaded=$uploaded, total=$total, task.uploadedCount=${task.uploadedCount}');
            _showProgressNotification(
                task.uploadedCount, task.mediaPaths.length, '正在上传视频...');
            _saveUploadTask(task); // 实时保存进度
            _onUploadProgressUpdated?.call(); // 通知UI更新进度
          },
          task.overrideDate,
        );
      } else {
        // 图片上传（支持多张，按日期分组）
        final imageFiles = <XFile>[];
        for (final path in remainingFiles) {
          final file = File(path);
          if (!await file.exists()) {
            task.failedFiles.add(path);
            task.errorMessage = '图片文件不存在: $path';
            await _saveUploadTask(task);
            continue;
          }
          imageFiles.add(XFile(file.path));
        }

        if (imageFiles.isNotEmpty) {
          await entryService.createImageEntry(
            imageFiles,
            task.description,
            task.config,
            (uploaded, total) {
              task.uploadedCount = uploaded;
              print(
                  'Image upload progress: uploaded=$uploaded, total=$total, task.uploadedCount=${task.uploadedCount}');
              _showProgressNotification(
                  task.uploadedCount, task.mediaPaths.length, '正在上传图片...');
              _saveUploadTask(task); // 实时保存进度
              _onUploadProgressUpdated?.call(); // 通知UI更新进度
            },
            task.overrideDate,
          );
        }
      }

      // 检查是否还有失败的文件
      if (task.failedFiles.isNotEmpty) {
        task.status = UploadStatus.failed;
        task.errorMessage = '部分文件上传失败: ${task.failedFiles.join(", ")}';
      } else {
        task.status = UploadStatus.completed;
        // 上传完成，调用回调刷新首页
        _onUploadCompleted?.call();
      }

      await _saveUploadTask(task);

      // 显示完成通知
      if (task.status == UploadStatus.completed) {
        // 只使用专门的完成通知，确保能正确自动消失
        await _showCompletionNotification('所有文件上传完成');
      } else {
        await _showProgressNotification(
          task.uploadedCount,
          task.mediaPaths.length,
          task.errorMessage ?? '上传失败',
          isError: true,
        );
      }
    } catch (e) {
      // 更新任务状态为失败
      task.status = UploadStatus.failed;
      task.errorMessage = e.toString();
      await _saveUploadTask(task);

      // 显示错误通知
      await _showProgressNotification(
        task.uploadedCount,
        task.mediaPaths.length,
        '上传失败: $e',
        isError: true,
      );
    } finally {
      // 清理活跃上传标记
      _activeTasks.remove(task.id);
      _activeUploads.remove(task.id); // 兼容性保留
    }
  }

  static bool hasActiveUploads() {
    return _activeUploads.isNotEmpty;
  }

  static Future<void> showBackgroundNotification(
      String title, String message) async {
    print('🔄 显示后台通知: $title - $message');

    const androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: '显示上传进度',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true, // 持续通知
      autoCancel: false,
      color: Color(0xFFE91E63),
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.service,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      1, // 不同的通知ID，避免与进度通知冲突
      title,
      message,
      details,
    );
  }

  // 持久化存储方法
  static Future<void> _saveUploadTask(UploadTask task) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString(_uploadTasksKey) ?? '{}';
    final tasksMap = json.decode(tasksJson) as Map<String, dynamic>;

    tasksMap[task.id] = task.toJson();
    await prefs.setString(_uploadTasksKey, json.encode(tasksMap));
  }

  static Future<void> _removeUploadTask(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString(_uploadTasksKey) ?? '{}';
    final tasksMap = json.decode(tasksJson) as Map<String, dynamic>;

    tasksMap.remove(taskId);
    await prefs.setString(_uploadTasksKey, json.encode(tasksMap));
  }

  static Future<void> _restorePendingUploads() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString(_uploadTasksKey);

    if (tasksJson == null) return;

    final tasksMap = json.decode(tasksJson) as Map<String, dynamic>;

    for (final entry in tasksMap.entries) {
      try {
        final task = UploadTask.fromJson(entry.value as Map<String, dynamic>);

        // 只恢复未完成的任务
        if (task.status == UploadStatus.uploading ||
            task.status == UploadStatus.pending) {
          _activeTasks[task.id] = task;
          _activeUploads[task.id] = true; // 兼容性保留

          // 重新启动上传任务
          _performAsyncUpload(task);
        } else if (task.status == UploadStatus.failed &&
            task.hasRemainingFiles) {
          // 对于失败的任务，如果还有剩余文件，可以选择重新启动
          task.status = UploadStatus.pending;
          _activeTasks[task.id] = task;
          _activeUploads[task.id] = true;

          // 显示恢复通知
          await _showProgressNotification(
              task.uploadedCount, task.mediaPaths.length, '检测到未完成的上传，正在恢复...');

          _performAsyncUpload(task);
        }
      } catch (e) {
        print('Failed to restore upload task ${entry.key}: $e');
        // 清理损坏的任务数据
        await _removeUploadTask(entry.key);
      }
    }
  }

  // 公共方法：获取所有上传任务
  static List<UploadTask> getAllUploadTasks() {
    return _activeTasks.values.toList();
  }

  // 公共方法：取消上传任务
  static Future<void> cancelUpload(String uploadId) async {
    final task = _activeTasks[uploadId];
    if (task != null) {
      task.status = UploadStatus.failed;
      task.errorMessage = '用户取消上传';
      await _saveUploadTask(task);
    }

    // 清理活跃上传标记
    _activeTasks.remove(uploadId);
    _activeUploads.remove(uploadId); // 兼容性保留
  }

  // 公共方法：重试失败的上传
  static Future<void> retryUpload(String uploadId) async {
    final task = _activeTasks[uploadId];
    if (task != null &&
        task.status == UploadStatus.failed &&
        task.hasRemainingFiles) {
      task.status = UploadStatus.uploading;
      task.errorMessage = null;
      await _saveUploadTask(task);

      _performAsyncUpload(task);
    }
  }

  static bool _isVideoFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm']
        .contains(extension);
  }
}
