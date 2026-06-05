import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Servidor por defecto (producción). Se puede cambiar desde la app (ícono ⛃).
const String kDefaultServer = 'http://172.31.102.40:4200';

void main() => runApp(const AdmosaApp());

class AdmosaApp extends StatelessWidget {
  const AdmosaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADMOSA SignageTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF020617),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0F172A)),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
      ),
      home: const PanelWebView(),
    );
  }
}

class PanelWebView extends StatefulWidget {
  const PanelWebView({super.key});
  @override
  State<PanelWebView> createState() => _PanelWebViewState();
}

class _PanelWebViewState extends State<PanelWebView> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefresh;
  String _server = kDefaultServer;
  double _progress = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _pullToRefresh = PullToRefreshController(
      onRefresh: () => _controller?.reload(),
    );
    setState(() {
      _server = prefs.getString('server') ?? kDefaultServer;
      _ready = true;
    });
  }

  String get _adminUrl => '$_server/admin';

  Future<void> _cambiarServidor() async {
    final ctrl = TextEditingController(text: _server);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'URL del servidor',
            hintText: 'http://172.31.102.40:4200',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (nuevo == null || nuevo.isEmpty) return;
    final limpio = nuevo.replaceAll(RegExp(r'/+$'), ''); // quita "/" final
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server', limpio);
    setState(() => _server = limpio);
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri('$limpio/admin')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_controller != null && await _controller!.canGoBack()) {
          _controller!.goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ADMOSA SignageTV'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () => _controller?.reload(),
            ),
            IconButton(
              icon: const Icon(Icons.dns_outlined),
              tooltip: 'Cambiar servidor',
              onPressed: _cambiarServidor,
            ),
          ],
          bottom: _progress < 1.0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress, minHeight: 3),
                )
              : null,
        ),
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_adminUrl)),
            pullToRefreshController: _pullToRefresh,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useHybridComposition: true,
              allowFileAccess: true,
              allowContentAccess: true,
              mediaPlaybackRequiresUserGesture: false,
              supportZoom: false,
              transparentBackground: true,
              // Permite cargar contenido por HTTP plano (red local de signage)
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            ),
            onWebViewCreated: (c) => _controller = c,
            onProgressChanged: (c, p) {
              if (p == 100) _pullToRefresh?.endRefreshing();
              setState(() => _progress = p / 100);
            },
            onReceivedError: (c, req, err) => _pullToRefresh?.endRefreshing(),
          ),
        ),
      ),
    );
  }
}
