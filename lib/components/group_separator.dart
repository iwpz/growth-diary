import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../models/diary_entry.dart';

class GroupSeparator extends StatelessWidget {
  final DiaryEntry representativeEntry;
  final bool isFirstGroup;
  final bool isLastGroup;
  final bool isPregnancyPeriod;
  final AppConfig config;

  const GroupSeparator({
    super.key,
    required this.representativeEntry,
    required this.isFirstGroup,
    required this.isLastGroup,
    required this.isPregnancyPeriod,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final groupValue = representativeEntry.getGroupKey(config);
    final displayValue = isPregnancyPeriod
        ? groupValue
        : (groupValue < 0 ? -groupValue : groupValue);
    final displayText = isPregnancyPeriod
        ? '$displayValue'
        : (groupValue < 0 ? '前$displayValue' : '$displayValue');
    final labelText = isPregnancyPeriod
        ? '孕期 $displayValue 周'
        : representativeEntry.getSimplifiedAgeLabel(config.childBirthDate);

    return Row(
      children: [
        // Timeline indicator for group
        SizedBox(
          width: 60,
          child: Column(
            children: [
              // Top line (only if not first group)
              Container(
                width: 2,
                height: 24,
                color: Colors.pink.shade200,
              ),

              // Group circle
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
                child: Center(
                  child: Text(
                    displayText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Bottom line (only if not last group)
              Container(
                width: 2,
                height: 24,
                color: Colors.pink.shade200,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Group label
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.pink.shade200,
                width: 1,
              ),
            ),
            child: Text(
              labelText,
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