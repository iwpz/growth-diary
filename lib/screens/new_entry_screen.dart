import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_config.dart';
import '../models/diary_entry.dart';
import '../services/webdav_service.dart';
import '../services/entry_creation_service.dart';

class NewEntryScreen extends StatefulWidget {
  final AppConfig config;
  final WebDAVService webdavService;
  final DiaryEntry? existingEntry;
  final String? initialMode; // 'media' or 'text'

  const NewEntryScreen({
    super.key,
    required this.config,
    required this.webdavService,
    this.existingEntry,
    this.initialMode,
  });

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  late final EntryCreationService _entryService;

  @override
  void initState() {
    super.initState();
    _entryService = EntryCreationService(widget.webdavService);
    // 如果有初始模式，直接执行
    if (widget.initialMode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.initialMode == 'media') {
          _addMediaEntry();
        } else if (widget.initialMode == 'text') {
          _addTextEntry();
        }
      });
    }
  }

  Future<String?> _showDescriptionDialog() async {
    String description = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加描述（可选）'),
        content: TextField(
          onChanged: (value) => description = value,
          decoration: const InputDecoration(hintText: '请输入描述'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(description),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showTextDialog() async {
    String text = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入文本记录'),
        content: TextField(
          onChanged: (value) => text = value,
          decoration: const InputDecoration(hintText: '请输入文本'),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMediaEntry() async {
    try {
      final List<XFile> media = await _picker.pickMultipleMedia();
      if (media.isEmpty) return;

      final String? description = await _showDescriptionDialog();
      if (description == null) return;

      setState(() => _isLoading = true);

      await _entryService.createMediaEntry(media, description, widget.config);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加媒体记录失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addTextEntry() async {
    try {
      final String? text = await _showTextDialog();
      if (text == null || text.isEmpty) return;

      setState(() => _isLoading = true);

      await _entryService.createTextEntry(text, widget.config);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加文本记录失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建记录'),
        backgroundColor: Colors.pink.shade100,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _addMediaEntry,
                    icon: const Icon(Icons.perm_media),
                    label: const Text('添加媒体'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade50,
                      foregroundColor: Colors.pink.shade700,
                      minimumSize: const Size(double.infinity, 60),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addTextEntry,
                    icon: const Icon(Icons.text_fields),
                    label: const Text('添加文本'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      minimumSize: const Size(double.infinity, 60),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
