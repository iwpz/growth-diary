import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import '../models/app_config.dart';
import '../services/cloud_storage_service.dart';
import '../services/local_storage_service.dart';
import '../services/qr_service.dart';
import 'setup_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  final AppConfig config;
  final CloudStorageService cloudService;
  final Function(AppConfig) onConfigChanged;

  const AppSettingsScreen({
    super.key,
    required this.config,
    required this.cloudService,
    required this.onConfigChanged,
  });

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final LocalStorageService _localStorage = LocalStorageService();
  final ScreenshotController _screenshotController = ScreenshotController();
  late AppConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  Future<void> _showQRCode() async {
    // 使用QRService生成加密的二维码数据
    final qrData = QRService.generateEncryptedQRData(_config);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Screenshot(
              controller: _screenshotController,
              child: Container(
                color: Colors.white, // 白色背景
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      height: 48,
                      width: 48,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFE91E63), // 粉红色
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 标题：宝宝名成长日记
                    Text(
                      '${_config.babyName}成长日记',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE91E63), // 粉红色
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    // 二维码
                    QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                    const SizedBox(height: 5),
                    // 说明文字
                    const Text(
                      '扫描二维码导入配置',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFAD1457), // 深粉色
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    // 截图并分享
                    final image = await _screenshotController.capture();
                    if (image != null && mounted) {
                      final directory = await getTemporaryDirectory();
                      final imagePath = '${directory.path}/qr_code.png';
                      final imageFile = File(imagePath);
                      await imageFile.writeAsBytes(image);

                      await Share.shareXFiles(
                        [XFile(imagePath)],
                        text: '扫描二维码导入${_config.babyName}的成长日记配置',
                      );
                    }
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('分享'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('这将删除所有已缓存的媒体文件。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // 显示loading对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在清除缓存...'),
            ],
          ),
        ),
      );

      try {
        await widget.cloudService.clearCache();

        // 关闭loading对话框
        if (mounted) {
          Navigator.of(context).pop(); // 关闭loading对话框

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('缓存已清除')),
          );
        }
      } catch (e) {
        // 关闭loading对话框
        if (mounted) {
          Navigator.of(context).pop(); // 关闭loading对话框

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除缓存失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('挥手告别'),
        content: const Text('这将清除当前宝宝的本地配置，线上文件仍然保留。确定要和宝宝说再见吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('挥手告别'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 删除当前配置
      await _localStorage.deleteConfig(_config.id);

      // 检查是否还有其他配置
      final remainingConfigs = await _localStorage.loadAllConfigs();

      if (remainingConfigs.isNotEmpty) {
        // deleteConfig已经设置了第一个配置为当前配置，这里不需要再设置
        // 通知父组件配置已更改（会重新加载所有配置）
        widget.onConfigChanged(remainingConfigs.values.first);

        // 返回首页，会自动切换到第一个宝宝
        if (mounted) {
          Navigator.of(context).pop(); // 返回首页
        }
      } else {
        // 如果没有配置了，返回初始化界面
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const SetupScreen(),
            ),
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        children: [
          _buildSection('数据管理'),
          ListTile(
            leading: const Icon(Icons.qr_code, color: Colors.green),
            title: const Text('导出配置二维码'),
            subtitle: const Text('生成包含宝宝配置信息的二维码'),
            onTap: _showQRCode,
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.orange),
            title: const Text('清除缓存'),
            subtitle: const Text('清除已下载的媒体文件缓存'),
            onTap: _clearCache,
          ),
          const Divider(),
          _buildSection('账户管理'),
          ListTile(
            leading: const Icon(Icons.waving_hand, color: Colors.red),
            title: const Text('挥手告别'),
            subtitle: const Text('清除当前宝宝的本地配置'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.pink.shade700,
        ),
      ),
    );
  }
}
