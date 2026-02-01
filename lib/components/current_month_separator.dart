import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../utils/age_calculator.dart';

class CurrentMonthSeparator extends StatelessWidget {
  final AppConfig config;

  const CurrentMonthSeparator({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final currentDate = DateTime.now();
    final birthDate = config.childBirthDate;
    if (birthDate == null) {
      return const SizedBox.shrink(); // Or some default
    }
    final ageLabel = AgeCalculator.formatDetailedAgeLabel(currentDate, config);

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cake,
                  color: Colors.pink.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '宝宝$ageLabel啦',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.celebration,
                  color: Colors.pink.shade600,
                  size: 20,
                ),
              ],
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
