// lib/widgets/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/manifest_service.dart';
import '../services/language_service.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Используем addPostFrameCallback для отложенного выполнения
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final manifestService = context.read<ManifestService>();
    final appState = context.read<AppState>();

    appState.setLoading(true);

    try {
      final result = await manifestService.checkAndSyncManifest();

      if (result.success && result.manifest != null && result.generation != null && result.etag != null) {
        appState.updateManifest(
          manifest: result.manifest!,
          generation: result.generation!,
          etag: result.etag!,
        );

        final languageService = context.read<LanguageService>();
        final selectedLang = await languageService.getSelectedLanguage(result.manifest!);
        await languageService.saveSelectedLanguage(selectedLang);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/webview');
        }
      } else if (result.isUnsupported && result.error != null) {
        appState.setError(result.error!);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/error', arguments: {
            'error': result.error,
            'type': 'unsupported',
          });
        }
      } else {
        appState.setError('Не удалось загрузить данные приложения');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/error', arguments: {
            'error': 'Не удалось загрузить данные приложения. Проверьте подключение к интернету.',
            'type': 'network',
          });
        }
      }
    } catch (e) {
      appState.setError('Ошибка: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/error', arguments: {
          'error': 'Произошла ошибка: $e',
          'type': 'error',
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FlutterLogo(size: 100),
            const SizedBox(height: 30),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Загрузка приложения...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}