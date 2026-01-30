import 'package:uuid/uuid.dart';

class Baby {
  String id;
  String name;
  DateTime? birthDate;
  DateTime? conceptionDate;

  Baby({
    this.id = '',
    this.name = '',
    this.birthDate,
    this.conceptionDate,
  }) {
    if (id.isEmpty) {
      id = const Uuid().v4();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'birthDate': birthDate?.toIso8601String(),
      'conceptionDate': conceptionDate?.toIso8601String(),
    };
  }

  factory Baby.fromJson(Map<String, dynamic> json) {
    return Baby(
      id: json['id'] ?? const Uuid().v4(),
      name: json['name'] ?? '',
      birthDate:
          json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      conceptionDate: json['conceptionDate'] != null
          ? DateTime.parse(json['conceptionDate'])
          : null,
    );
  }

  // 获取年龄标签的辅助方法
  String getAgeLabel() {
    if (birthDate == null) return name;
    final now = DateTime.now();
    final ageInMonths = _calculateAgeInMonths(birthDate!, now);
    if (ageInMonths < 0) {
      // 还没出生，显示孕期
      final weeks = (-ageInMonths * 4.33).round();
      return '$name (孕$weeks周)';
    } else {
      // 已出生，显示月龄
      return '$name ($ageInMonths个月)';
    }
  }

  int _calculateAgeInMonths(DateTime birthDate, DateTime currentDate) {
    int months = (currentDate.year - birthDate.year) * 12 +
        currentDate.month -
        birthDate.month;
    if (currentDate.day < birthDate.day) {
      months--;
    }
    return months;
  }
}

class AppConfig {
  String id;
  String webdavUrl;
  String username;
  String password;
  String babyName;
  DateTime? babyBirthDate;
  DateTime? babyConceptionDate;

  AppConfig({
    this.id = '',
    this.webdavUrl = '',
    this.username = '',
    this.password = '',
    this.babyName = '',
    this.babyBirthDate,
    this.babyConceptionDate,
  }) {
    if (id.isEmpty) {
      id = const Uuid().v4();
    }
  }

  // 检查配置是否完整
  bool get isConfigured {
    return webdavUrl.isNotEmpty && username.isNotEmpty && babyName.isNotEmpty;
  }

  // 向后兼容的getter
  String get childName => babyName;
  DateTime? get childBirthDate => babyBirthDate;
  DateTime? get conceptionDate => babyConceptionDate;

  // 获取年龄标签
  String getAgeLabel() {
    if (babyBirthDate == null) return babyName;
    final now = DateTime.now();
    final ageInMonths = _calculateAgeInMonths(babyBirthDate!, now);
    if (ageInMonths < 0) {
      // 还没出生，显示孕期
      final weeks = (-ageInMonths * 4.33).round();
      return '$babyName (孕$weeks周)';
    } else {
      // 已出生，显示月龄
      return '$babyName ($ageInMonths个月)';
    }
  }

  int _calculateAgeInMonths(DateTime birthDate, DateTime currentDate) {
    int months = (currentDate.year - birthDate.year) * 12 +
        currentDate.month -
        birthDate.month;
    if (currentDate.day < birthDate.day) {
      months--;
    }
    return months;
  }

  // 创建副本的方法
  AppConfig copyWith({
    String? id,
    String? webdavUrl,
    String? username,
    String? password,
    String? babyName,
    DateTime? babyBirthDate,
    DateTime? babyConceptionDate,
  }) {
    return AppConfig(
      id: id ?? this.id,
      webdavUrl: webdavUrl ?? this.webdavUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      babyName: babyName ?? this.babyName,
      babyBirthDate: babyBirthDate ?? this.babyBirthDate,
      babyConceptionDate: babyConceptionDate ?? this.babyConceptionDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'webdavUrl': webdavUrl,
      'username': username,
      'password': password,
      'babyName': babyName,
      'babyBirthDate': babyBirthDate?.toIso8601String(),
      'babyConceptionDate': babyConceptionDate?.toIso8601String(),
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      id: json['id'] ?? const Uuid().v4(),
      webdavUrl: json['webdavUrl'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      babyName: json['babyName'] ?? json['childName'] ?? '', // 向后兼容
      babyBirthDate: json['babyBirthDate'] != null
          ? DateTime.parse(json['babyBirthDate'])
          : (json['childBirthDate'] != null
              ? DateTime.parse(json['childBirthDate'])
              : null),
      babyConceptionDate: json['babyConceptionDate'] != null
          ? DateTime.parse(json['babyConceptionDate'])
          : (json['conceptionDate'] != null
              ? DateTime.parse(json['conceptionDate'])
              : null),
    );
  }
}
