import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/manifest.dart' as manifest_models;
import '../services/manifest_manager.dart';
import 'web_page_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String _statusMessage = 'Загрузка...';
  ManifestManager? _manifestManager;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        print('🚀 SplashScreen: Starting initialization...');

        setState(() {
          _statusMessage = 'Загрузка состояния...';
        });

        final prefs = await SharedPreferences.getInstance();
        _manifestManager = ManifestManager(prefs: prefs);
        print('✅ SharedPreferences loaded');

        setState(() {
          _statusMessage = 'Синхронизация манифеста...';
        });

        print('📡 Calling syncManifest...');
        final manifest = await _manifestManager!.syncManifest();
        print('✅ Manifest loaded: ${manifest.manifestVersion}');

        setState(() {
          _statusMessage = 'Подготовка страницы...';
        });

        if (manifest != null) {
          print('📄 Looking for entry page: ${manifest.entryPage}');
          final entryPage = manifest.pages.firstWhere(
                (p) => p.id == manifest.entryPage,
            orElse: () => manifest.pages.first,
          );
          print('✅ Entry page found: ${entryPage.id}');

          if (entryPage.requiresAuth) {
            print('🔐 Entry page requires auth, redirecting to auth page');
            final authPage = manifest.pages.firstWhere(
                  (p) => p.id == manifest.authPage,
              orElse: () => entryPage,
            );
            _navigateToPage(authPage);
          } else {
            print('✅ Navigating to entry page');
            _navigateToPage(entryPage);
          }
        }

        setState(() {
          _isLoading = false;
          _statusMessage = 'Готово!';
        });

      } catch (e, stackTrace) {
        print('❌ SplashScreen error: $e');
        print('📚 Stack trace: $stackTrace');
        setState(() {
          _isLoading = false;
          _statusMessage = 'Ошибка загрузки: $e';
        });
      }
    });
  }

  void _navigateToPage(manifest_models.Page page) {
    if (!mounted || _manifestManager == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WebPageScreen(
          page: page,
          manifestManager: _manifestManager!, // Используем manifestManager
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/avdicon.png',
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.apps,
                  size: 80,
                  color: Colors.blue,
                );
              },
            ),
            SizedBox(height: 30),
            if (_isLoading) CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 16,
                color: _statusMessage.contains('Ошибка')
                    ? Colors.red
                    : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}