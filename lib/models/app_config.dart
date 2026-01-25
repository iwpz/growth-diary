class AppConfig {
  final String webdavUrl;
  final String username;
  final String password;
  final DateTime? childBirthDate;
  final String childName;

  AppConfig({
    this.webdavUrl = '',
    this.username = '',
    this.password = '',
    this.childBirthDate,
    this.childName = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'webdavUrl': webdavUrl,
      'username': username,
      'password': password,
      'childBirthDate': childBirthDate?.toIso8601String(),
      'childName': childName,
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
    );
  }

  bool get isConfigured {
    return webdavUrl.isNotEmpty && 
           username.isNotEmpty && 
           childBirthDate != null;
  }
}
