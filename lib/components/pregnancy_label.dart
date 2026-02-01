import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_config.dart';

class PregnancyLabel extends StatelessWidget {
  final AppConfig config;

  const PregnancyLabel({super.key, required this.config});

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
              color: Colors.pink.shade200,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '怀孕啦！${DateFormat('yyyy年M月d日').format(config.conceptionDate!)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade700,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.pink.shade200,
            ),
          ),
        ],
      ),
    );
  }
}
