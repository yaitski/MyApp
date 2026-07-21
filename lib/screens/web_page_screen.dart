import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/manifest.dart' as manifest_models;
import '../services/manifest_manager.dart';

class WebPageScreen extends StatefulWidget {
  final manifest_models.Page page;
  final ManifestManager manifestManager;

  const WebPageScreen({
    Key? key,
    required this.page,
    required this.manifestManager,
  }) : super(key: key);

  @override
  _WebPageScreenState createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController? _controller;
  bool _isLoading = true;
  String _htmlContent = '';

  @override
  void initState() {
    super.initState();
    _loadPageWithResources();
  }

  Future<void> _loadPageWithResources() async {
    try {
      final manifest = widget.manifestManager.getActiveManifest();
      if (manifest == null) {
        print('❌ No active manifest');
        _loadPageDirectly();
        return;
      }

      final generation = widget.manifestManager.getCurrentState()?.cacheGeneration ?? 1;
      final resourceLoader = widget.manifestManager.resourceLoader;

      print('📄 Loading page: ${widget.page.id}');
      print('📄 Generation: $generation');

      // Загружаем HTML
      _htmlContent = await resourceLoader.loadPageHtml(widget.page, generation);

      // Загружаем CSS
      String cssContent = '';
      final styles = manifest.styles.where((s) => widget.page.styles.contains(s.id));
      for (var style in styles) {
        try {
          final css = await resourceLoader.loadCss(style, generation);
          cssContent += '\n/* ${style.id} */\n$css\n';
          print('✅ Loaded CSS: ${style.id}');
        } catch (e) {
          print('❌ Failed to load CSS ${style.id}: $e');
        }
      }

      // Загружаем JS
      String jsContent = '';
      final scripts = manifest.scripts.where((s) => widget.page.scripts.contains(s.id));
      final sortedScripts = scripts.toList()..sort((a, b) => a.loadOrder.compareTo(b.loadOrder));
      for (var script in sortedScripts) {
        try {
          final js = await resourceLoader.loadJs(script, generation);
          jsContent += '\n// ${script.id}\n$js\n';
          print('✅ Loaded JS: ${script.id}');
        } catch (e) {
          print('❌ Failed to load JS ${script.id}: $e');
        }
      }

      // Внедряем CSS и JS в HTML
      final finalHtml = _injectResources(_htmlContent, cssContent, jsContent);

      // Загружаем в WebView
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              print('❌ WebView error: $error');
              setState(() {
                _isLoading = false;
              });
            },
          ),
        )
        ..loadHtmlString(finalHtml);

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print('❌ Error loading page: $e');
      _loadPageDirectly();
    }
  }

  void _loadPageDirectly() {
    print('📄 Loading page directly from URL: ${widget.page.url}');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView error: $error');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.page.url));
  }

  String _injectResources(String html, String css, String js) {
    // Внедряем CSS в head
    String result = html;
    if (css.isNotEmpty) {
      final cssTag = '<style>\n$css\n</style>';
      result = result.replaceFirst('</head>', '$cssTag</head>');
    }

    // Внедряем JS перед closing body
    if (js.isNotEmpty) {
      final jsTag = '<script>\n$js\n</script>';
      result = result.replaceFirst('</body>', '$jsTag</body>');
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.page.title),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (_controller != null)  // ✅ Проверка на null
            WebViewWidget(controller: _controller!),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}