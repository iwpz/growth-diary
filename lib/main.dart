import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/local_storage_service.dart';
import 'services/webdav_service.dart';
import 'services/cloud_storage_service.dart';
import 'services/background_upload_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '成长日记',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'), // English
        Locale('zh', 'CN'), // Chinese
      ],
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final LocalStorageService _localStorage = LocalStorageService();
  final CloudStorageService _webdavService = WebDAVService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize WorkManager first
      await BackgroundUploadService.initialize();
    } catch (e) {
      // WorkManager initialization failed, but don't block app startup
      print('WorkManager initialization failed: $e');
    }

    // Load all configs from local storage
    final configs = await _localStorage.loadAllConfigs();
    final currentConfigId = await _localStorage.getCurrentConfigId();

    debugPrint('Loaded configs: ${configs.keys}');
    debugPrint('Current config id: $currentConfigId');

    if (configs.isNotEmpty) {
      // 如果有配置，选择当前配置或第一个配置
      final configId = currentConfigId ?? configs.keys.first;
      final config = configs[configId]!;

      debugPrint('Using config id: $configId, webdavUrl: ${config.webdavUrl}');

      try {
        // Initialize WebDAV service
        await _webdavService.initialize(config);

        // Try to load config from WebDAV (might have been updated)
        final webdavConfig = await _webdavService.loadConfig();
        final finalConfig = webdavConfig ?? config;

        debugPrint('WebDAV config loaded: ${webdavConfig != null}');

        // 更新配置到configs中
        configs[configId] = finalConfig;
        await _localStorage.saveAllConfigs(configs);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              configs: configs,
              currentConfigId: configId,
              cloudService: _webdavService,
              localStorage: _localStorage,
            ),
          ),
        );
      } catch (e) {
        // If WebDAV fails, still go to home with local config
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              configs: configs,
              currentConfigId: configId,
              cloudService: _webdavService,
              localStorage: _localStorage,
            ),
          ),
        );
      }
    } else {
      // No configs found, show setup screen
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SetupScreen(
            localStorage: _localStorage,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.pink.shade100,
              Colors.purple.shade100,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.child_care,
                size: 100,
                color: Colors.pink.shade300,
              ),
              const SizedBox(height: 20),
              const Text(
                '成长日记',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
