import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/entry_creation_service.dart';
import '../services/webdav_service.dart';

class DiaryEditorScreen extends StatefulWidget {
  final AppConfig config;
  final WebDAVService webdavService;

  const DiaryEditorScreen({
    super.key,
    required this.config,
    required this.webdavService,
  });

  @override
  State<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends State<DiaryEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  late final EntryCreationService _entryService;

  @override
  void initState() {
    super.initState();
    _entryService = EntryCreationService(widget.webdavService);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveDiary() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少输入标题或内容')),
      );
      return;
    }

    try {
      await _entryService.createDiaryEntry(title, content, widget.config);
      Navigator.of(context).pop(); // 返回上一页
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存日记失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加日记'),
        actions: [
          TextButton(
            onPressed: _saveDiary,
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '输入日记标题（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '内容',
                  hintText: '写下你的日记内容...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveDiary,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                ),
                child: const Text('就这样吧'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
