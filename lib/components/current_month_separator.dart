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
    final ageLabel =
        AgeCalculator.formatSimplifiedAgeLabel(birthDate, currentDate);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 气泡背景
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.pink.shade200,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          // 内容
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cake,
                color: Colors.pink.shade600,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                '宝宝现在$ageLabel啦',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink.shade800,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.celebration,
                color: Colors.pink.shade600,
                size: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
