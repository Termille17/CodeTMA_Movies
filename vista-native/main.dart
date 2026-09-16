import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const vistaOrigin = 'https://vista-tv.vercel.app';
const vistaIptvUserAgent = 'VLC/3.0.21 LibVLC/3.0.21';

const nativeBridge = r'''(() => {
  window.__VISTA_NATIVE__ = true;
  if (window.__vistaNativeBridge) return;
  window.__vistaNativeBridge = true;
  window.__vistaNativeMedia = window.__vistaNativeMedia || new Map();

  // Observe Vista's real catalogue responses so native playback receives the
  // exact kind, playback id & provider container extension for every item.
  const originalFetch = window.fetch.bind(window);
  window.fetch = async (...args) => {
    const response = await originalFetch(...args);
    try {
      const raw = String(typeof args[0] === 'string' ? args[0] : (args[0]?.url || ''));
      if (/\/api\/catalog\/(live|movies|series)/.test(raw)) {
        response.clone().json().then((data) => {
          for (const item of (data?.items || [])) {
            if (item?.id) window.__vistaNativeMedia.set(String(item.id), item);
          }
        }).catch(() => {});
      }
    } catch (_) {}
    return response;
  };

  const itemFrom = (target) => {
    const el = target?.closest?.('[data-vista-id],[data-vista],[data-stream-id],[data-live-id],[data-id],a[href*="/api/play/xtream/"]');
    if (!el) return null;

    const vistaId = String(el.dataset?.vistaId || '');
    const cached = vistaId ? window.__vistaNativeMedia.get(vistaId) : null;
    if (cached) {
      return {
        id: String(cached.playbackId || cached.streamId || cached.id || ''),
        kind: String(cached.kind || 'live').toLowerCase(),
        ext: String(cached.containerExtension || (cached.kind === 'live' ? 'ts' : 'mp4')),
        title: String(cached.name || ''),
        el,
      };
    }

    const values = [
      vistaId,
      el.dataset?.vista,
      el.dataset?.streamId,
      el.dataset?.liveId,
      el.dataset?.id,
      el.getAttribute?.('href'),
    ].filter(Boolean).map(String);

    for (const raw of values) {
      let m = raw.match(/xtream-(live|movie)-(\d+)/i);
      if (m) return {id: m[2], kind: m[1].toLowerCase(), ext: m[1].toLowerCase() === 'live' ? 'ts' : 'mp4', title: '', el};

      m = raw.match(/\/api\/play\/xtream\/(\d+)(?:\?([^#]+))?/i);
      if (m) {
        const qs = new URLSearchParams(m[2] || '');
        const kind = String(qs.get('kind') || 'live').toLowerCase();
        return {id: m[1], kind, ext: qs.get('ext') || (kind === 'live' ? 'ts' : 'mp4'), title: '', el};
      }
    }
    return null;
  };

  const intercept = async (event) => {
    const hit = itemFrom(event.target);
    if (!hit || !/^\d+$/.test(hit.id) || hit.kind === 'series') return;

    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();

    const playbackId = hit.id;
    const kind = hit.kind === 'movie' ? 'movie' : 'live';
    const ext = hit.ext || (kind === 'live' ? 'ts' : 'mp4');
    const el = hit.el;
    const title = (
      hit.title ||
      el.dataset?.title ||
      el.querySelector?.('.media-title')?.textContent ||
      el.querySelector?.('h4')?.textContent ||
      el.querySelector?.('strong')?.textContent ||
      (kind === 'movie' ? 'Vista Movie' : 'Vista Live')
    ).trim();

    try {
      const qs = new URLSearchParams({kind, ext});
      const r = await originalFetch(`/api/native/play-url/${encodeURIComponent(playbackId)}?${qs}`, {
        cache: 'no-store',
        credentials: 'include',
      });
      if (!r.ok) throw new Error(`Vista playback ${r.status}`);
      const data = await r.json();
      if (!data?.url) throw new Error('Missing Vista playback URL');
      await window.flutter_inappwebview.callHandler('vistaPlay', {url: data.url, title, kind, ext});
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
        theme: ThemeData.dark(useMaterial3: true)
            .copyWith(scaffoldBackgroundColor: const Color(0xFF050607)),
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
    final title = value['title']?.toString() ?? 'Vista';
    final kind = value['kind']?.toString() ?? 'live';
    final ext = value['ext']?.toString() ?? '';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VistaPlayer(url: url, title: title, kind: kind, ext: ext),
      ),
    );
  }

  Future<void> loadVistaRoot() async {
    if (!mounted) return;
    await webController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(vistaOrigin)),
    );
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
        body: Stack(
          children: [
            SafeArea(
              top: Platform.isWindows,
              bottom: false,
              child: InAppWebView(
                initialUrlRequest: null,
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: nativeBridge,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    forMainFrameOnly: true,
                  ),
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
                  if (uri == null || uri.host != 'vista-tv.vercel.app') {
                    return NavigationActionPolicy.CANCEL;
                  }
                  // Browser playback is never allowed inside the native shell.
                  if (uri.path.startsWith('/api/play/')) {
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
              ),
            ),
            if (progress < 1)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  value: progress == 0 ? null : progress,
                  minHeight: 1,
                ),
              ),
          ],
        ),
      );
}

class VistaPlayer extends StatefulWidget {
  const VistaPlayer({
    super.key,
    required this.url,
    required this.title,
    required this.kind,
    required this.ext,
  });

  final String url;
  final String title;
  final String kind;
  final String ext;

  bool get isLive => kind == 'live';

  @override
  State<VistaPlayer> createState() => _VistaPlayerState();
}

class _VistaPlayerState extends State<VistaPlayer> {
  late final Player player;
  late final VideoController controller;
  StreamSubscription<bool>? completedSub;
  StreamSubscription<String>? errorSub;
  Timer? reconnectTimer;
  String? directUrl;
  String? lastError;
  int reconnectAttempts = 0;
  bool disposed = false;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    if (!Platform.isWindows) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    completedSub = player.stream.completed.listen((done) {
      if (done && widget.isLive) scheduleReconnect();
    });
    errorSub = player.stream.error.listen((message) {
      lastError = message;
      if (mounted) setState(() {});
      if (widget.isLive) scheduleReconnect();
    });

    startPlayback();
  }

  Future<String> resolveProviderUrl(String signedUrl) async {
    final client = HttpClient();
    client.userAgent = vistaIptvUserAgent;
    try {
      final request = await client.getUrl(Uri.parse(signedUrl));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain();
      if (location != null && response.statusCode >= 300 && response.statusCode < 400) {
        return Uri.parse(signedUrl).resolve(location).toString();
      }
      return signedUrl;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> setNativeProperty(String name, String value) async {
    final platform = player.platform;
    if (platform is NativePlayer) {
      try {
        await platform.setProperty(name, value);
      } catch (_) {
        // Some bundled mpv builds do not expose every option; playback must
        // continue even when an optional tuning property is unavailable.
      }
    }
  }

  Future<void> configureNativeTransport() async {
    await setNativeProperty('user-agent', vistaIptvUserAgent);
    await setNativeProperty('network-timeout', '90');
    await setNativeProperty('cache', 'yes');
    await setNativeProperty('demuxer-readahead-secs', widget.isLive ? '6' : '20');
    if (widget.isLive) {
      await setNativeProperty(
        'stream-lavf-o',
        'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=5,multiple_requests=1',
      );
    }
  }

  Media mediaFor(String url) => Media(
        url,
        httpHeaders: const {
          'User-Agent': vistaIptvUserAgent,
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      );

  Future<void> startPlayback() async {
    try {
      directUrl ??= await resolveProviderUrl(widget.url);
      if (disposed) return;
      await configureNativeTransport();
      await player.open(mediaFor(directUrl!), play: true);
      reconnectAttempts = 0;
      lastError = null;
      if (mounted) setState(() {});
    } catch (e) {
      lastError = e.toString();
      if (mounted) setState(() {});
      if (widget.isLive) scheduleReconnect();
    }
  }

  void scheduleReconnect() {
    if (disposed || !widget.isLive || reconnectTimer?.isActive == true) return;
    final seconds = reconnectAttempts < 2 ? 1 : (reconnectAttempts < 5 ? 2 : 4);
    reconnectAttempts += 1;
    reconnectTimer = Timer(Duration(seconds: seconds), () async {
      if (disposed || directUrl == null) return;
      try {
        await player.open(mediaFor(directUrl!), play: true);
      } catch (e) {
        lastError = e.toString();
        if (mounted) setState(() {});
        scheduleReconnect();
      }
    });
  }

  @override
  void dispose() {
    disposed = true;
    reconnectTimer?.cancel();
    completedSub?.cancel();
    errorSub?.cancel();
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
        body: Stack(
          children: [
            Positioned.fill(
              child: Video(
                controller: controller,
                controls: AdaptiveVideoControls,
                fit: BoxFit.contain,
              ),
            ),
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
            if (lastError != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: SafeArea(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC111318),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        widget.isLive
                            ? 'Vista is reconnecting to this live channel…'
                            : 'Vista could not open this movie: $lastError',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
