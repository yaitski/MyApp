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
  String? _pendingModalPageId;
  Map<String, dynamic>? _pendingModalParams;
  String? _pendingPageId;
  Map<String, dynamic>? _pendingPageParams;

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
            //debugPrint('📍 Page started: $url');
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
            //debugPrint('📍 Page finished: $url');
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
          _handleOpenResource(data);
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

  void _handleOpenResource(Map<String, dynamic> data) {
    debugPrint('📂 Opening resource...');
    debugPrint('📂 Data: $data');

    try {
      // Извлекаем параметры
      final resourceId = data['resource_id'] as String?;
      final presentation = data['presentation'] as String? ?? 'page';
      final params = data['params'] as Map<String, dynamic>? ?? {};

      if (resourceId == null) {
        debugPrint('❌ Resource ID is null');
        _sendErrorToJavaScript('open_resource_error', 'Resource ID is required');
        return;
      }

      debugPrint('📂 Resource ID: $resourceId');
      debugPrint('📂 Presentation: $presentation');
      debugPrint('📂 Params: $params');

      final appState = context.read<AppState>();
      final manifest = appState.manifest;
      if (manifest == null) {
        _sendErrorToJavaScript('open_resource_error', 'Manifest not loaded');
        return;
      }

      // Ищем страницу в манифесте по id или route
      final page = manifest.pages.firstWhere(
            (p) => p.id == resourceId || p.route == resourceId,
        orElse: () => manifest.pages.firstWhere(
              (p) => p.id == 'home',
          orElse: () => manifest.pages.first,
        ),
      );

      debugPrint('📄 Found page: ${page.id} (route: ${page.route})');

      // Проверяем авторизацию для ресурса
      if (page.requiresAuth && !_isAuthenticated) {
        debugPrint('🔐 Resource requires auth, redirecting to auth');
        _pendingPageId = page.id;
        _loadAuthPage(manifest);
        return;
      }

      // Открываем в зависимости от presentation
      if (presentation == 'modal') {
        _openResourceAsModal(page, params);
      } else {
        _openResourceAsPage(page, params);
      }

    } catch (e) {
      debugPrint('❌ Error opening resource: $e');
      _sendErrorToJavaScript('open_resource_error', 'Error opening resource: $e');
    }
  }

  void _openResourceAsModal(dynamic page, Map<String, dynamic> params) {
    debugPrint('🟨 Opening resource as MODAL: ${page.id}');

    // Сохраняем параметры
    _pendingModalParams = params;
    _pendingModalPageId = page.id;

    // Получаем data URL асинхронно
    _getPageUrl(page).then((dataUrl) {
      debugPrint('📄 Data URL for modal length: ${dataUrl.length}');
      _showModalSheet(page, dataUrl);
    }).catchError((error) {
      debugPrint('❌ Error getting page URL: $error');
      _showError('Не удалось загрузить страницу');
    });
  }

    // Показываем модальное окно
  void _showModalSheet(dynamic page, String dataUrl) {
    // Убедимся, что контекст еще активен
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Заголовок модального окна
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      page.title ?? 'Modal',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Содержимое модального окна
              Expanded(
                child: _buildModalWebView(page, dataUrl),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      debugPrint('🟨 Modal closed: ${page.id}');
      _pendingModalParams = null;
      _pendingModalPageId = null;
      _sendResultToJavaScript('modal_closed', {
        'resource_id': page.id,
        'result': 'closed',
      });
    }).catchError((error) {
      debugPrint('❌ Error showing modal: $error');
    });
  }

// Создание WebView для модального окна
  Widget _buildModalWebView(dynamic page, String dataUrl) {
    debugPrint('🔨 Building modal WebView for: ${page.id}');
    debugPrint('🔨 Data URL length: ${dataUrl.length}');

    return WebViewWidget(
      controller: WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'ModalApp',
          onMessageReceived: (JavaScriptMessage message) {
            debugPrint('📨 Modal message: ${message.message}');
            try {
              final data = jsonDecode(message.message) as Map<String, dynamic>;
              final action = data['action'] as String?;

              if (action == 'close_modal') {
                Navigator.pop(context);
              } else if (action == 'modal_result') {
                Navigator.pop(context, data['result']);
              }
            } catch (e) {
              debugPrint('❌ Error handling modal message: $e');
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              debugPrint('📄 Data URL for modal length: ${dataUrl.length}');
            },
            onPageFinished: (String url) {
              debugPrint('📍 Modal page finished');
              // После загрузки страницы передаем параметры
              _injectModalParams(page.id);
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('❌ Modal error: ${error.description}');
            },
          ),
        )
      // Загружаем страницу из data URL
        ..loadRequest(Uri.parse(dataUrl)),
    );
  }

  Future<String> _getPageUrl(dynamic page) async {
    try {
      final appState = context.read<AppState>();
      final generation = appState.generation;
      if (generation == null) {
        debugPrint('⚠️ Generation is null, using remote URL');
        return page.url;
      }

      // Загружаем HTML из кэша
      final htmlData = await context.read<CacheService>().readResourceFile(
        page.key,
        generation,
      );

      if (htmlData == null) {
        debugPrint('⚠️ HTML data is null for: ${page.key}, using remote URL');
        return page.url;
      }

      // Конвертируем в base64 data URL
      final base64Html = base64Encode(htmlData);
      final dataUrl = 'data:text/html;charset=utf-8;base64,$base64Html';

      debugPrint('✅ Loaded page from cache: ${page.key} (${htmlData.length} bytes)');
      return dataUrl;

    } catch (e) {
      debugPrint('❌ Error loading HTML from cache: $e');
      return page.url; // fallback to remote URL
    }
  }

  void _openResourceAsPage(dynamic page, Map<String, dynamic> params) {
    debugPrint('📄 Opening resource as PAGE: ${page.id}');

    // Сохраняем параметры для передачи на страницу
    _pendingPageParams = params;
    _pendingPageId = page.id;

    // Загружаем страницу
    _loadPage(page.id).then((_) {
      // После загрузки страницы передаем параметры
      _injectPageParams(page.id);
    });
  }

// Инжекция параметров в модальное окно
  void _injectModalParams(String pageId) {
    if (_pendingModalParams == null) return;

    final paramsJson = jsonEncode(_pendingModalParams);
    _controller.runJavaScript('''
    (function() {
      try {
        window.__MODAL_PARAMS__ = $paramsJson;
        console.log('✅ Modal params injected for $pageId:', window.__MODAL_PARAMS__);
        
        // Событие для уведомления страницы о параметрах
        document.dispatchEvent(new CustomEvent('modal:params', {
          detail: window.__MODAL_PARAMS__
        }));
        
        // Если есть AuthPage, передаем параметры через него
        if (window.AuthPage && typeof window.AuthPage.setModalParams === 'function') {
          window.AuthPage.setModalParams(window.__MODAL_PARAMS__);
        }
      } catch (e) {
        console.error('❌ Error injecting modal params:', e);
      }
    })();
  ''');
  }

  void _injectPageParams(String pageId) {
    if (_pendingPageParams == null) return;

    final paramsJson = jsonEncode(_pendingPageParams);
    _controller.runJavaScript('''
    (function() {
      try {
        window.__PAGE_PARAMS__ = $paramsJson;
        console.log('✅ Page params injected for $pageId:', window.__PAGE_PARAMS__);
        
        // Событие для уведомления страницы о параметрах
        document.dispatchEvent(new CustomEvent('page:params', {
          detail: window.__PAGE_PARAMS__
        }));
        
        // Если есть AuthPage, передаем параметры через него
        if (window.AuthPage && typeof window.AuthPage.setPageParams === 'function') {
          window.AuthPage.setPageParams(window.__PAGE_PARAMS__);
        }
      } catch (e) {
        console.error('❌ Error injecting page params:', e);
      }
    })();
  ''');

    _pendingPageParams = null;
  }



  String _buildModalHtml(dynamic page) {
    // Здесь нужно загрузить HTML для модального окна
    // Аналогично _buildHtmlWithCssOnly, но для модального контента
    // Пока возвращаем простой HTML
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${page.title ?? 'Modal'}</title>
  <style>
    body {
      margin: 0;
      padding: 20px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
    .close-btn {
      position: fixed;
      top: 20px;
      right: 20px;
      background: none;
      border: none;
      font-size: 24px;
      cursor: pointer;
    }
  </style>
</head>
<body>
  <button class="close-btn" onclick="window.ModalApp.postMessage('{\\"action\\":\\"close_modal\\"}')">✕</button>
  <h1>${page.title ?? 'Modal Content'}</h1>
  <p>Modal content for ${page.id}</p>
  <div id="params-display">Waiting for params...</div>
  
  <script>
    // Слушаем событие с параметрами
    document.addEventListener('modal:params', function(event) {
      document.getElementById('params-display').textContent = 
        'Params: ' + JSON.stringify(event.detail, null, 2);
    });
    
    // Проверяем, есть ли уже параметры
    if (window.__MODAL_PARAMS__) {
      document.getElementById('params-display').textContent = 
        'Params: ' + JSON.stringify(window.__MODAL_PARAMS__, null, 2);
    }
  </script>
</body>
</html>
  ''';
  }

  void _sendErrorToJavaScript(String action, String message) {
    _controller.runJavaScript('''
    (function() {
      try {
        if (window.MobileAppBridge && window.MobileAppBridge.postMessage) {
          window.MobileAppBridge.postMessage(JSON.stringify({
            action: '$action',
            error: '$message'
          }));
        }
      } catch (e) {
        console.error('Error sending error to JS:', e);
      }
    })();
  ''');
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
  // Строим HTML ТОЛЬКО с CSS, БЕЗ JS (полностью убираем bridgeScript)
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

    // Добавляем ТОЛЬКО CSS (без JavaScript!)
    if (modifiedHtml.contains('</head>')) {
      modifiedHtml = modifiedHtml.replaceFirst(
        '</head>',
        '$styleTags</head>',
      );
    }

    return modifiedHtml;
  }

  // Инициализация JavaScript моста через runJavaScript
  Future<void> _initializeJavaScriptBridge() async {
    try {
      await _controller.runJavaScript('''
      (function() {
        console.log('🔍 Initializing JavaScript bridge via runJavaScript...');
        
        // Создаем мост для коммуникации с нативным приложением
        window.MobileAppBridge = {
          postMessage: function(message) {
            try {
              console.log('📤 Sending to native:', message);
              
              // Используем канал, зарегистрированный в addJavaScriptChannel
              if (typeof window.MobileApp === 'function') {
                console.log('✅ Using window.MobileApp as function');
                window.MobileApp(message);
                return true;
              }
              
              if (window.MobileApp && typeof window.MobileApp.postMessage === 'function') {
                console.log('✅ Using window.MobileApp.postMessage');
                window.MobileApp.postMessage(message);
                return true;
              }
              
              console.error('❌ No bridge found!');
              return false;
            } catch (e) {
              console.error('❌ Error in postMessage:', e);
              return false;
            }
          }
        };
        
        // Перехватываем сообщения от страницы через событие
        document.addEventListener('sendToNative', function(event) {
          if (event.detail && event.detail.message) {
            window.MobileAppBridge.postMessage(event.detail.message);
          }
        });
        
        console.log('✅ JavaScript bridge initialized');
        console.log('📌 window.MobileAppBridge available:', typeof window.MobileAppBridge);
      })();
    ''');

      debugPrint('✅ JavaScript bridge initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing JavaScript bridge: $e');
    }
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

    // Сначала инициализируем мост
    await _initializeJavaScriptBridge();

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
            
            // Добавляем обертку для window.MobileApp, если его нет
            if (typeof window.MobileApp === 'undefined') {
              window.MobileApp = function(message) {
                if (window.MobileAppBridge && window.MobileAppBridge.postMessage) {
                  window.MobileAppBridge.postMessage(message);
                } else {
                  console.warn('⚠️ MobileAppBridge not ready for message:', message);
                }
              };
              console.log('✅ window.MobileApp wrapper created');
            }
            
            // Выполняем скрипт
            ${content}
            console.log('✅ Script executed: $scriptId');
          } catch (e) {
            console.error('❌ Script error: $scriptId', e.message || String(e));
            if (window.MobileAppBridge && window.MobileAppBridge.postMessage) {
              window.MobileAppBridge.postMessage(JSON.stringify({
                action: 'script_error',
                script: '$scriptId',
                error: e.message || String(e)
              }));
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

      final Map<String, dynamic> allPackages = {};
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
      };

      final languageJson = jsonEncode(languageData);

      // Проверяем наличие window.MobileAppBridge перед отправкой
      await _controller.runJavaScript('''
      (function() {
        try {
          console.log('📚 Initializing I18n with pre-loaded packages...');
          
          // Проверяем, что мост существует
          if (!window.MobileAppBridge) {
            console.error('❌ MobileAppBridge not initialized!');
            // Создаем fallback
            window.MobileAppBridge = {
              postMessage: function(message) {
                console.warn('⚠️ Fallback bridge used:', message);
              }
            };
          }
          
          var languageData = $languageJson;
          
          // Инициализируем AuthPage, если он существует
          if (window.AuthPage && typeof window.AuthPage.bootstrap === 'function') {
            window.AuthPage.bootstrap({
              manifest: languageData.manifest,
              current_language: languageData.current_language,
              language_packages: languageData.packages
            });
            console.log('✅ AuthPage initialized');
          } else {
            console.warn('⚠️ AuthPage not found or bootstrap method missing');
          }
          
          console.log('✅ Page features initialized');
        } catch (e) {
          console.error('❌ Error initializing page features:', e);
          
          // Отправляем ошибку в нативное приложение
          if (window.MobileAppBridge && window.MobileAppBridge.postMessage) {
            window.MobileAppBridge.postMessage(JSON.stringify({
              action: 'init_error',
              error: e.message || String(e)
            }));
          }
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
    debugPrint('🔄 Updating language to: $languageCode');

    final appState = context.read<AppState>();
    final manifest = appState.manifest;
    if (manifest == null) return;

    try {
      final languageService = context.read<LanguageService>();
      final translations = await languageService.loadTranslations(
        languageCode,
        manifest,
      );

      Map<String, dynamic> fallbackTranslations = {};
      if (manifest.fallbackLanguage != languageCode) {
        fallbackTranslations = await languageService.loadTranslations(
          manifest.fallbackLanguage,
          manifest,
        );
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
        'current_language': languageCode,
        'packages': {
          languageCode: translations,
          if (manifest.fallbackLanguage != languageCode)
            manifest.fallbackLanguage: fallbackTranslations,
        },
      };

      final languageJson = jsonEncode(languageData);

      await _controller.runJavaScript('''
      (function() {
        try {
          console.log('📚 Updating language to: $languageCode');
          
          var languageData = $languageJson;
          
          // Обновляем через MiniAppI18n, если он существует
          if (window.MiniAppI18n && typeof window.MiniAppI18n.setLanguage === 'function') {
            window.MiniAppI18n.setLanguage('$languageCode', languageData)
              .then(function() {
                console.log('✅ Language updated via MiniAppI18n');
              })
              .catch(function(e) {
                console.error('❌ MiniAppI18n error:', e);
              });
          }
          
          // Обновляем AuthPage, если он существует
          if (window.AuthPage && typeof window.AuthPage.applyLanguage === 'function') {
            window.AuthPage.applyLanguage('$languageCode', languageData.packages['$languageCode']);
            console.log('✅ AuthPage updated');
          }
          
          // Отправляем подтверждение в нативное приложение
          if (window.MobileAppBridge && window.MobileAppBridge.postMessage) {
            window.MobileAppBridge.postMessage(JSON.stringify({
              action: 'language_updated',
              language: '$languageCode',
              timestamp: Date.now()
            }));
          }
          
          console.log('✅ Language updated successfully');
        } catch (e) {
          console.error('❌ Error updating language:', e);
          
          // Отправляем ошибку в нативное приложение
          if (window.MobileAppBridge && window.MobileAppBridge.postMessage) {
            window.MobileAppBridge.postMessage(JSON.stringify({
              action: 'language_update_error',
              language: '$languageCode',
              error: e.message || String(e)
            }));
          }
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