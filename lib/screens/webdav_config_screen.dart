import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../models/app_config.dart';
import '../services/webdav_service.dart';
import '../services/local_storage_service.dart';

enum WebDAVConfigMode {
  setup, // 初始设置模式，返回配置结果
  settings, // 设置页面模式，通过回调更新
}

class WebDAVConfigScreen extends StatefulWidget {
  final WebDAVConfigMode mode;
  final AppConfig? config; // setup模式下可为null，settings模式下必填
  final WebDAVService? webdavService; // settings模式下需要
  final Function(AppConfig)? onConfigChanged; // settings模式下的回调

  const WebDAVConfigScreen({
    super.key,
    required this.mode,
    this.config,
    this.webdavService,
    this.onConfigChanged,
  }) : assert(
            (mode == WebDAVConfigMode.setup) ||
                (mode == WebDAVConfigMode.settings &&
                    config != null &&
                    webdavService != null &&
                    onConfigChanged != null),
            'Invalid configuration for WebDAVConfigScreen');

  @override
  State<WebDAVConfigScreen> createState() => _WebDAVConfigScreenState();
}

class _WebDAVConfigScreenState extends State<WebDAVConfigScreen> {
  final LocalStorageService _localStorage = LocalStorageService();
  final _formKey = GlobalKey<FormState>();
  late AppConfig _config;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    _config = widget.config ?? AppConfig();
    _urlController.text = _config.webdavUrl;
    _usernameController.text = _config.username;
    _passwordController.text = _config.password;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testWebDAVConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
    });

    try {
      final url = _urlController.text.trim();
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      final client = webdav.newClient(
        url,
        user: username,
        password: password,
        debug: true,
      );
      client.setConnectTimeout(8000);
      client.setSendTimeout(8000);
      client.setReceiveTimeout(8000);

      // Test connection by listing directory
      await client.readDir('/');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('连接测试成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接测试失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newConfig = _config.copyWith(
      webdavUrl: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (widget.mode == WebDAVConfigMode.settings) {
      // Settings模式：保存到本地和服务，调用回调
      await _localStorage.saveConfig(newConfig);
      await widget.webdavService!.initialize(newConfig);
      await widget.webdavService!.saveConfig(newConfig);
      widget.onConfigChanged!(newConfig);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // Setup模式：返回配置结果
      Navigator.of(context).pop(newConfig);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSetupMode = widget.mode == WebDAVConfigMode.setup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV 配置'),
        actions: null, // 统一使用底部按钮，不在AppBar显示
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.cloud,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                isSetupMode ? '配置云存储' : '修改WebDAV设置',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isSetupMode ? '设置WebDAV连接以同步您的成长日记数据' : '修改WebDAV连接配置',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'WebDAV URL',
                  hintText: 'https://example.com/webdav',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 WebDAV URL';
                  }
                  if (!value.startsWith('http')) {
                    return '请输入有效的 URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入用户名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isTestingConnection ? null : _testWebDAVConnection,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isTestingConnection
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('测试连接'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('保存配置'),
                    ),
                  ),
                ],
              ),
              if (!isSetupMode) ...[
                const SizedBox(height: 16),
                const Text(
                  '注意：修改配置后，数据将迁移到新的存储路径。',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
