import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/webdav_service.dart';
import '../services/local_storage_service.dart';
import 'setup_screen.dart';

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

  Future<void> _showEditBirthDateDialog() async {
    DateTime? newBirthDate = _config.childBirthDate;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('修改宝宝生日'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: newBirthDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => newBirthDate = picked);
                  }
                },
                child: Text(
                  newBirthDate != null
                      ? '${newBirthDate!.year}-${newBirthDate!.month.toString().padLeft(2, '0')}-${newBirthDate!.day.toString().padLeft(2, '0')}'
                      : '选择生日',
                ),
              ),
            ],
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
      ),
    );
    if (result == true && newBirthDate != null) {
      setState(() {
        _config = _config.copyWith(childBirthDate: newBirthDate);
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

  Future<void> _showEditConceptionDateDialog() async {
    DateTime? newConceptionDate = _config.conceptionDate;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('修改受孕日'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: newConceptionDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => newConceptionDate = picked);
                  }
                },
                child: Text(
                  newConceptionDate != null
                      ? '${newConceptionDate!.year}-${newConceptionDate!.month.toString().padLeft(2, '0')}-${newConceptionDate!.day.toString().padLeft(2, '0')}'
                      : '选择受孕日',
                ),
              ),
            ],
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
      ),
    );
    if (result == true && newConceptionDate != null) {
      setState(() {
        _config = _config.copyWith(conceptionDate: newConceptionDate);
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
          Dismissible(
            key: const Key('childName'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              _showEditChildNameDialog();
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.blue,
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            child: ListTile(
              leading: const Icon(Icons.baby_changing_station),
              title: const Text('宝宝昵称'),
              subtitle: Text(_config.childName),
            ),
          ),
          Dismissible(
            key: const Key('childBirthDate'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              _showEditBirthDateDialog();
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.blue,
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            child: ListTile(
              leading: const Icon(Icons.cake),
              title: const Text('宝宝生日'),
              subtitle: Text(
                _config.childBirthDate != null
                    ? '${_config.childBirthDate!.year}-${_config.childBirthDate!.month.toString().padLeft(2, '0')}-${_config.childBirthDate!.day.toString().padLeft(2, '0')}'
                    : '未设置',
              ),
            ),
          ),
          Dismissible(
            key: const Key('conceptionDate'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              _showEditConceptionDateDialog();
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.blue,
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            child: ListTile(
              leading: const Icon(Icons.pregnant_woman),
              title: const Text('受孕日'),
              subtitle: Text(
                _config.conceptionDate != null
                    ? '${_config.conceptionDate!.year}-${_config.conceptionDate!.month.toString().padLeft(2, '0')}-${_config.conceptionDate!.day.toString().padLeft(2, '0')}'
                    : '未设置',
              ),
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
