import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/webdav_service.dart';
import '../services/local_storage_service.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppConfig config;
  final WebDAVService webdavService;

  const SettingsScreen({
    super.key,
    required this.config,
    required this.webdavService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalStorageService _localStorage = LocalStorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.pink.shade100,
      ),
      body: ListView(
        children: [
          _buildSection('宝宝信息'),
          ListTile(
            leading: const Icon(Icons.baby_changing_station),
            title: const Text('宝宝昵称'),
            subtitle: Text(widget.config.childName),
          ),
          ListTile(
            leading: const Icon(Icons.cake),
            title: const Text('宝宝生日'),
            subtitle: Text(
              widget.config.childBirthDate != null
                  ? '${widget.config.childBirthDate!.year}-${widget.config.childBirthDate!.month.toString().padLeft(2, '0')}-${widget.config.childBirthDate!.day.toString().padLeft(2, '0')}'
                  : '未设置',
            ),
          ),
          const Divider(),
          _buildSection('WebDAV 配置'),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('WebDAV URL'),
            subtitle: Text(widget.config.webdavUrl),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('用户名'),
            subtitle: Text(widget.config.username),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('同步状态'),
            subtitle: Text(
              widget.webdavService.isInitialized ? '已连接' : '未连接',
            ),
            trailing: widget.webdavService.isInitialized
                ? Icon(Icons.check_circle, color: Colors.green.shade400)
                : Icon(Icons.error, color: Colors.red.shade400),
          ),
          const Divider(),
          _buildSection('应用'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            subtitle: const Text('成长日记 v1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('重新配置'),
            onTap: () async {
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
                await _localStorage.clearConfig();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const SetupScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
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
