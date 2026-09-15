import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const vistaOrigin = 'https://vista-tv.vercel.app';

const nativeBridge = r'''(() => {
  if (window.__vistaNativeBridge) return;
  window.__vistaNativeBridge = true;
  document.addEventListener('click', async (event) => {
    const el = event.target?.closest?.('[data-vista-id]');
    if (!el) return;
    const id = String(el.dataset.vistaId || '');
    const match = id.match(/^xtream-live-(.+)$/);
    if (!match) return;
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
    const playbackId = match[1];
    const title = (el.dataset.title || el.querySelector('.media-title')?.textContent || el.querySelector('h4')?.textContent || el.querySelector('strong')?.textContent || 'Vista Live').trim();
    try {
      const r = await fetch(`/api/native/play-url/${encodeURIComponent(playbackId)}?kind=live&ext=ts`, {cache:'no-store', credentials:'include'});
      if (!r.ok) throw new Error(`Vista playback ${r.status}`);
      const data = await r.json();
      if (!data?.url) throw new Error('Missing Vista playback URL');
      await window.flutter_inappwebview.callHandler('vistaPlay', {url:data.url, title});
    } catch (e) {
      console.error('Vista native playback failed', e);
      const badge = document.querySelector('#vistaConnection');
      if (badge) badge.textContent = 'NATIVE PLAYBACK ERROR';
    }
  }, true);
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

  Future<void> openPlayer(dynamic value) async {
    if (value is! Map) return;
    final url = value['url']?.toString();
    if (url == null || !url.startsWith(vistaOrigin) || !mounted) return;
    final title = value['title']?.toString() ?? 'Vista Live';
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VistaPlayer(url: url, title: title)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      SafeArea(
        top: Platform.isWindows,
        bottom: false,
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(vistaOrigin)),
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
            controller.addJavaScriptHandler(
              handlerName: 'vistaPlay',
              callback: (args) async {
                if (args.isNotEmpty) await openPlayer(args.first);
                return {'ok': true};
              },
            );
          },
          onProgressChanged: (_, p) { if (mounted) setState(() => progress = p / 100); },
          shouldOverrideUrlLoading: (_, action) async {
            final url = action.request.url?.toString();
            return url != null && url.startsWith(vistaOrigin) ? NavigationActionPolicy.ALLOW : NavigationActionPolicy.CANCEL;
          },
        ),
      ),
      if (progress < 1) Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(value: progress == 0 ? null : progress, minHeight: 1)),
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
      Positioned(top: 18, left: 18, child: SafeArea(child: IconButton.filledTonal(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)))),
      Positioned(top: 24, left: 76, right: 76, child: SafeArea(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))),
    ]),
  );
}
