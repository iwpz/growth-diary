# 项目架构文档 / Project Architecture

## 目录结构 / Directory Structure

```
growth_diary/
├── lib/
│   ├── main.dart                    # 应用入口和启动画面
│   ├── models/                      # 数据模型
│   │   ├── app_config.dart         # 应用配置模型
│   │   └── diary_entry.dart        # 日记条目模型
│   ├── screens/                     # 界面屏幕
│   │   ├── entry_detail_screen.dart # 日记详情页
│   │   ├── home_screen.dart        # 主页时间轴
│   │   ├── new_entry_screen.dart   # 新建/编辑日记
│   │   ├── settings_screen.dart    # 设置页
│   │   └── setup_screen.dart       # 初始设置页
│   ├── services/                    # 服务层
│   │   ├── local_storage_service.dart  # 本地存储服务
│   │   └── webdav_service.dart        # WebDAV 云存储服务
│   └── utils/                       # 工具类
│       └── age_calculator.dart     # 年龄计算工具
├── android/                         # Android 平台配置
├── ios/                            # iOS 平台配置
├── web/                            # Web 平台配置
└── assets/                         # 资源文件
```

## 核心功能模块 / Core Modules

### 1. 数据模型 (Models)

#### DiaryEntry
- 日记条目数据结构
- 包含：ID、日期、标题、描述、图片路径、视频路径、月龄
- 提供 JSON 序列化/反序列化
- 年龄标签格式化

#### AppConfig
- 应用配置数据结构
- 包含：WebDAV URL、用户名、密码、宝宝生日、宝宝昵称
- 配置验证逻辑

### 2. 服务层 (Services)

#### WebDAVService
- WebDAV 客户端管理
- 配置保存/加载
- 日记条目 CRUD 操作
- 媒体文件上传
- 自动创建目录结构

#### LocalStorageService
- SharedPreferences 封装
- 本地配置缓存
- 离线配置访问

### 3. 界面层 (Screens)

#### SplashScreen
- 启动画面
- 配置加载
- 自动导航到主页或设置页

#### SetupScreen
- 首次使用配置
- 宝宝信息输入
- WebDAV 连接配置

#### HomeScreen
- 时间轴视图
- 日记列表展示
- 下拉刷新
- 浮动按钮新建日记

#### NewEntryScreen
- 新建/编辑日记
- 日期选择（自动计算月龄）
- 文字输入
- 照片/视频选择和上传

#### EntryDetailScreen
- 日记详情展示
- 删除功能
- 媒体文件列表

#### SettingsScreen
- 配置信息查看
- 重新配置选项

### 4. 工具类 (Utils)

#### AgeCalculator
- 年龄计算（月龄）
- 年龄标签格式化
- 常量定义（平均每月天数）

## 数据流 / Data Flow

```
用户操作 → Screen → Service → WebDAV/Local Storage
                ↓
            Model 数据结构
                ↓
            UI 更新
```

## WebDAV 存储结构 / WebDAV Storage Structure

```
growth_diary/
├── config.json              # 应用配置
├── entries/                 # 日记条目
│   ├── <uuid1>.json
│   ├── <uuid2>.json
│   └── ...
└── media/                   # 媒体文件
    ├── <timestamp>_<filename>.jpg
    ├── <timestamp>_<filename>.mp4
    └── ...
```

## 技术特性 / Technical Features

- **状态管理**: StatefulWidget
- **异步操作**: async/await
- **错误处理**: try-catch with debugPrint
- **导航**: MaterialPageRoute
- **主题**: Material Design 3 with pink color scheme
- **跨平台**: Android, iOS, Web support

## 安全考虑 / Security Considerations

- 密码仅存储在本地
- 所有数据存储在用户的 WebDAV 服务器
- 使用 HTTPS 连接 (建议)
- 无第三方数据收集

## 未来改进 / Future Improvements

- 媒体文件预览和下载
- 离线模式支持
- 数据备份和导出
- 搜索功能
- 标签分类
- 分享功能
