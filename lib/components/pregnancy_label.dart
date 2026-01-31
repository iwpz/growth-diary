import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_config.dart';

class PregnancyLabel extends StatelessWidget {
  final AppConfig config;

  const PregnancyLabel({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Timeline indicator for pregnancy
        SizedBox(
          width: 60,
          child: Column(
            children: [
              // Pregnancy icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.pink.shade300, Colors.pink.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pregnant_woman,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Pregnancy label
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.pink.shade200,
                width: 1,
              ),
            ),
            child: Text(
              '怀孕啦！${DateFormat('yyyy年M月d日').format(config.conceptionDate!)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
