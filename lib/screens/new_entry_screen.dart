import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../models/app_config.dart';
import '../models/diary_entry.dart';
import '../services/webdav_service.dart';
import '../utils/age_calculator.dart';

class NewEntryScreen extends StatefulWidget {
  final AppConfig config;
  final WebDAVService webdavService;
  final DiaryEntry? existingEntry;

  const NewEntryScreen({
    super.key,
    required this.config,
    required this.webdavService,
    this.existingEntry,
  });

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  final List<File> _selectedImages = [];
  final List<File> _selectedVideos = [];
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _titleController.text = widget.existingEntry!.title;
      _descriptionController.text = widget.existingEntry!.description;
      _selectedDate = widget.existingEntry!.date;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: widget.config.childBirthDate!,
      lastDate: DateTime.now(),
      helpText: '选择日期',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      setState(() {
        _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedVideos.add(File(video.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择视频失败: $e')),
        );
      }
    }
  }

  int _calculateAgeInMonths(DateTime date) {
    final birthDate = widget.config.childBirthDate!;
    return AgeCalculator.calculateAgeInMonths(birthDate, date);
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload media files
      final List<String> imagePaths = [];
      final List<String> videoPaths = [];

      for (var image in _selectedImages) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
        final uploadedPath = await widget.webdavService.uploadMedia(image, fileName);
        imagePaths.add(uploadedPath);
      }

      for (var video in _selectedVideos) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(video.path)}';
        final uploadedPath = await widget.webdavService.uploadMedia(video, fileName);
        videoPaths.add(uploadedPath);
      }

      final entry = DiaryEntry(
        id: widget.existingEntry?.id,
        date: _selectedDate!,
        title: _titleController.text,
        description: _descriptionController.text,
        imagePaths: imagePaths,
        videoPaths: videoPaths,
        ageInMonths: _calculateAgeInMonths(_selectedDate!),
      );

      await widget.webdavService.saveDiaryEntry(entry);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
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
        title: Text(widget.existingEntry != null ? '编辑记录' : '新建记录'),
        backgroundColor: Colors.pink.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveEntry,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '日期',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDate != null
                              ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                              : '选择日期',
                        ),
                      ),
                    ),
                    if (_selectedDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '宝宝年龄: ${DiaryEntry(date: _selectedDate!, title: '', ageInMonths: _calculateAgeInMonths(_selectedDate!)).getAgeLabel()}',
                        style: TextStyle(
                          color: Colors.pink.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入标题';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '描述',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.photo),
                            label: const Text('添加照片'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink.shade50,
                              foregroundColor: Colors.pink.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickVideo,
                            icon: const Icon(Icons.videocam),
                            label: const Text('添加视频'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade50,
                              foregroundColor: Colors.purple.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '已选择的照片:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedImages.asMap().entries.map((entry) {
                          final index = entry.key;
                          final image = entry.value;
                          return Stack(
                            children: [
                              Image.file(
                                image,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedImages.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                    if (_selectedVideos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '已选择的视频:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: _selectedVideos.asMap().entries.map((entry) {
                          final index = entry.key;
                          final video = entry.value;
                          return ListTile(
                            leading: const Icon(Icons.videocam),
                            title: Text(path.basename(video.path)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _selectedVideos.removeAt(index);
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
