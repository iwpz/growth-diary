import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/local_storage_service.dart';
import '../services/webdav_service.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _webdavUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _childNameController = TextEditingController();
  DateTime? _childBirthDate;
  bool _isLoading = false;

  final LocalStorageService _localStorage = LocalStorageService();
  final WebDAVService _webdavService = WebDAVService();

  @override
  void dispose() {
    _webdavUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _childNameController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '选择宝宝生日',
    );
    if (picked != null) {
      setState(() {
        _childBirthDate = picked;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_childBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择宝宝生日')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final config = AppConfig(
        webdavUrl: _webdavUrlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        childBirthDate: _childBirthDate,
        childName: _childNameController.text.trim(),
      );

      // Initialize WebDAV
      await _webdavService.initialize(config);

      // Save config to WebDAV
      await _webdavService.saveConfig(config);

      // Save config locally
      await _localStorage.saveConfig(config);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            config: config,
            webdavService: _webdavService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('配置失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('初始设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.child_care,
                size: 80,
                color: Colors.pink,
              ),
              const SizedBox(height: 20),
              const Text(
                '欢迎使用成长日记',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                '记录宝宝的每一个珍贵瞬间',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const Text(
                '宝宝信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _childNameController,
                decoration: const InputDecoration(
                  labelText: '宝宝昵称',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.baby_changing_station),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入宝宝昵称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              InkWell(
                onTap: _selectBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '宝宝生日',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake),
                  ),
                  child: Text(
                    _childBirthDate != null
                        ? '${_childBirthDate!.year}-${_childBirthDate!.month.toString().padLeft(2, '0')}-${_childBirthDate!.day.toString().padLeft(2, '0')}'
                        : '点击选择日期',
                    style: TextStyle(
                      color:
                          _childBirthDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'WebDAV 配置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _webdavUrlController,
                decoration: const InputDecoration(
                  labelText: 'WebDAV URL',
                  hintText: 'https://example.com/webdav',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cloud),
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
              const SizedBox(height: 15),
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
              const SizedBox(height: 15),
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
              ElevatedButton(
                onPressed: _isLoading ? null : _saveConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '完成设置',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
