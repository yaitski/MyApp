// lib/widgets/webview_screen.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/manifest.dart';
import '../services/cache_service.dart';
import '../services/language_service.dart';
import '../main.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _currentPage;
  String? _errorMessage;
  bool _isAuthenticated = false;
  String? _pendingPageId;

  // Храним загруженные скрипты
  final Map<String, String> _loadedScripts = {};
  final Set<String> _executedScripts = {};
  bool _scriptsExecuted = false;
  bool _isRealPageLoaded = false;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  Future<bool> _checkAuth() async {
    try {
      // Здесь реальная проверка авторизации
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _initializeWebView() async {
    final appState = context.read<AppState>();
    final manifest = appState.manifest;
    if (manifest == null) {
      _showError('Манифест не загружен');
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'MobileApp',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('📨 Received message from WebView: ${message.message}');
          _handleNativeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('📍 Page started: $url');
            if (url != 'about:blank') {
              _isRealPageLoaded = false;
              _scriptsExecuted = false;
              _currentUrl = url;
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            debugPrint('📍 Page finished: $url');
            if (url != 'about:blank') {
              _isRealPageLoaded = true;
              _currentUrl = url;
              setState(() {
                _isLoading = false;
              });
              // Выполняем скрипты после загрузки реальной страницы
              _executeScripts();
            }
          },
          onWebResourceError: (WebResourceError error) {
            _showError('Ошибка загрузки: ${error.description}');
          },
        ),
      );

    _isAuthenticated = await _checkAuth();
    await _loadPage(manifest.entryPage);
  }

  void _handleNativeMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final action = data['action'] as String?;

      debugPrint('📨 Native message: $action');

      switch (action) {
        case 'auth_submit':
          _handleAuthSubmit(data);
          break;
        case 'change_language':
          debugPrint('___handleNativeMessage started___');
          _handleChangeLanguage(data);
          break;
        case 'open_password_recovery':
          _handlePasswordRecovery();
          break;
        case 'open_resource':
          _handleOpenResource();
          break;
        case 'page_ready':
          debugPrint('📄 Page ready: ${data['page']}');
          if (!_scriptsExecuted) {
            _executeScripts();
          }
          break;

        case 'script_error':
          debugPrint('❌ Script error: ${data['script']} - ${data['error']}');
          break;
        default:
          debugPrint('⚠️ Unknown action: $action');
      }
    } catch (e) {
      debugPrint('❌ Error handling native message: $e');
    }
  }

  void _handleAuthSubmit(Map<String, dynamic> data) async {
    final login = data['login'] as String?;
    final password = data['password'] as String?;
    final requestId = data['request_id'] as String?;

    debugPrint('🔐 Auth submit: login=$login');

    // Имитация авторизации
    await Future.delayed(const Duration(seconds: 1));

    final result = {
      'request_id': requestId,
      'success': true,
      'message': 'Вход выполнен',
    };

    _sendResultToJavaScript('handleAuthResult', result);
  }

  void _handleChangeLanguage(Map<String, dynamic> data) {
    final language = data['language'] as String?;
    debugPrint('🌐 Change language: $language');
    if (language != null) {
      _updateLanguage(language);
    }
  }

  void _handlePasswordRecovery() {
    debugPrint('🔑 Password recovery requested');
  }

  void _handleOpenResource() {
    debugPrint('🔑 Opening resource...');


  }

  void _sendResultToJavaScript(String function, Map<String, dynamic> data) {
    final jsonData = jsonEncode(data);
    _controller.runJavaScript('''
      (function() {
        try {
          if (typeof window.AuthPage !== 'undefined' && window.AuthPage.$function) {
            window.AuthPage.$function($jsonData);
          } else {
            console.warn('AuthPage.$function not found');
          }
        } catch (e) {
          console.error('Error calling AuthPage.$function:', e);
        }
      })();
    ''');
  }

  Future<void> _loadPage(String pageId) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _scriptsExecuted = false;
        _isRealPageLoaded = false;
        _executedScripts.clear();
        _loadedScripts.clear();
      });

      final appState = context.read<AppState>();
      final manifest = appState.manifest;
      if (manifest == null) {
        _showError('Манифест не загружен');
        return;
      }

      final page = manifest.pages.firstWhere(
            (p) => p.id == pageId,
        orElse: () => manifest.pages.first,
      );

      if (page.requiresAuth && !_isAuthenticated) {
        debugPrint('🔐 Page "$pageId" requires auth, redirecting to auth page');
        _pendingPageId = pageId;
        await _loadAuthPage(manifest);
        return;
      }

      final generation = appState.generation;
      if (generation == null) {
        _showError('Поколение кэша не определено');
        return;
      }

      // 1. Загружаем HTML
      final htmlData = await context.read<CacheService>().readResourceFile(
        page.key,
        generation,
      );

      if (htmlData == null) {
        _showError('Не удалось загрузить страницу');
        return;
      }

      // 2. Загружаем CSS (для внедрения в head)
      final styles = await _loadStyles(page.styles, manifest, generation);

      // 3. Загружаем JS (сохраняем для выполнения через runJavaScript)
      final scripts = await _loadScripts(page.scripts, manifest, generation);

      // Сохраняем скрипты
      for (final script in scripts) {
        final id = script['id'] as String;
        final content = script['content'] as String;
        _loadedScripts[id] = content;
        debugPrint('📦 Script loaded: $id (${content.length} bytes)');
      }

      // 4. Получаем язык
      final languageData = await _getLanguageData(manifest);

      // 5. Формируем HTML ТОЛЬКО с CSS (БЕЗ JS!)
      final html = _buildHtmlWithCssOnly(
        htmlData,
        styles,
        languageData,
        pageId,
      );

      // 6. Загружаем HTML в WebView через loadUrl (избегаем about:blank)
      final base64Html = base64Encode(utf8.encode(html));
      await _controller.loadRequest(
          Uri.parse('data:text/html;charset=utf-8;base64,$base64Html')
      );

      setState(() {
        _currentPage = pageId;
        _isLoading = false;
      });

    } catch (e, stackTrace) {
      debugPrint('❌ Error loading page: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _showError('Ошибка загрузки страницы: $e');
    }
  }

  Future<void> _loadAuthPage(Manifest manifest) async {
    try {
      final authPage = manifest.pages.firstWhere(
            (p) => p.id == 'auth',
        orElse: () => manifest.pages.firstWhere(
              (p) => p.route == '/auth',
          orElse: () => manifest.pages.first,
        ),
      );

      debugPrint('🔑 Loading auth page: ${authPage.id}');

      final appState = context.read<AppState>();
      final generation = appState.generation;
      if (generation == null) {
        _showError('Поколение кэша не определено');
        return;
      }

      final htmlData = await context.read<CacheService>().readResourceFile(
        authPage.key,
        generation,
      );

      if (htmlData == null) {
        _showError('Не удалось загрузить страницу авторизации');
        return;
      }

      final styles = await _loadStyles(authPage.styles, manifest, generation);
      final scripts = await _loadScripts(authPage.scripts, manifest, generation);

      for (final script in scripts) {
        final id = script['id'] as String;
        final content = script['content'] as String;
        _loadedScripts[id] = content;
        debugPrint('📦 Script loaded: $id (${content.length} bytes)');
      }

      final languageData = await _getLanguageData(manifest);

      final html = _buildHtmlWithCssOnly(
        htmlData,
        styles,
        languageData,
        'auth',
      );

      // Используем loadUrl вместо loadHtmlString
      final base64Html = base64Encode(utf8.encode(html));
      await _controller.loadRequest(
          Uri.parse('data:text/html;charset=utf-8;base64,$base64Html')
      );

      setState(() {
        _currentPage = 'auth';
        _isLoading = false;
      });

    } catch (e, stackTrace) {
      debugPrint('❌ Error loading auth page: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _showError('Ошибка загрузки страницы авторизации: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadStyles(
      List<String> styleIds,
      Manifest manifest,
      int generation,
      ) async {
    final styles = <Map<String, dynamic>>[];
    for (final id in styleIds) {
      try {
        final style = manifest.styles.firstWhere(
              (s) => s.id == id,
          orElse: () => manifest.styles.first,
        );
        final data = await context.read<CacheService>().readResourceFile(
          style.key,
          generation,
        );
        if (data != null) {
          styles.add({
            'id': style.id,
            'content': utf8.decode(data),
            'media': style.media,
          });
        }
      } catch (e) {
        debugPrint('⚠️ Error loading style $id: $e');
      }
    }
    return styles;
  }

  Future<List<Map<String, dynamic>>> _loadScripts(
      List<String> scriptIds,
      Manifest manifest,
      int generation,
      ) async {
    final scripts = <Map<String, dynamic>>[];
    for (final id in scriptIds) {
      try {
        final script = manifest.scripts.firstWhere(
              (s) => s.id == id,
          orElse: () => manifest.scripts.first,
        );
        final data = await context.read<CacheService>().readResourceFile(
          script.key,
          generation,
        );
        if (data != null) {
          scripts.add({
            'id': script.id,
            'content': utf8.decode(data),
            'loadOrder': script.loadOrder,
            'defer': script.defer,
            'module': script.module,
          });
          debugPrint('✅ Loaded script: ${script.id} (order: ${script.loadOrder})');
        }
      } catch (e) {
        debugPrint('⚠️ Error loading script $id: $e');
      }
    }
    scripts.sort((a, b) => (a['loadOrder'] as int).compareTo(b['loadOrder'] as int));
    return scripts;
  }

  Future<Map<String, dynamic>> _getLanguageData(Manifest manifest) async {
    try {
      final languageService = context.read<LanguageService>();
      final selectedLang = await languageService.getSelectedLanguage(manifest);
      final translations = await languageService.loadTranslations(
        selectedLang,
        manifest,
      );

      final direction = manifest.languages.firstWhere(
            (l) => l.code == selectedLang,
        orElse: () => manifest.languages.first,
      ).direction;

      return {
        'code': selectedLang,
        'direction': direction,
        'translations': translations,
      };
    } catch (e) {
      debugPrint('⚠️ Error getting language data: $e');
      return {
        'code': 'ru',
        'direction': 'ltr',
        'translations': {},
      };
    }
  }

  // Строим HTML ТОЛЬКО с CSS, БЕЗ JS
  String _buildHtmlWithCssOnly(
      List<int> htmlData,
      List<Map<String, dynamic>> styles,
      Map<String, dynamic> languageData,
      String pageId,
      ) {
    String html = utf8.decode(htmlData);

    final headMeta = '''
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <meta name="language" content="${languageData['code']}">
      <meta name="page-id" content="$pageId">
    ''';

    // Только CSS
    final styleTags = styles.map((style) {
      final content = style['content'] as String;
      final media = style['media'] as String? ?? 'all';
      return '<style media="$media">$content</style>';
    }).join('\n');


    String _escapeJsString(String str) {
      return str
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');
    }
    // Минимальный мост для коммуникации с нативным приложением
    final bridgeScript = '''
<script>
  (function() {
    console.log('🔍 Initializing bridge...');
    
    // Проверяем доступные каналы
    console.log('📌 Available window properties:');
    console.log('- window.MobileApp:', typeof window.MobileApp);
    console.log('- window.MobileAppChannel:', typeof window.MobileAppChannel);
    
    window.MobileAppBridge = {
      postMessage: function(message) {
        try {
          console.log('📤 Sending to native:', message);
          
          // ✅ ИСПРАВЛЕНО: используем ТОЧНО такое же имя, как в addJavaScriptChannel
          // В вашем случае это 'MobileApp'
          if (typeof window.MobileApp === 'function') {
            console.log('✅ Using window.MobileApp as function');
            window.MobileApp(message);
            return;
          }
          
          // Если window.MobileApp - это объект с методом postMessage
          // (для обратной совместимости)
          if (window.MobileApp && typeof window.MobileApp.postMessage === 'function') {
            console.log('✅ Using window.MobileApp.postMessage');
            window.MobileApp.postMessage(message);
            return;
          }
          
          // Fallback для других случаев
          if (typeof window.MobileAppChannel === 'function') {
            console.log('✅ Using MobileAppChannel');
            window.MobileAppChannel(message);
            return;
          }
          
          console.error('❌ No bridge found!');
          console.log('Available:', Object.keys(window).filter(k => k.includes('Mobile') || k.includes('App')));
        } catch (e) {
          console.error('❌ Error:', e);
        }
      }
    };
    
    // Отправляем сигнал готовности
    setTimeout(function() {
      try {
        if (window.MobileApp && window.MobileApp.postMessage) {
          window.MobileApp.postMessage(JSON.stringify({
            action: 'page_ready',
            page: '${_escapeJsString(pageId)}',
            timestamp: Date.now()
          }));
        }
      } catch (e) {
        console.error('Ready error:', e);
      }
    }, 500);
    
    console.log('✅ Bridge initialized');
  })();
</script>
''';



    String modifiedHtml = html;

    // Добавляем мета-теги в head
    if (modifiedHtml.contains('<head>')) {
      modifiedHtml = modifiedHtml.replaceFirst(
        '<head>',
        '<head>$headMeta',
      );
    } else if (modifiedHtml.contains('<html>')) {
      modifiedHtml = modifiedHtml.replaceFirst(
        '<html>',
        '<html><head>$headMeta</head>',
      );
    } else {
      modifiedHtml = '<!DOCTYPE html><html><head>$headMeta</head><body>$modifiedHtml</body></html>';
    }

    // Добавляем CSS и мост в head (БЕЗ JS СКРИПТОВ!)
    if (modifiedHtml.contains('</head>')) {
      modifiedHtml = modifiedHtml.replaceFirst(
        '</head>',
        '$styleTags$bridgeScript</head>',
      );
    }

    return modifiedHtml;
  }

  // Выполнение скриптов через runJavaScript
  Future<void> _executeScripts() async {
    if (_scriptsExecuted) {
      debugPrint('⏭️ Scripts already executed');
      return;
    }

    if (!_isRealPageLoaded) {
      debugPrint('⏳ Real page not loaded yet, waiting...');
      return;
    }

    if (_loadedScripts.isEmpty) {
      debugPrint('⚠️ No scripts to execute');
      return;
    }

    debugPrint('📜 Executing ${_loadedScripts.length} scripts via runJavaScript...');
    debugPrint('📍 Current URL: $_currentUrl');

    final sortedKeys = _loadedScripts.keys.toList();

    for (final scriptId in sortedKeys) {
      if (_executedScripts.contains(scriptId)) {
        debugPrint('⏭️ Script already executed: $scriptId');
        continue;
      }

      final content = _loadedScripts[scriptId];
      if (content == null || content.isEmpty) {
        debugPrint('⚠️ Empty script: $scriptId');
        continue;
      }

      debugPrint('🔄 Executing script: $scriptId (${content.length} bytes)');

      try {
        await _controller.runJavaScript('''
          (function() {
            try {
              // Проверяем готовность документа
              if (document.readyState !== 'complete') {
                console.warn('⚠️ Document not ready for script: $scriptId');
              }
              ${content}
              console.log('✅ Script executed: $scriptId');
            } catch (e) {
              console.error('❌ Script error: $scriptId', e.message || String(e));
              if (window.MobileApp) {
                window.MobileApp.postMessage({
                  action: 'script_error',
                  script: '$scriptId',
                  error: e.message || String(e)
                });
              }
            }
          })();
        ''');
        _executedScripts.add(scriptId);
        debugPrint('✅ Script executed: $scriptId');

        // Небольшая задержка между скриптами
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        debugPrint('❌ Error executing script $scriptId: $e');
      }
    }

    _scriptsExecuted = true;

    // Инициализируем i18n и AuthPage
    await Future.delayed(const Duration(milliseconds: 200));
    await _initializePageFeatures();

    debugPrint('✅ All scripts executed successfully');
  }

  // Инициализация i18n и AuthPage через runJavaScript
  Future<void> _initializePageFeatures() async {
    final appState = context.read<AppState>();
    final manifest = appState.manifest;
    if (manifest == null) return;

    try {
      final languageService = context.read<LanguageService>();
      final selectedLang = await languageService.getSelectedLanguage(manifest);

      /*final translations = await languageService.loadTranslations(
        selectedLang,
        manifest,
      );*/
      final Map<String, dynamic> allPackages = {};
      //Map<String, dynamic> fallbackTranslations = {};
      for (final language in manifest.languages) {
        try {
          final translations = await languageService.loadTranslations(
            language.code,
            manifest,
          );
          allPackages[language.code] = translations;
          debugPrint('📦 Loaded language: ${language.code} (${translations.length} keys)');
        } catch (e) {
          debugPrint('⚠️ Failed to load language: ${language.code} - $e');
        }
      }

      final languageData = {
        'manifest': {
          'default_language': manifest.defaultLanguage,
          'fallback_language': manifest.fallbackLanguage,
          'languages': manifest.languages.map((l) => {
            'id': l.id,
            'code': l.code,
            'locale': l.locale,
            'name': l.name,
            'native_name': l.nativeName,
            'direction': l.direction,
          }).toList(),
          'language_storage_key': manifest.languageStorageKey,
          'detect_device_language': manifest.detectDeviceLanguage,
        },
        'current_language': selectedLang,
        'packages': allPackages,
        //'packages': {
        // selectedLang: translations,
        //  if (manifest.fallbackLanguage != selectedLang)
        //   manifest.fallbackLanguage: fallbackTranslations,
        //},
      };

      final languageJson = jsonEncode(languageData);

      await _controller.runJavaScript('''
        (function() {
          try {
            console.log('📚 Initializing I18n with pre-loaded packages...');
            
            var languageData = $languageJson;
            window.AuthPage.bootstrap({
                  manifest: languageData.manifest,
                  current_language: languageData.current_language,
                  language_packages: languageData.packages
                });
            console.log('✅Done');
console.log(JSON.stringify({
    manifest: languageData.manifest,
    current_language: languageData.current_language,
    language_packages: languageData.packages
}, null, 2));
            
          } catch (e) {
            console.error('❌ Error initializing page features:', e);
          }
        })();
      ''');

      debugPrint('✅ Page features initialized with language: $selectedLang');
    } catch (e) {
      debugPrint('❌ Error initializing page features: $e');
    }
  }

  // Обновление языка через runJavaScript
  Future<void> _updateLanguage(String languageCode) async {
    debugPrint('___Started update Language___');
    final appState = context.read<AppState>();
    final manifest = appState.manifest;
    if (manifest == null) return;

    try {
      final languageService = context.read<LanguageService>();
      final translations = await languageService.loadTranslations(
        languageCode,
        manifest,
      );

      // Получаем fallback переводы, если нужны
      Map<String, dynamic> fallbackTranslations = {};
      if (manifest.fallbackLanguage != languageCode) {
        fallbackTranslations = await languageService.loadTranslations(
          manifest.fallbackLanguage,
          manifest,
        );
      }

      // Формируем полные данные для JavaScript
      final languageData = {
        'manifest': {
          'default_language': manifest.defaultLanguage,
          'fallback_language': manifest.fallbackLanguage,
          'languages': manifest.languages.map((l) => {
            'id': l.id,
            'code': l.code,
            'locale': l.locale,
            'name': l.name,
            'native_name': l.nativeName,
            'direction': l.direction,
          }).toList(),
          'language_storage_key': manifest.languageStorageKey,
          'detect_device_language': manifest.detectDeviceLanguage,
        },
        'current_language': languageCode,
        'packages': {
          languageCode: translations,
          if (manifest.fallbackLanguage != languageCode)
            manifest.fallbackLanguage: fallbackTranslations,
        },
      };

      final languageJson = jsonEncode(languageData);

      // Отправляем ВСЕ данные в JavaScript
      await _controller.runJavaScript('''
      (function() {
        try {
          console.log('📚 Updating language to: $languageCode');
          
          var languageData = $languageJson;
          
          // Проверяем, существует ли MiniAppI18n
          if (window.MiniAppI18n) {
            // Обновляем язык с полными данными
            window.MiniAppI18n.setLanguage('$languageCode', languageData)
              .then(function() {
                console.log('✅ Language updated to: $languageCode');
                
                // Обновляем AuthPage если есть
                if (window.AuthPage && window.AuthPage.applyLanguage) {
                  window.AuthPage.applyLanguage('$languageCode', languageData.packages['$languageCode']);
                }
              })
              .catch(function(e) {
                console.error('❌ Language change error:', e);
              });
          } else {
            console.warn('⚠️ MiniAppI18n not found');
          }
        } catch (e) {
          console.error('❌ Error updating language:', e);
        }
      })();
    ''');

      debugPrint('🌐 Language updated to: $languageCode');
    } catch (e) {
      debugPrint('❌ Error updating language: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ошибка'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage != null) {
                      _loadPage(_currentPage!);
                    } else {
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(
              controller: _controller,
            ),
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.8),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Загрузка...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}