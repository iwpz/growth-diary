import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../services/webdav_service.dart';

class EntryDetailScreen extends StatelessWidget {
  final DiaryEntry entry;
  final WebDAVService webdavService;

  const EntryDetailScreen({
    super.key,
    required this.entry,
    required this.webdavService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
        backgroundColor: Colors.pink.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认删除'),
                  content: const Text('确定要删除这条记录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('删除', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await webdavService.deleteEntry(entry.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('删除失败: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.getAgeLabel(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.child_care,
                    size: 60,
                    color: Colors.pink.shade200,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '标题',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (entry.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                '描述',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.description,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
            if (entry.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                '照片',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${entry.imagePaths.length} 张照片（存储在 WebDAV）',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: entry.imagePaths.length,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  );
                },
              ),
            ],
            if (entry.videoPaths.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                '视频',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${entry.videoPaths.length} 个视频（存储在 WebDAV）',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: entry.videoPaths.asMap().entries.map((videoEntry) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.videocam, color: Colors.purple),
                      title: Text('视频 ${videoEntry.key + 1}'),
                      subtitle: Text(videoEntry.value),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
