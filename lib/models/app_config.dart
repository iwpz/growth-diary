import 'package:uuid/uuid.dart';

class AppConfig {
  String id;
  final String webdavUrl;
  final String username;
  final String password;
  final DateTime? childBirthDate;
  final String childName;
  final DateTime? conceptionDate;

  AppConfig({
    this.id = '',
    this.webdavUrl = '',
    this.username = '',
    this.password = '',
    this.childBirthDate,
    this.childName = '',
    this.conceptionDate,
  }) {
    if (id.isEmpty) {
      id = const Uuid().v4();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'webdavUrl': webdavUrl,
      'username': username,
      'password': password,
      'childBirthDate': childBirthDate?.toIso8601String(),
      'childName': childName,
      'conceptionDate': conceptionDate?.toIso8601String(),
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      id: json['id'] ?? const Uuid().v4(),
      webdavUrl: json['webdavUrl'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      childBirthDate: json['childBirthDate'] != null
          ? DateTime.parse(json['childBirthDate'])
          : null,
      childName: json['childName'] ?? '',
      conceptionDate: json['conceptionDate'] != null
          ? DateTime.parse(json['conceptionDate'])
          : null,
    );
  }

  bool get isConfigured {
    return webdavUrl.isNotEmpty &&
        username.isNotEmpty &&
        childBirthDate != null;
  }

  AppConfig copyWith({
    String? id,
    String? webdavUrl,
    String? username,
    String? password,
    DateTime? childBirthDate,
    String? childName,
    DateTime? conceptionDate,
  }) {
    return AppConfig(
      id: id ?? this.id,
      webdavUrl: webdavUrl ?? this.webdavUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      childBirthDate: childBirthDate ?? this.childBirthDate,
      childName: childName ?? this.childName,
      conceptionDate: conceptionDate ?? this.conceptionDate,
    );
  }
}
