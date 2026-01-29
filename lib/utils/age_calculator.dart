class AgeCalculator {
  /// Average days per month used for age calculation
  /// 365.25 days/year ÷ 12 months ≈ 30.44 days/month
  static const double averageDaysPerMonth = 30.44;

  /// Calculates the age in months from birth date to the given date
  static int calculateAgeInMonths(DateTime birthDate, DateTime currentDate) {
    final diff = currentDate.difference(birthDate);
    return (diff.inDays / averageDaysPerMonth).floor().toInt();
  }

  /// Calculates the detailed age (years, months, days) from birth date to the given date
  static Map<String, int> calculateDetailedAge(
      DateTime birthDate, DateTime currentDate) {
    int years = currentDate.year - birthDate.year;
    int months = currentDate.month - birthDate.month;
    int days = currentDate.day - birthDate.day;

    // Adjust for negative months
    if (months < 0) {
      years--;
      months += 12;
    }

    // Adjust for negative days
    if (days < 0) {
      months--;
      if (months < 0) {
        years--;
        months += 12;
      }

      // Calculate days in previous month
      DateTime previousMonth =
          DateTime(currentDate.year, currentDate.month - 1, 1);
      int daysInPreviousMonth =
          DateTime(previousMonth.year, previousMonth.month + 1, 0).day;
      days += daysInPreviousMonth;
    }

    return {
      'years': years.clamp(0, double.infinity).toInt(),
      'months': months.clamp(0, 11), // 0-11 months
      'days': days.clamp(0, double.infinity).toInt(),
    };
  }

  /// Formats age in months to a human-readable Chinese label with days
  static String formatAgeLabel(int ageInMonths) {
    // For backward compatibility, if we only have months, show approximate
    if (ageInMonths == 0) {
      return '出生';
    } else if (ageInMonths < 12) {
      return '$ageInMonths月龄';
    } else {
      int years = ageInMonths ~/ 12;
      int months = ageInMonths % 12;
      if (months == 0) {
        return '$years岁';
      } else {
        return '$years岁$months月';
      }
    }
  }

  /// Formats detailed age (years, months, days) to a human-readable Chinese label
  static String formatDetailedAgeLabel(
      DateTime birthDate, DateTime currentDate) {
    final age = calculateDetailedAge(birthDate, currentDate);
    final years = age['years']!;
    final months = age['months']!;
    final days = age['days']!;

    if (years == 0 && months == 0 && days == 0) {
      return '出生';
    } else if (years == 0 && months == 0) {
      return '$days天';
    } else if (years == 0) {
      return '$months个月$days天';
    } else {
      return '$years岁$months个月$days天';
    }
  }

  /// Formats age to a simplified Chinese label (years and months only, no days)
  static String formatSimplifiedAgeLabel(
      DateTime birthDate, DateTime currentDate) {
    int ageInMonths = calculateAgeInMonths(birthDate, currentDate);
    if (ageInMonths < 0) {
      return '出生前 ${-ageInMonths} 月';
    }
    final age = calculateDetailedAge(birthDate, currentDate);
    final years = age['years']!;
    final months = age['months']!;

    if (years == 0 && months == 0) {
      return '出生';
    } else if (years == 0) {
      return '$months个月';
    } else {
      return '$years岁$months个月';
    }
  }
}
