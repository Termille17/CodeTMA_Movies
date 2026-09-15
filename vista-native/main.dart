import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const vistaOrigin = 'https://vista-tv.vercel.app';

const nativeBridge = r'''(() => {
  window.__VISTA_NATIVE__ = true;
  if (window.__vistaNativeBridge) return;
  window.__vistaNativeBridge = true;

  const liveIdFrom = (target) => {
    const el = target?.closest?.('[data-vista-id],[data-vista],[data-stream-id],[data-live-id],[data-id],a[href*="/api/play/xtream/"]');
    if (!el) return null;

    const values = [
      el.dataset?.vistaId,
      el.dataset?.vista,
      el.dataset?.streamId,
      el.dataset?.liveId,
      el.dataset?.id,
      el.getAttribute?.('href')
    ].filter(Boolean).map(String);

    for (const raw of values) {
      try {
        if (raw.trim().startsWith('{')) {
          const j = JSON.parse(raw);
          const jt = String(j?.type || j?.kind || '').toLowerCase();
          const jid = String(j?.id || j?.streamId || j?.stream_id || '');
          if ((!jt || jt === 'live') && /^\d+$/.test(jid)) return {id: jid, el};
        }
      } catch (_) {}

      let m = raw.match(/xtream-live-(\d+)/i);
      if (m) return {id: m[1], el};
      m = raw.match(/\/api\/play\/xtream\/(\d+)/i);
      if (m) return {id: m[1], el};
      m = raw.match(/(?:^|[|:_-])live(?:[|:_-]+(?:xtream)?[|:_-]*)?(\d+)(?:$|[|:_-])/i);
      if (m) return {id: m[1], el};
    }

    const explicitType = String(el.dataset?.type || el.dataset?.kind || '').toLowerCase();
    const numeric = String(el.dataset?.streamId || el.dataset?.liveId || el.dataset?.id || '');
    if (explicitType === 'live' && /^\d+$/.test(numeric)) return {id: numeric, el};
    return null;
  };

  const intercept = async (event) => {
    const hit = liveIdFrom(event.target);
    if (!hit) return;

    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();

    const {id: playbackId, el} = hit;
    const title = (
      el.dataset?.title ||
      el.querySelector?.('.media-title')?.textContent ||
      el.querySelector?.('h4')?.textContent ||
      el.querySelector?.('strong')?.textContent ||
      'Vista Live'
    ).trim();

    try {
      const r = await fetch(`/api/native/play-url/${encodeURIComponent(playbackId)}?kind=live&ext=ts`, {
        cache: 'no-store',
        credentials: 'include'
      });
      if (!r.ok) throw new Error(`Vista playback ${r.status}`);
      const data = await r.json();
      if (!data?.url) throw new Error('Missing Vista playback URL');
      await window.flutter_inappwebview.callHandler('vistaPlay', {url: data.url, title});
    } catch (e) {
      console.error('Vista native playback failed', e);
      const badge = document.querySelector('#vistaConnection');
      if (badge) badge.textContent = 'NATIVE PLAYBACK ERROR';
    }
  };

  document.addEventListener('click', intercept, true);
})();''';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const VistaApp());
}

class VistaApp extends StatelessWidget {
  const VistaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vista TV',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: const Color(0xFF050607)),
    home: const VistaShell(),
  );
}

class VistaShell extends StatefulWidget {
  const VistaShell({super.key});
  @override
  State<VistaShell> createState() => _VistaShellState();
}

class _VistaShellState extends State<VistaShell> {
  double progress = 0;
  InAppWebViewController? webController;
  Timer? retryTimer;
  int retryCount = 0;
  bool initialLoadStarted = false;

  Future<void> openPlayer(dynamic value) async {
    if (value is! Map) return;
    final url = value['url']?.toString();
    if (url == null || !url.startsWith(vistaOrigin) || !mounted) return;
    final title = value['title']?.toString() ?? 'Vista Live';
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VistaPlayer(url: url, title: title)));
  }

  Future<void> loadVistaRoot() async {
    if (!mounted) return;
    await webController?.loadUrl(urlRequest: URLRequest(url: WebUri(vistaOrigin)));
  }

  void scheduleVistaRetry() {
    if (!mounted || retryCount >= 6) return;
    retryTimer?.cancel();
    final delayMs = 700 + (retryCount * 650);
    retryCount += 1;
    retryTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      await loadVistaRoot();
    });
  }

  bool isTransientNetworkError(WebResourceError error) {
    final description = error.description.toLowerCase();
    return description.contains('err_network_changed') ||
        description.contains('network changed') ||
        description.contains('internet disconnected') ||
        description.contains('connection reset') ||
        description.contains('connection aborted');
  }

  @override
  void dispose() {
    retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      SafeArea(
        top: Platform.isWindows,
        bottom: false,
        child: InAppWebView(
          initialUrlRequest: null,
          initialUserScripts: UnmodifiableListView<UserScript>([
            UserScript(source: nativeBridge, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START, forMainFrameOnly: true),
          ]),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            useShouldOverrideUrlLoading: true,
            supportZoom: false,
          ),
          onWebViewCreated: (controller) {
            webController = controller;
            controller.addJavaScriptHandler(
              handlerName: 'vistaPlay',
              callback: (args) async {
                if (args.isNotEmpty) await openPlayer(args.first);
                return {'ok': true};
              },
            );

            if (!initialLoadStarted) {
              initialLoadStarted = true;
              Future.delayed(const Duration(milliseconds: 1200), () async {
                if (mounted) await loadVistaRoot();
              });
            }
          },
          onLoadStart: (_, __) {
            retryTimer?.cancel();
          },
          onLoadStop: (controller, url) async {
            retryTimer?.cancel();
            retryCount = 0;
            final uri = Uri.tryParse(url?.toString() ?? '');
            if (uri != null && uri.host == 'vista-tv.vercel.app' && uri.path == '/login') {
              await loadVistaRoot();
              return;
            }
            await controller.evaluateJavascript(source: nativeBridge);
          },
          onReceivedError: (_, request, error) {
            final isMainFrame = request.isForMainFrame == true;
            if (isMainFrame && isTransientNetworkError(error)) {
              scheduleVistaRetry();
            }
          },
          onProgressChanged: (_, p) {
            if (mounted) setState(() => progress = p / 100);
          },
          shouldOverrideUrlLoading: (_, action) async {
            final raw = action.request.url?.toString();
            if (raw == null) return NavigationActionPolicy.CANCEL;
            final uri = Uri.tryParse(raw);
            if (uri == null || uri.host != 'vista-tv.vercel.app') return NavigationActionPolicy.CANCEL;
            if (uri.path == '/login') {
              await loadVistaRoot();
              return NavigationActionPolicy.CANCEL;
            }
            if (uri.path.startsWith('/api/play/')) return NavigationActionPolicy.CANCEL;
            return NavigationActionPolicy.ALLOW;
          },
        ),
      ),
      if (progress < 1)
        Align(
          alignment: Alignment.topCenter,
          child: LinearProgressIndicator(value: progress == 0 ? null : progress, minHeight: 1),
        ),
    ]),
  );
}

class VistaPlayer extends StatefulWidget {
  const VistaPlayer({super.key, required this.url, required this.title});
  final String url;
  final String title;
  @override
  State<VistaPlayer> createState() => _VistaPlayerState();
}

class _VistaPlayerState extends State<VistaPlayer> {
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    if (!Platform.isWindows) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    player.open(Media(widget.url), play: true);
  }

  @override
  void dispose() {
    if (!Platform.isWindows) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(children: [
      Positioned.fill(child: Video(controller: controller, controls: AdaptiveVideoControls, fit: BoxFit.contain)),
      Positioned(
        top: 18,
        left: 18,
        child: SafeArea(
          child: IconButton.filledTonal(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ),
      Positioned(
        top: 24,
        left: 76,
        right: 76,
        child: SafeArea(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ]),
  );
}
