import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads.dart';
import 'game.dart';
import 'overlays.dart';
import 'strings.dart';

void main() {
  runApp(const ConstellaApp());
}

class ConstellaApp extends StatefulWidget {
  const ConstellaApp({super.key});

  @override
  State<ConstellaApp> createState() => _ConstellaAppState();
}

class _ConstellaAppState extends State<ConstellaApp> with WidgetsBindingObserver {
  // Oyunu bir kez olustur, her build'de yeniden yaratma.
  final ConstellaGame game = ConstellaGame();

  // Altta banner reklam alani. Su an Google TEST banner'i gosteriyor;
  // yayina cikarken AdsService icindeki ID'ler gercekleriyle degisecek.
  static const double kBannerHeight = 60;
  BannerAd? _banner;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // SDK'nin baslamasi icin kucuk bir gecikmeyle banner'i yukle.
    Future.delayed(const Duration(seconds: 2), _loadBanner);
  }

  void _loadBanner() {
    if (!mounted) return;
    _banner = BannerAd(
      size: AdSize.banner,
      adUnitId: AdsService.bannerId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _bannerLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _banner = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana/on plana gecince muzigi durdur/devam ettir.
    game.handleLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1026),
        body: SafeArea(
          bottom: true,
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => game.handleTap(d.localPosition),
                  child: GameWidget(
                    game: game,
                    overlayBuilderMap: {
                      'ui': (context, g) => ConstellaUi(game: g as ConstellaGame),
                    },
                    initialActiveOverlays: const ['ui'],
                  ),
                ),
              ),

              // Banner: SADECE menu ekranlarinda (oyun sirasinda gizli),
              // "Reklamlari Kaldir" alaninca tamamen kalkar.
              ValueListenableBuilder<GState>(
                valueListenable: game.uiState,
                builder: (context, s, _) {
                  final inMenus = s != GState.playing && s != GState.connecting;
                  if (game.adsRemoved || !inMenus) return const SizedBox.shrink();
                  return Container(
                    height: kBannerHeight,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10131F),
                      border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
                    ),
                    alignment: Alignment.center,
                    child: (_bannerLoaded && _banner != null)
                        ? SizedBox(
                            width: _banner!.size.width.toDouble(),
                            height: _banner!.size.height.toDouble(),
                            child: AdWidget(ad: _banner!),
                          )
                        : Text(
                            t('adSpacePlaceholder'),
                            style: const TextStyle(color: Color(0x44FFFFFF), fontSize: 12),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
