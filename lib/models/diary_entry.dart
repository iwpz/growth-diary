import 'package:uuid/uuid.dart';
import '../utils/age_calculator.dart';
import 'app_config.dart';

class DiaryEntry {
  final String id;
  final DateTime date;
  final String title;
  final String description;
  final List<String> imagePaths;
  final List<String> videoPaths;
  final List<String> imageThumbnails; // 小号缩略图，用于时间轴
  final List<String> videoThumbnails; // 小号缩略图，用于时间轴
  final int ageInMonths;

  DiaryEntry({
    String? id,
    required this.date,
    required this.title,
    this.description = '',
    this.imagePaths = const [],
    this.videoPaths = const [],
    this.imageThumbnails = const [],
    this.videoThumbnails = const [],
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
      'imageThumbnails': imageThumbnails,
      'videoThumbnails': videoThumbnails,
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
      imageThumbnails: List<String>.from(json['imageThumbnails'] ?? []),
      videoThumbnails: List<String>.from(json['videoThumbnails'] ?? []),
      ageInMonths: json['ageInMonths'],
    );
  }

  String getAgeLabel(AppConfig? config) {
    if (config != null) {
      return AgeCalculator.formatDetailedAgeLabel(date, config);
    } else {
      return AgeCalculator.formatAgeLabel(ageInMonths);
    }
  }

  String getSimplifiedAgeLabel(AppConfig config) {
    if (config.childBirthDate != null) {
      return AgeCalculator.formatSimplifiedAgeLabel(date, config);
    } else {
      return AgeCalculator.formatAgeLabel(ageInMonths);
    }
  }

  int getGroupKey(AppConfig config) {
    if (config.conceptionDate != null &&
        date.isBefore(config.childBirthDate ?? DateTime.now())) {
      return AgeCalculator.calculateWeeksDifference(
          config.conceptionDate!, date);
    } else {
      return AgeCalculator.calculateDateDifference(
          config.childBirthDate!, date)['months']!;
    }
  }
}

/// 详情页返回结果
class EntryDetailResult {
  final bool isDeleted;
  final DiaryEntry? updatedEntry;

  const EntryDetailResult({
    this.isDeleted = false,
    this.updatedEntry,
  });

  factory EntryDetailResult.updated(DiaryEntry entry) {
    return EntryDetailResult(isDeleted: false, updatedEntry: entry);
  }

  factory EntryDetailResult.deleted() {
    return const EntryDetailResult(isDeleted: true, updatedEntry: null);
  }
}
