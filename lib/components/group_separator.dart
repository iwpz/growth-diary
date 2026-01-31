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
        : (groupValue < 0 ? -groupValue + 1 : groupValue);
    final displayText = isPregnancyPeriod
        ? '孕$displayValue周'
        : (groupValue < 0 ? '前$displayValue月' : '$displayValue月');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.pink.shade700,
        ),
      ),
    );
  }
}
