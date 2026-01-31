import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/cloud_storage_service.dart';
import '../services/local_storage_service.dart';
import 'setup_screen.dart';
import 'webdav_config_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppConfig config;
  final CloudStorageService cloudService;
  final Function(AppConfig) onConfigChanged;

  const SettingsScreen({
    super.key,
    required this.config,
    required this.cloudService,
    required this.onConfigChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalStorageService _localStorage = LocalStorageService();
  late AppConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  Future<void> _showEditChildNameDialog() async {
    String newName = _config.babyName;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改宝宝昵称'),
        content: TextField(
          controller: TextEditingController(text: newName),
          onChanged: (value) => newName = value,
          decoration: const InputDecoration(hintText: '请输入宝宝昵称'),
        ),
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
    if (result == true && newName.isNotEmpty) {
      final updatedConfig = _config.copyWith(babyName: newName);
      setState(() {
        _config = updatedConfig;
      });
      await _localStorage.saveConfig(_config);
      await widget.cloudService.saveConfig(_config);
      widget.onConfigChanged(_config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('宝宝昵称已更新')),
        );
      }
    }
  }

  Future<void> _editBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _config.babyBirthDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final updatedConfig = _config.copyWith(babyBirthDate: picked);
      setState(() {
        _config = updatedConfig;
      });
      await _localStorage.saveConfig(_config);
      await widget.cloudService.saveConfig(_config);
      widget.onConfigChanged(_config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('宝宝生日已更新')),
        );
      }
    }
  }

  Future<void> _editConceptionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _config.babyConceptionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final updatedConfig = _config.copyWith(babyConceptionDate: picked);
      setState(() {
        _config = updatedConfig;
      });
      await _localStorage.saveConfig(_config);
      await widget.cloudService.saveConfig(_config);
      widget.onConfigChanged(_config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('受孕日已更新')),
        );
      }
    }
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

  Future<void> _resetConfiguration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新配置'),
        content: const Text('这将清除当前配置并返回设置页面。确定继续吗？'),
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

    if (confirm == true) {
      await _localStorage.clearAllConfigs();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => SetupScreen(
              localStorage: _localStorage,
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        children: [
          _buildSection('宝宝信息'),
          ListTile(
            leading: const Icon(Icons.baby_changing_station),
            title: const Text('宝宝昵称'),
            subtitle: Text(_config.childName),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showEditChildNameDialog,
          ),
          ListTile(
            leading: const Icon(Icons.cake),
            title: const Text('宝宝生日'),
            subtitle: Text(
              _config.childBirthDate != null
                  ? '${_config.childBirthDate!.year}-${_config.childBirthDate!.month.toString().padLeft(2, '0')}-${_config.childBirthDate!.day.toString().padLeft(2, '0')}'
                  : '未设置',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editBirthDate,
          ),
          ListTile(
            leading: const Icon(Icons.pregnant_woman),
            title: const Text('受孕日'),
            subtitle: Text(
              _config.conceptionDate != null
                  ? '${_config.conceptionDate!.year}-${_config.conceptionDate!.month.toString().padLeft(2, '0')}-${_config.conceptionDate!.day.toString().padLeft(2, '0')}'
                  : '未设置',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editConceptionDate,
          ),
          const Divider(),
          _buildSection('WebDAV 配置'),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('WebDAV 配置'),
            subtitle: Text('${_config.webdavUrl} (${_config.username})'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WebDAVConfigScreen(
                    mode: WebDAVConfigMode.settings,
                    config: _config,
                    webdavService: widget.cloudService,
                    onConfigChanged: widget.onConfigChanged,
                  ),
                ),
              ).then((_) {
                // 刷新配置
                setState(() {});
              });
            },
          ),
          const Divider(),
          _buildSection('应用'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('关于'),
            subtitle: Text('成长日记 v1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.orange),
            title: const Text('清除缓存'),
            subtitle: const Text('清除已下载的媒体文件缓存'),
            onTap: _clearCache,
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('重新配置'),
            onTap: _resetConfiguration,
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
