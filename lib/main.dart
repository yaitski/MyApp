import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/manifest.dart';
import 'services/cache_service.dart';
import 'services/download_service.dart';
import 'services/manifest_service.dart';
import 'services/language_service.dart';
import 'widgets/splash_screen.dart';
import 'widgets/webview_screen.dart';
import 'widgets/error_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CacheService>(
          create: (_) => CacheService()..init(),
        ),
        Provider<DownloadService>(
          create: (_) => DownloadService(),
        ),
        Provider<ManifestService>(
          create: (context) => ManifestService(
            cacheService: context.read<CacheService>(),
            downloadService: context.read<DownloadService>(),
          ),
        ),
        Provider<LanguageService>(
          create: (context) => LanguageService(
            cacheService: context.read<CacheService>(),
            downloadService: context.read<DownloadService>(), // ← ДОБАВЛЕНО!
          ),
        ),
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
        ),
      ],
      child: MaterialApp(
        title: 'MiniApp',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: SplashScreen(),
        routes: {
          '/webview': (context) => WebViewScreen(),
          '/error': (context) => ErrorScreen(),
        },
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  Manifest? manifest;
  int? generation;
  String? etag;
  bool isLoading = false;
  String? error;

  void updateManifest({
    required Manifest manifest,
    required int generation,
    required String etag,
  }) {
    this.manifest = manifest;
    this.generation = generation;
    this.etag = etag;
    isLoading = false;
    error = null;
    notifyListeners();
  }

  void setLoading(bool loading) {
    isLoading = loading;
    notifyListeners();
  }

  void setError(String message) {
    error = message;
    isLoading = false;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}