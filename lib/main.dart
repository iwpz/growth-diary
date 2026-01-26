import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/local_storage_service.dart';
import 'services/webdav_service.dart';

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
  final WebDAVService _webdavService = WebDAVService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load config from local storage
    final config = await _localStorage.loadConfig();

    if (config != null && config.isConfigured) {
      try {
        // Initialize WebDAV service
        await _webdavService.initialize(config);

        // Try to load config from WebDAV (might have been updated)
        final webdavConfig = await _webdavService.loadConfig();
        final finalConfig = webdavConfig ?? config;

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              config: finalConfig,
              webdavService: _webdavService,
            ),
          ),
        );
      } catch (e) {
        // If WebDAV fails, still go to home with local config
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              config: config,
              webdavService: _webdavService,
            ),
          ),
        );
      }
    } else {
      // No config found, show setup screen
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SetupScreen(),
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
