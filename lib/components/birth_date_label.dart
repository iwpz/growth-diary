import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_config.dart';

class BirthDateLabel extends StatelessWidget {
  final AppConfig config;
  final bool showBottomLine;

  const BirthDateLabel({
    super.key,
    required this.config,
    this.showBottomLine = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.blue.shade200,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '出生啦！${DateFormat('yyyy年M月d日').format(config.childBirthDate ?? DateTime.now())}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.blue.shade200,
            ),
          ),
        ],
      ),
    );
  }
}
