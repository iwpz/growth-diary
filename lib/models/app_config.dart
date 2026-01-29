class AppConfig {
  final String webdavUrl;
  final String username;
  final String password;
  final DateTime? childBirthDate;
  final String childName;
  final DateTime? conceptionDate;

  AppConfig({
    this.webdavUrl = '',
    this.username = '',
    this.password = '',
    this.childBirthDate,
    this.childName = '',
    this.conceptionDate,
  });

  Map<String, dynamic> toJson() {
    return {
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
    String? webdavUrl,
    String? username,
    String? password,
    DateTime? childBirthDate,
    String? childName,
    DateTime? conceptionDate,
  }) {
    return AppConfig(
      webdavUrl: webdavUrl ?? this.webdavUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      childBirthDate: childBirthDate ?? this.childBirthDate,
      childName: childName ?? this.childName,
      conceptionDate: conceptionDate ?? this.conceptionDate,
    );
  }
}
