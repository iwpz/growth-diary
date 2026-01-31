import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/local_storage_service.dart';
import '../services/webdav_service.dart';
import 'home_screen.dart';
import 'webdav_config_screen.dart';

class SetupScreen extends StatefulWidget {
  final LocalStorageService? localStorage;

  const SetupScreen({super.key, this.localStorage});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _childNameController = TextEditingController();
  DateTime? _childBirthDate;
  DateTime? _conceptionDate;
  bool _isLoading = false;
  bool _isPregnant = false; // false = 已出生, true = 怀孕中
  AppConfig? _webdavConfig;

  final WebDAVService _webdavService = WebDAVService();

  @override
  void dispose() {
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

  Future<void> _selectConceptionDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 280)), // 预产期大约280天
      helpText: '选择受孕日期',
    );
    if (picked != null) {
      setState(() {
        _conceptionDate = picked;
      });
    }
  }

  Future<void> _configureWebDAV() async {
    final result = await Navigator.of(context).push<AppConfig>(
      MaterialPageRoute(
        builder: (context) => WebDAVConfigScreen(
          mode: WebDAVConfigMode.setup,
          config: _webdavConfig,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _webdavConfig = result;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isPregnant) {
      if (_conceptionDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择受孕日期')),
        );
        return;
      }
    } else {
      if (_childBirthDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择宝宝生日')),
        );
        return;
      }
    }

    if (_webdavConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置WebDAV')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final config = AppConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        webdavUrl: _webdavConfig!.webdavUrl,
        username: _webdavConfig!.username,
        password: _webdavConfig!.password,
        babyName: _childNameController.text.trim(),
        babyBirthDate: _isPregnant ? null : _childBirthDate,
        babyConceptionDate: _isPregnant ? _conceptionDate : null,
      );

      // Initialize WebDAV
      await _webdavService.initialize(config);

      // Save config to WebDAV
      await _webdavService.saveConfig(config);

      // Save config locally
      final localStorage = widget.localStorage ?? LocalStorageService();
      await localStorage.saveConfig(config);
      await localStorage.setCurrentConfigId(config.id);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            configs: {config.id: config},
            currentConfigId: config.id,
            cloudService: _webdavService,
            localStorage: localStorage,
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
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    // 已出生选项
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isPregnant = false;
                            _conceptionDate = null; // 清除受孕日期
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: !_isPregnant
                                ? Colors.pink.shade50
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cake,
                                color: !_isPregnant ? Colors.pink : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '已出生',
                                style: TextStyle(
                                  color:
                                      !_isPregnant ? Colors.pink : Colors.grey,
                                  fontWeight: !_isPregnant
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 怀孕中选项
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isPregnant = true;
                            _childBirthDate = null; // 清除生日
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _isPregnant
                                ? Colors.pink.shade50
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pregnant_woman,
                                color: _isPregnant ? Colors.pink : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '怀孕中',
                                style: TextStyle(
                                  color:
                                      _isPregnant ? Colors.pink : Colors.grey,
                                  fontWeight: _isPregnant
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
              if (_isPregnant)
                InkWell(
                  onTap: _selectConceptionDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '受孕日期',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pregnant_woman),
                    ),
                    child: Text(
                      _conceptionDate != null
                          ? '${_conceptionDate!.year}-${_conceptionDate!.month.toString().padLeft(2, '0')}-${_conceptionDate!.day.toString().padLeft(2, '0')}'
                          : '点击选择日期',
                      style: TextStyle(
                        color: _conceptionDate != null
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ),
                )
              else
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
                        color: _childBirthDate != null
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              const Text(
                '云存储配置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud,
                          color:
                              _webdavConfig != null ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _webdavConfig != null
                                ? 'WebDAV 已配置 (${_webdavConfig!.webdavUrl})'
                                : '未配置云存储',
                            style: TextStyle(
                              color: _webdavConfig != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _configureWebDAV,
                          child: Text(_webdavConfig != null ? '修改配置' : '配置'),
                        ),
                      ],
                    ),
                  ],
                ),
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
