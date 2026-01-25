import 'package:uuid/uuid.dart';
import '../utils/age_calculator.dart';

class DiaryEntry {
  final String id;
  final DateTime date;
  final String title;
  final String description;
  final List<String> imagePaths;
  final List<String> videoPaths;
  final int ageInMonths;

  DiaryEntry({
    String? id,
    required this.date,
    required this.title,
    this.description = '',
    this.imagePaths = const [],
    this.videoPaths = const [],
    required this.ageInMonths,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'description': description,
      'imagePaths': imagePaths,
      'videoPaths': videoPaths,
      'ageInMonths': ageInMonths,
    };
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'],
      date: DateTime.parse(json['date']),
      title: json['title'],
      description: json['description'] ?? '',
      imagePaths: List<String>.from(json['imagePaths'] ?? []),
      videoPaths: List<String>.from(json['videoPaths'] ?? []),
      ageInMonths: json['ageInMonths'],
    );
  }

  String getAgeLabel() {
    return AgeCalculator.formatAgeLabel(ageInMonths);
  }
}
