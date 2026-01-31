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
    final currentAgeInMonths =
        AgeCalculator.calculateAgeInMonths(birthDate, currentDate);
    final ageLabel =
        AgeCalculator.formatDetailedAgeLabel(birthDate, currentDate);

    return Row(
      children: [
        // Timeline indicator for current month
        SizedBox(
          width: 60,
          child: Column(
            children: [
              // Month circle
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
                    '$currentAgeInMonths',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Bottom line
              Container(
                width: 2,
                height: 24,
                color: Colors.pink.shade200,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Age label
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
              ageLabel,
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