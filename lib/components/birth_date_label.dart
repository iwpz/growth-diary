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
    return Row(
      children: [
        // Timeline indicator for birth date
        SizedBox(
          width: 60,
          child: Column(
            children: [
              // Birth icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade300, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.child_care,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              // Bottom line
              if (showBottomLine)
                Container(
                  width: 2,
                  height: 24,
                  color: Colors.pink.shade200,
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Birth date label
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.blue.shade200,
                width: 1,
              ),
            ),
            child: Text(
              '出生啦！${DateFormat('yyyy年M月d日').format(config.childBirthDate ?? DateTime.now())}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
