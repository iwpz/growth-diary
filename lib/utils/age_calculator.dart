class AgeCalculator {
  /// Average days per month used for age calculation
  /// 365.25 days/year ÷ 12 months ≈ 30.44 days/month
  static const double averageDaysPerMonth = 30.44;

  /// Calculates the age in months from birth date to the given date
  static int calculateAgeInMonths(DateTime birthDate, DateTime currentDate) {
    final diff = currentDate.difference(birthDate);
    return (diff.inDays / averageDaysPerMonth).floor().clamp(0, double.infinity).toInt();
  }

  /// Formats age in months to a human-readable Chinese label
  static String formatAgeLabel(int ageInMonths) {
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
}
