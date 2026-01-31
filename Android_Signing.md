# Android APK 签名配置指南

## 概述
本项目已配置 Android APK 签名功能，用于生成可发布的 APK 文件。

## 文件结构
```
android/
├── key.properties          # 签名配置属性文件
├── app/
│   ├── build.gradle.kts    # Gradle 构建配置
│   └── growth-keystore.p12 # 签名密钥库文件（PKCS12 格式，运行脚本后生成）
└── generate_keystore.ps1   # 密钥生成脚本
```

## 环境变量
- `ANDROID_KEYSTORE_PASSWORD`: 密钥库密码（PKCS12 格式使用单一密码）

如果设置了环境变量，构建时会优先使用环境变量中的值。

## 配置步骤

### 1. 设置环境变量（推荐）
您可以设置环境变量来避免在文件中存储敏感信息：

**Windows PowerShell:**
```powershell
$env:ANDROID_KEYSTORE_PASSWORD = "your_actual_store_password"
```

**Windows CMD:**
```cmd
set ANDROID_KEYSTORE_PASSWORD=your_actual_store_password
```

**永久设置环境变量（Windows）：**
1. 打开系统属性 → 高级 → 环境变量
2. 添加新的用户变量：
   - `ANDROID_KEYSTORE_PASSWORD` = 您的密钥库密码

### 2. 生成签名密钥

运行 PowerShell 脚本生成密钥库：
```powershell
.\generate_keystore.ps1
```

脚本会自动从环境变量获取密码，如果环境变量不存在则使用默认值。

### 3. 编辑配置文件
如果不使用环境变量，需要直接编辑 `android/key.properties` 文件。

### 4. 构建发布 APK
```bash
flutter build apk --release
```

生成的 APK 文件位于 `build/app/outputs/flutter-apk/app-release.apk`

## 安全注意事项
- 不要将 `key.properties` 文件更新的密钥和 `growth-keystore.p12` 文件提交到版本控制系统
- 妥善保管您的密钥库文件和密码
- 考虑将敏感信息存储在环境变量或安全的密钥管理系统中
