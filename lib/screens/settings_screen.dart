import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../models/app_config.dart';
import '../services/webdav_service.dart';
import '../services/local_storage_service.dart';
import 'setup_screen.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppConfig config;
  final WebDAVService webdavService;
  final Function(AppConfig) onConfigChanged;

  const SettingsScreen({
    super.key,
    required this.config,
    required this.webdavService,
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
    String newName = _config.childName;
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
      setState(() {
        _config = _config.copyWith(childName: newName);
      });
      await _localStorage.saveConfig(_config);
      await widget.webdavService.saveConfig(_config);
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
      initialDate: _config.childBirthDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _config = _config.copyWith(childBirthDate: picked);
      });
      await _localStorage.saveConfig(_config);
      await widget.webdavService.saveConfig(_config);
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
      initialDate: _config.conceptionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _config = _config.copyWith(conceptionDate: picked);
      });
      await _localStorage.saveConfig(_config);
      await widget.webdavService.saveConfig(_config);
      widget.onConfigChanged(_config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('受孕日已更新')),
        );
      }
    }
  }

  Future<void> _testWebDAVConnection(
      String url, String username, String password) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 WebDAV URL')),
      );
      return;
    }

    try {
      final client = webdav.newClient(
        url,
        user: username,
        password: password,
        debug: true,
      );
      client.setConnectTimeout(5000);
      client.setSendTimeout(5000);
      client.setReceiveTimeout(5000);

      // 尝试 ping 服务器来测试连接
      await client.ping();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接成功！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接失败！请检查配置')),
        );
        print('WebDAV connection test failed: $e');
      }
    }
  }

  Future<void> _showWebDAVSettings() async {
    String url = _config.webdavUrl;
    String username = _config.username;
    String password = _config.password;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('WebDAV 配置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: url),
                  onChanged: (value) => url = value,
                  decoration: const InputDecoration(
                    labelText: 'WebDAV URL',
                    hintText: 'https://example.com/webdav',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: username),
                  onChanged: (value) => username = value,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: password),
                  onChanged: (value) => password = value,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await _testWebDAVConnection(url, username, password);
                  },
                  child: const Text('测试连接'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      // 检查是否有变化
      if (url != _config.webdavUrl ||
          username != _config.username ||
          password != _config.password) {
        // 确认修改
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认修改'),
            content: const Text('修改 WebDAV 配置将迁移数据到新路径。确定继续吗？'),
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
          // 更新配置
          final updatedConfig = _config.copyWith(
            webdavUrl: url,
            username: username,
            password: password,
          );
          await _localStorage.saveConfig(updatedConfig);

          // 创建新的 WebDAV 客户端并保存配置到新路径
          final newClient = webdav.newClient(
            url,
            user: username,
            password: password,
            debug: true,
          );
          newClient.setConnectTimeout(8000);
          newClient.setSendTimeout(8000);
          newClient.setReceiveTimeout(8000);

          try {
            // 创建目录
            await newClient.mkdir('growth_diary');
            // 保存配置
            final configJson = jsonEncode(updatedConfig.toJson());
            await newClient.write(
                'growth_diary/config.json', utf8.encode(configJson));
          } catch (e) {
            // 如果保存失败，显示错误但仍继续
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('保存配置到新路径失败: $e')),
              );
            }
          }

          // 创建新的 WebDAV 服务并导航到 HomeScreen
          final newWebDAVService = WebDAVService();
          await newWebDAVService.initialize(updatedConfig);

          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  config: updatedConfig,
                  webdavService: newWebDAVService,
                ),
              ),
              (route) => false,
            );
          }
        }
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
            subtitle:
                Text('${widget.config.webdavUrl} (${widget.config.username})'),
            trailing: const Icon(Icons.settings),
            onTap: _showWebDAVSettings,
          ),
          const Divider(),
          _buildSection('应用'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('关于'),
            subtitle: Text('成长日记 v1.0.0'),
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
