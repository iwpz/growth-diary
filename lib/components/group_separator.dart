import 'package:flutter/material.dart';
import 'package:growth_diary/utils/age_calculator.dart';
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
    final displayText = AgeCalculator.formatSimplifiedAgeLabel(
        representativeEntry.date, config);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.pink.shade200,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 12,
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
