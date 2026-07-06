import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ads.dart';
import 'level_config.dart';
import 'strings.dart';

/// Kozmetik yildiz gorunumu (oynanisi ETKILEMEZ, sadece gorsel).
/// Gorunen ad t('skin{id kapitalize}') ceviri anahtarindan gelir.
class StarSkin {
  final String id;
  final int price; // yildiz tozu
  const StarSkin(this.id, this.price);
}

const List<StarSkin> kSkins = [
  StarSkin('klasik', 0),
  StarSkin('elmas', 250),
  StarSkin('zumrut', 300),
  StarSkin('nova', 400),
  StarSkin('kuyruklu', 600),
];

/// Kozmetik cekirdek temasi (oynanisi ETKILEMEZ, sadece merkez diskin
/// halka+isima rengini degistirir). Ad t('core{id kapitalize}') anahtarindan.
class CoreTheme {
  final String id;
  final int price;
  final Color color;
  const CoreTheme(this.id, this.price, this.color);
}

const List<CoreTheme> kCoreThemes = [
  CoreTheme('klasik', 0, Color(0xFF55CCFF)),
  CoreTheme('kor', 350, Color(0xFFFF7A45)),
  CoreTheme('ametist', 350, Color(0xFFB388FF)),
  CoreTheme('yesim', 350, Color(0xFF5CE0A0)),
  CoreTheme('buz', 450, Color(0xFFBFEFFF)),
];

const List<Color> kStarColors = [
  Color(0xFF66E0FF),
  Color(0xFFFF7AB3),
  Color(0xFFFFD166),
  Color(0xFF9B8CFF),
  Color(0xFF7CF5A0),
];

Color _colorOf(int idx) => idx < 0 ? Colors.white : kStarColors[idx % kStarColors.length];

/// Yildiz Tozuyla devam etmenin maliyeti (reklamsiz alternatif).
const int kContinueDustCost = 60;

enum GState { onboarding, title, playing, connecting, dying, levelComplete, gameOver }

class _Particle {
  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  final Color color;
  final double radius;
  _Particle(this.pos, this.vel, this.life, this.maxLife, this.color, this.radius);
}

class _Shock {
  Offset pos;
  double radius;
  double life;
  final double maxLife;
  final Color color;
  _Shock(this.pos, this.radius, this.life, this.maxLife, this.color);
}

class _BgStar {
  final Offset frac;
  final double phase;
  final double size;
  const _BgStar(this.frac, this.phase, this.size);
}

class ConstellaGame extends FlameGame {
  GState state = GState.title;

  // Arayüz (overlay) icin: durum degisince Flutter menuleri yeniden cizilir.
  final ValueNotifier<GState> uiState = ValueNotifier(GState.title);
  // Acik panel: null | 'settings' | 'shop'
  final ValueNotifier<String?> panel = ValueNotifier(null);
  final ValueNotifier<int> uiTick = ValueNotifier(0); // arayüzü zorla yenilemek icin

  int level = 1;
  int bestLevel = 1;
  int savedLevel = 1;

  // --- Yildiz Tozu ekonomisi ---
  int dust = 0;
  int lastDustEarned = 0; // son bolumden kazanilan (tamamlandi ekraninda)
  int _nearMissCountLevel = 0; // bu bolumdeki kil payi sayisi (+2 toz/adet)
  String starSkin = 'klasik';
  final Set<String> unlockedSkins = {'klasik'};
  String coreTheme = 'klasik';
  final Set<String> unlockedCoreThemes = {'klasik'};

  // --- Gunluk sistemler (Faz 3) ---
  int streak = 0; // arka arkaya oynanan gun sayisi
  int _lastPlayDay = -1; // son bolum gecilen gun (epoch gun)
  String questType = 'levels'; // 'levels' | 'nearmiss'
  int questTarget = 3;
  int questProgress = 0;
  bool questDone = false;

  int _epochDay() => DateTime.now().difference(DateTime(2020, 1, 1)).inDays;

  // --- Reklam & satin alma haklari (Faz 4) ---
  final AdsService ads = AdsService();
  bool adsRemoved = false; // "Reklamlari Kaldir" satin alaninca true olacak
  int _levelsSinceAd = 0; // gecis reklami kadansi (her 3 bolumde bir)
  bool continueUsed = false; // bolum basina 1 kez reklamli devam
  final List<double> _contAngles = []; // devam icin saklanan yildizlar
  final List<int> _contColors = [];
  int _contPins = 0;

  bool musicOn = true;
  bool sfxOn = true;
  double musicVolume = 0.4;
  double sfxVolume = 1.0;
  bool _bgmStarted = false;

  // Kisa bilgi mesaji (butona basinca "Yakinda!" gibi)
  final ValueNotifier<String?> toast = ValueNotifier(null);

  late LevelConfig cfg;
  int pinsPlaced = 0;

  double diskRotation = 0;
  int curDirection = 1;
  double elapsed = 0;
  double flipAccum = 0;
  double jolt = 0;

  final List<double> stuckAngles = [];
  final List<int> stuckColors = [];

  bool flying = false;
  double flyingY = 0;
  int flyingColor = -1;
  int nextColor = -1;

  double collisionFlash = 0;
  double winFlash = 0;
  double shake = 0;

  // Faz 1: his sistemleri
  double connectAnim = 0; // takimyildiz orme animasyonu (connecting durumu)
  double nearMissPop = 0; // "KIL PAYI!" yazisi sayaci
  int deathsOnLevel = 0; // ayni bolumdeki olum sayisi (pity icin)
  int _pityLevelKey = -1;
  double pityFactor = 1.0; // gizli yardim: 5+ olumde hiz hafif duser

  final List<_Particle> _particles = [];
  final List<_Shock> _shocks = [];
  final List<_BgStar> _bg = [];
  final Random _rng = Random();

  SharedPreferences? prefs;

  @override
  Color backgroundColor() => const Color(0xFF0B1026);

  @override
  Future<void> onLoad() async {
    prefs = await SharedPreferences.getInstance();
    bestLevel = prefs?.getInt('bestLevel') ?? 1;
    savedLevel = prefs?.getInt('curLevel') ?? 1;
    // Dil secimi: kullanici daha once elle sectiyse o kazanir. Yoksa ILK
    // acilista cihazin diline uy; desteklemiyorsak Ingilizceye dus.
    final savedLang = prefs?.getString('lang');
    if (savedLang != null) {
      L.current = langFromCode(savedLang);
    } else {
      final deviceCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      L.current = kLangCodes.values.contains(deviceCode) ? langFromCode(deviceCode) : Lang.en;
    }
    musicOn = prefs?.getBool('musicOn') ?? true;
    sfxOn = prefs?.getBool('sfxOn') ?? true;
    musicVolume = prefs?.getDouble('musicVol') ?? 0.4;
    sfxVolume = prefs?.getDouble('sfxVol') ?? 1.0;
    dust = prefs?.getInt('dust') ?? 0;
    starSkin = prefs?.getString('skin') ?? 'klasik';
    unlockedSkins
      ..clear()
      ..addAll(prefs?.getStringList('skins') ?? ['klasik'])
      ..add('klasik');
    coreTheme = prefs?.getString('coreTheme') ?? 'klasik';
    unlockedCoreThemes
      ..clear()
      ..addAll(prefs?.getStringList('coreThemes') ?? ['klasik'])
      ..add('klasik');
    // --- Gunluk sistemler ---
    final today = _epochDay();
    streak = prefs?.getInt('streak') ?? 0;
    _lastPlayDay = prefs?.getInt('lastPlayDay') ?? -1;
    // Bir gunden fazla ara verildiyse seri koptu
    if (_lastPlayDay >= 0 && today - _lastPlayDay > 1) {
      streak = 0;
      prefs?.setInt('streak', 0);
    }
    // Gunluk giris odulu (gunde bir kez)
    final lastReward = prefs?.getInt('lastRewardDay') ?? -1;
    if (lastReward != today) {
      dust += 25;
      prefs?.setInt('dust', dust);
      prefs?.setInt('lastRewardDay', today);
      showToast(t('toastDailyReward', {'n': '25'}));
    }
    // Gunluk gorev: her gun tarihten uretilir (herkese o gun ayni)
    final qDay = prefs?.getInt('questDay') ?? -1;
    if (qDay != today) {
      final qr = Random(today * 31 + 7);
      if (qr.nextBool()) {
        questType = 'levels';
        questTarget = 3 + qr.nextInt(3); // 3-5 bolum
      } else {
        questType = 'nearmiss';
        questTarget = 2 + qr.nextInt(3); // 2-4 kil payi
      }
      questProgress = 0;
      questDone = false;
      prefs
        ?..setInt('questDay', today)
        ..setString('questType', questType)
        ..setInt('questTarget', questTarget)
        ..setInt('questProgress', 0)
        ..setBool('questDone', false);
    } else {
      questType = prefs?.getString('questType') ?? 'levels';
      questTarget = prefs?.getInt('questTarget') ?? 3;
      questProgress = prefs?.getInt('questProgress') ?? 0;
      questDone = prefs?.getBool('questDone') ?? false;
    }

    adsRemoved = prefs?.getBool('adsRemoved') ?? false;
    ads.init(); // beklemeden arka planda baslasin

    final seen = prefs?.getBool('seenIntro') ?? false;
    _enter(seen ? GState.title : GState.onboarding);
    cfg = generateLevel(savedLevel);
    try {
      await FlameAudio.audioCache.loadAll([
        'tap.wav',
        'shoot.wav',
        'place.wav',
        'fail.wav',
        'level.wav',
        'music.wav',
        'nearmiss.wav',
        'connect.wav'
      ]);
    } catch (_) {}
  }

  /// Durumu degistir ve arayüze haber ver.
  void _enter(GState s) {
    state = s;
    uiState.value = s;
  }

  // ---------------- Ses ----------------
  void _sfx(String name, {double volume = 1.0}) {
    if (!sfxOn) return;
    try {
      FlameAudio.play(name, volume: (volume * sfxVolume).clamp(0.0, 1.0));
    } catch (_) {}
  }

  void _startBgm() {
    if (!musicOn || _bgmStarted) return;
    _bgmStarted = true;
    try {
      FlameAudio.bgm.play('music.wav', volume: musicVolume);
    } catch (_) {}
  }

  void _applyMusicVolume() {
    try {
      FlameAudio.bgm.audioPlayer.setVolume(musicVolume);
    } catch (_) {}
  }

  void toggleMusic() {
    musicOn = !musicOn;
    prefs?.setBool('musicOn', musicOn);
    uiTick.value++;
    try {
      if (!musicOn) {
        FlameAudio.bgm.pause();
      } else if (_bgmStarted) {
        FlameAudio.bgm.resume();
        _applyMusicVolume();
      } else {
        _startBgm();
      }
    } catch (_) {}
  }

  void toggleSfx() {
    sfxOn = !sfxOn;
    prefs?.setBool('sfxOn', sfxOn);
    uiTick.value++;
  }

  void setMusicVolume(double v) {
    musicVolume = v;
    prefs?.setDouble('musicVol', v);
    uiTick.value++;
    _applyMusicVolume();
  }

  void setSfxVolume(double v) {
    sfxVolume = v;
    prefs?.setDouble('sfxVol', v);
    uiTick.value++;
  }

  void setLanguage(Lang lang) {
    L.current = lang;
    prefs?.setString('lang', kLangCodes[lang]!);
    uiTick.value++;
  }

  /// Gunluk gorev ilerlemesi ('levels' = bolum gecme, 'nearmiss' = kil payi)
  void _questEvent(String type) {
    if (questDone || questType != type) return;
    questProgress++;
    prefs?.setInt('questProgress', questProgress);
    if (questProgress >= questTarget) {
      questDone = true;
      dust += 50;
      prefs
        ?..setBool('questDone', true)
        ..setInt('dust', dust);
      showToast(t('toastQuestDone', {'n': '50'}));
    }
    uiTick.value++;
  }

  void showToast(String msg) {
    toast.value = msg;
    Future.delayed(const Duration(seconds: 2), () {
      if (toast.value == msg) toast.value = null;
    });
  }

  void handleLifecycle(AppLifecycleState appState) {
    try {
      if (appState == AppLifecycleState.resumed) {
        if (musicOn && _bgmStarted) FlameAudio.bgm.resume();
      } else {
        FlameAudio.bgm.pause();
      }
    } catch (_) {}
  }

  // ---------------- Arayüz aksiyonlari (butonlar bunlari cagirir) ----------------
  void uiStart() {
    _sfx('tap.wav', volume: 0.5);
    startRun();
  }

  void uiRetry() {
    _sfx('tap.wav', volume: 0.5);
    startRun();
  }

  void uiNext() {
    _sfx('tap.wav', volume: 0.5);
    void go() {
      startLevel();
      _enter(GState.playing);
    }

    // Gecis reklami: OLUMDE DEGIL, sadece bolum gecislerinde ve her 3'te bir.
    _levelsSinceAd++;
    if (!adsRemoved && _levelsSinceAd >= 3 && ads.interstitialReady) {
      _levelsSinceAd = 0;
      ads.showInterstitial(go);
    } else {
      go();
    }
  }

  /// Olum aninda saklanan yildizlari geri yukleyip oyuna devam ettirir.
  void _restoreContinue() {
    continueUsed = true;
    stuckAngles
      ..clear()
      ..addAll(_contAngles);
    stuckColors
      ..clear()
      ..addAll(_contColors);
    pinsPlaced = _contPins;
    flying = false;
    nextColor = _pickColor();
    _enter(GState.playing);
    uiTick.value++;
  }

  /// Odullu reklam: kaldigin yerden devam (bolum basina 1 kez).
  void uiContinueWithAd() {
    _sfx('tap.wav', volume: 0.5);
    ads.showRewarded(
      onReward: () {
        _restoreContinue();
        showToast(t('toastContinue'));
      },
      onUnavailable: () => showToast(t('adNotReady')),
    );
  }

  /// Yildiz Tozuyla devam (bolum basina 1 kez, reklamsiz alternatif).
  void uiContinueWithDust() {
    _sfx('tap.wav', volume: 0.5);
    if (dust < kContinueDustCost) {
      showToast(t('toastInsufficientDust', {'price': '$kContinueDustCost'}));
      return;
    }
    dust -= kContinueDustCost;
    prefs?.setInt('dust', dust);
    _restoreContinue();
    showToast(t('toastContinue'));
  }


  void uiToMenu() {
    _sfx('tap.wav', volume: 0.5);
    panel.value = null;
    _enter(GState.title);
  }

  void uiOnboardingDone() {
    _sfx('tap.wav', volume: 0.5);
    prefs?.setBool('seenIntro', true);
    _enter(GState.title);
  }

  void openMenu() {
    _sfx('tap.wav', volume: 0.5);
    panel.value = 'settings';
  }

  void openShop() {
    _sfx('tap.wav', volume: 0.5);
    panel.value = 'shop';
  }

  void closeMenu() {
    _sfx('tap.wav', volume: 0.5);
    panel.value = null;
  }

  /// Gorunum satin al / sec. Oynanisi etkilemez, sadece gorsel.
  void tapSkin(String id) {
    final skin = kSkins.firstWhere((s) => s.id == id);
    if (unlockedSkins.contains(id)) {
      starSkin = id;
      prefs?.setString('skin', id);
      _sfx('tap.wav', volume: 0.5);
    } else if (dust >= skin.price) {
      dust -= skin.price;
      unlockedSkins.add(id);
      starSkin = id;
      prefs?.setInt('dust', dust);
      prefs?.setStringList('skins', unlockedSkins.toList());
      prefs?.setString('skin', id);
      _sfx('nearmiss.wav', volume: 0.6);
      HapticFeedback.mediumImpact();
      showToast(t('toastSkinBought', {'name': skinName(skin.id)}));
    } else {
      _sfx('tap.wav', volume: 0.4);
      showToast(t('toastInsufficientDust', {'price': '${skin.price}'}));
    }
    uiTick.value++;
  }

  /// Cekirdek temasi satin al / sec. Oynanisi etkilemez, sadece gorsel.
  void tapCoreTheme(String id) {
    final theme = kCoreThemes.firstWhere((c) => c.id == id);
    if (unlockedCoreThemes.contains(id)) {
      coreTheme = id;
      prefs?.setString('coreTheme', id);
      _sfx('tap.wav', volume: 0.5);
    } else if (dust >= theme.price) {
      dust -= theme.price;
      unlockedCoreThemes.add(id);
      coreTheme = id;
      prefs?.setInt('dust', dust);
      prefs?.setStringList('coreThemes', unlockedCoreThemes.toList());
      prefs?.setString('coreTheme', id);
      _sfx('nearmiss.wav', volume: 0.6);
      HapticFeedback.mediumImpact();
      showToast(t('toastSkinBought', {'name': coreThemeName(theme.id)}));
    } else {
      _sfx('tap.wav', volume: 0.4);
      showToast(t('toastInsufficientDust', {'price': '${theme.price}'}));
    }
    uiTick.value++;
  }

  // ---------------- Dokunma (sadece oyun icinde firlatma) ----------------
  void handleTap(Offset pos) {
    if (!isLoaded) return;
    if (state == GState.playing && panel.value == null) shoot();
  }

  void startRun() {
    level = savedLevel;
    _startBgm();
    startLevel();
    _enter(GState.playing);
  }

  void startLevel() {
    cfg = generateLevel(level);
    // Pity: bolum degistiyse olum sayacini sifirla; ayni bolumde 5+ olumde
    // donus hizini GIZLICE hafifce dusur (oyuncu fark etmez, "yendim" hisseder).
    if (_pityLevelKey != level) {
      _pityLevelKey = level;
      deathsOnLevel = 0;
    }
    pityFactor = deathsOnLevel >= 5
        ? (1 - min(0.20, 0.05 + (deathsOnLevel - 5) * 0.02))
        : 1.0;
    _nearMissCountLevel = 0;
    continueUsed = false;
    pinsPlaced = 0;
    stuckAngles.clear();
    stuckColors.clear();
    curDirection = cfg.direction;
    flipAccum = 0;
    jolt = 0;
    flying = false;
    _placePreplaced();
    nextColor = _pickColor();
  }

  void _placePreplaced() {
    final r = Random(level * 104729 + 7);
    var placed = 0;
    var attempts = 0;
    while (placed < cfg.preplaced && attempts < 300) {
      attempts++;
      final a = r.nextDouble() * 2 * pi;
      var ok = true;
      for (final s in stuckAngles) {
        if (_angularDist(s, a) < kGap) {
          ok = false;
          break;
        }
      }
      if (ok) {
        for (final z in cfg.deadZones) {
          if (_angularDist(z.center, a) < z.halfWidth + 0.15) {
            ok = false;
            break;
          }
        }
      }
      if (ok) {
        stuckAngles.add(a);
        stuckColors.add(_segColorAt(a));
        placed++;
      }
    }
  }

  int _segColorAt(double a) {
    if (!cfg.colorMode) return -1;
    final segW = 2 * pi / cfg.segCount;
    final seg = (_norm(a) / segW).floor() % cfg.segCount;
    return cfg.segColorIdx[seg];
  }

  int _pickColor() {
    if (!cfg.colorMode) return -1;
    final segW = 2 * pi / cfg.segCount;
    final counts = List<int>.filled(cfg.segCount, 0);
    for (final a in stuckAngles) {
      final s = (_norm(a) / segW).floor() % cfg.segCount;
      counts[s]++;
    }
    var bestSeg = 0;
    var bestRoom = -1.0;
    for (var i = 0; i < cfg.segCount; i++) {
      final room = (segW / kGap) - counts[i];
      if (room > bestRoom) {
        bestRoom = room;
        bestSeg = i;
      }
    }
    return cfg.segColorIdx[bestSeg];
  }

  void shoot() {
    if (flying) return;
    flying = true;
    flyingY = size.y;
    flyingColor = nextColor;
    if (cfg.joltMag > 0) jolt = cfg.joltMag;
    _sfx('shoot.wav', volume: 0.35);
    HapticFeedback.selectionClick();
  }

  // ---------------- Geometri ----------------
  double get _baseRadius => min(size.x, size.y) * 0.14;
  double get _radius => _baseRadius * (1 + cfg.radiusPulse * sin(elapsed * 1.5));
  double get _pinLen => _baseRadius * 1.15;
  Offset get _center => Offset(size.x / 2, size.y / 2);
  double get _flySpeed => size.y * 1.4;

  Offset _starWorldPos(double rel) {
    final theta = rel + diskRotation;
    return _center + Offset(cos(theta), sin(theta)) * (_radius + _pinLen);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded) return;
    elapsed += dt;

    for (final p in _particles) {
      p.pos = p.pos + p.vel * dt;
      p.vel = p.vel * (1 - (2.0 * dt).clamp(0.0, 1.0));
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);

    for (final s in _shocks) {
      s.radius += 320 * dt;
      s.life -= dt;
    }
    _shocks.removeWhere((s) => s.life <= 0);

    if (collisionFlash > 0) collisionFlash -= dt;
    if (winFlash > 0) winFlash -= dt;
    if (shake > 0) shake -= dt;
    if (nearMissPop > 0) nearMissPop -= dt;

    // Takimyildiz orme animasyonu: yildizlar altin ipliklerle birbirine baglanir
    if (state == GState.connecting) {
      diskRotation += 0.15 * dt;
      connectAnim += dt;
      if (connectAnim >= 1.7) {
        _sfx('level.wav', volume: 0.8);
        HapticFeedback.mediumImpact();
        _enter(GState.levelComplete);
      }
      return;
    }

    if (state != GState.playing || panel.value != null) {
      diskRotation += 0.4 * dt;
      return;
    }

    // SLOW-MOTION: bolumun SON yildizi cekirdege yaklasirken zaman yavaslar.
    // Her bolum sonu kucuk bir klimaks anina donusur.
    var gdt = dt;
    if (flying && pinsPlaced == cfg.starCount - 1) {
      final targetY = _center.dy + _radius + _pinLen;
      if (flyingY - targetY < size.y * 0.22) gdt = dt * 0.35;
    }

    final speed =
        cfg.baseSpeed * pityFactor * (1 + cfg.pulseAmp * sin(elapsed * cfg.pulseFreq));
    diskRotation += (speed + jolt) * curDirection * gdt;
    if (jolt > 0) {
      jolt -= jolt * 3 * gdt;
      if (jolt < 0.01) jolt = 0;
    }
    if (cfg.flipTurns > 0) {
      flipAccum += (speed + jolt).abs() * gdt;
      if (flipAccum >= cfg.flipTurns * 2 * pi) {
        flipAccum = 0;
        curDirection = -curDirection;
      }
    }

    if (flying) {
      final targetY = _center.dy + _radius + _pinLen;
      flyingY -= _flySpeed * gdt;
      if (flyingY <= targetY) _stick();
    }
  }

  void _stick() {
    flying = false;
    final newRel = _norm(pi / 2 - diskRotation);

    if (cfg.colorMode) {
      final segW = 2 * pi / cfg.segCount;
      final seg = (newRel / segW).floor() % cfg.segCount;
      if (cfg.segColorIdx[seg] != flyingColor) {
        _fail(newRel);
        return;
      }
    }
    // En yakin yildiza mesafeyi olc (hem carpisma hem kil payi icin)
    var minDist = double.infinity;
    for (final a in stuckAngles) {
      final d = _angularDist(a, newRel);
      if (d < minDist) minDist = d;
    }
    // Yasak bolgeye yakinlik da kil payi sayilir
    var minZone = double.infinity;
    for (final z in cfg.deadZones) {
      final d = _angularDist(z.center, newRel) - z.halfWidth;
      if (d < minZone) minZone = d;
      if (d < 0) {
        _fail(newRel);
        return;
      }
    }
    if (minDist < 0.20) {
      _fail(newRel);
      return;
    }

    // KIL PAYI: carpismaya cok yaklasip kurtulmak — beyin bunu odul sayar
    final nearMiss = minDist < 0.32 || minZone < 0.12;

    stuckAngles.add(newRel);
    stuckColors.add(flyingColor);
    _burst(_starWorldPos(newRel), _colorOf(flyingColor), 10, 160);
    _sfx('place.wav', volume: 0.55);
    if (nearMiss) {
      nearMissPop = 0.9;
      _nearMissCountLevel++;
      _burst(_starWorldPos(newRel), const Color(0xFFFFD166), 16, 220);
      _sfx('nearmiss.wav', volume: 0.6);
      HapticFeedback.mediumImpact();
      _questEvent('nearmiss');
    } else {
      HapticFeedback.lightImpact();
    }
    pinsPlaced++;
    nextColor = _pickColor();

    if (pinsPlaced >= cfg.starCount) {
      winFlash = 0.6;
      for (var i = 0; i < stuckAngles.length; i++) {
        _burst(_starWorldPos(stuckAngles[i]), const Color(0xFFFFD166), 8, 160);
      }
      // Yildiz Tozu kazanimi: temel 10 + ilk denemede 15 + kil payi basina 2
      final firstTry = deathsOnLevel == 0;
      lastDustEarned = 10 + (firstTry ? 15 : 0) + _nearMissCountLevel * 2;
      dust += lastDustEarned;
      prefs?.setInt('dust', dust);

      level++;
      savedLevel = level;
      prefs?.setInt('curLevel', level);
      if (level > bestLevel) {
        bestLevel = level;
        prefs?.setInt('bestLevel', bestLevel);
      }

      // Gunluk seri: bugunun ilk bolum gecisiyse seriyi guncelle
      final today = _epochDay();
      if (_lastPlayDay != today) {
        streak = (_lastPlayDay == today - 1) ? streak + 1 : 1;
        _lastPlayDay = today;
        prefs
          ?..setInt('streak', streak)
          ..setInt('lastPlayDay', today);
        if (streak > 1) showToast(t('toastStreak', {'n': '$streak'}));
      }
      // Gunluk gorev ilerlemesi
      _questEvent('levels');

      // Once takimyildiz orme animasyonu, sonra TAMAMLANDI ekrani
      connectAnim = 0;
      _sfx('connect.wav', volume: 0.7);
      _enter(GState.connecting);
    }
  }

  void _fail(double rel) {
    deathsOnLevel++;
    HapticFeedback.heavyImpact();
    collisionFlash = 0.4;
    shake = 0.35;
    final pos = _starWorldPos(rel);
    _burst(pos, const Color(0xFFFF5A6E), 26, 260);
    _shocks.add(_Shock(pos, _baseRadius * 0.2, 0.5, 0.5, const Color(0xFFFF5A7A)));
    _sfx('fail.wav', volume: 0.8);
    _gameOver();
  }

  void _gameOver() {
    // Reklamli "DEVAM ET" icin mevcut durumu sakla (patlamadan once)
    _contAngles
      ..clear()
      ..addAll(stuckAngles);
    _contColors
      ..clear()
      ..addAll(stuckColors);
    _contPins = pinsPlaced;

    for (var i = 0; i < stuckAngles.length; i++) {
      _burst(_starWorldPos(stuckAngles[i]), _colorOf(stuckColors[i]), 8, 200);
    }
    _shocks.add(_Shock(_center, _baseRadius * 0.3, 0.7, 0.7, const Color(0xFF66E0FF)));
    stuckAngles.clear();
    stuckColors.clear();
    shake = 0.5;
    // Aninda "Basarisiz" ekranina gecmek yerine, once patlama/sarsinti
    // efektlerinin izlenebilmesi icin kisa bir gecis suresi tanı.
    _enter(GState.dying);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (state == GState.dying) _enter(GState.gameOver);
    });
  }

  void _burst(Offset pos, Color color, int n, double speed) {
    for (var i = 0; i < n; i++) {
      final ang = _rng.nextDouble() * 2 * pi;
      final spd = speed * (0.25 + _rng.nextDouble());
      final life = 0.4 + _rng.nextDouble() * 0.6;
      _particles.add(_Particle(
        pos,
        Offset(cos(ang), sin(ang)) * spd,
        life,
        life,
        color,
        1.5 + _rng.nextDouble() * 2.5,
      ));
    }
  }

  double _norm(double a) {
    a = a % (2 * pi);
    if (a < 0) a += 2 * pi;
    return a;
  }

  double _angularDist(double a, double b) {
    var d = (a - b).abs() % (2 * pi);
    if (d > pi) d = 2 * pi - d;
    return d;
  }

  // ============================ RENDER (sadece oyun sahnesi) ============================
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!isLoaded) return;

    _ensureBg();
    _renderBg(canvas);

    canvas.save();
    if (shake > 0) {
      final s = shake * 14;
      canvas.translate((_rng.nextDouble() * 2 - 1) * s, (_rng.nextDouble() * 2 - 1) * s);
    }
    _renderCore(canvas);
    if (state == GState.playing ||
        state == GState.connecting ||
        state == GState.levelComplete) {
      _renderStars(canvas);
    }
    if (state == GState.connecting) _renderConnections(canvas);
    if (state == GState.playing && panel.value == null) _renderFlying(canvas);
    _renderShocks(canvas);
    _renderParticles(canvas);
    canvas.restore();

    _renderFlashes(canvas);

    if (state == GState.playing) _renderHud(canvas);
    if (nearMissPop > 0 && state == GState.playing) _renderNearMiss(canvas);
  }

  /// Bolum bitince: yildizlar yerlestirme sirasina gore altin ipliklerle
  /// birbirine orulur — gercek bir takimyildiz dogar.
  void _renderConnections(Canvas canvas) {
    if (stuckAngles.length < 2) return;
    final pts = [for (final a in stuckAngles) _starWorldPos(a)];
    final total = pts.length - 1;
    final progress = (connectAnim / 1.1).clamp(0.0, 1.0) * total;

    final glow = Paint()
      ..color = const Color(0x66FFD166)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final line = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = 2.2;

    for (var i = 0; i < total; i++) {
      if (progress >= i + 1) {
        canvas.drawLine(pts[i], pts[i + 1], glow);
        canvas.drawLine(pts[i], pts[i + 1], line);
      } else if (progress > i) {
        final f = progress - i;
        final end = Offset.lerp(pts[i], pts[i + 1], f)!;
        canvas.drawLine(pts[i], end, glow);
        canvas.drawLine(pts[i], end, line);
        // orulen ucun ucunda kucuk parilti
        canvas.drawCircle(end, 4, Paint()..color = Colors.white);
        break;
      }
    }
  }

  void _renderNearMiss(Canvas canvas) {
    final a = (nearMissPop / 0.9).clamp(0.0, 1.0);
    final scale = 1.0 + (1 - a) * 0.25;
    _drawText(canvas, t('nearMiss'), Offset(size.x / 2, size.y * 0.30), 26 * scale,
        Color.fromRGBO(255, 209, 102, a),
        bold: true);
  }

  void _ensureBg() {
    if (_bg.isNotEmpty || size.x == 0) return;
    final r = Random(12345);
    for (var i = 0; i < 70; i++) {
      _bg.add(_BgStar(Offset(r.nextDouble(), r.nextDouble()), r.nextDouble() * 2 * pi,
          0.6 + r.nextDouble() * 1.6));
    }
  }

  void _renderBg(Canvas canvas) {
    final paint = Paint();
    for (final s in _bg) {
      final tw = 0.4 + 0.6 * (0.5 + 0.5 * sin(elapsed * 1.2 + s.phase));
      paint.color = Color.fromRGBO(200, 220, 255, tw * 0.7);
      canvas.drawCircle(Offset(s.frac.dx * size.x, s.frac.dy * size.y), s.size, paint);
    }
  }

  Color get _coreThemeColor =>
      kCoreThemes.firstWhere((c) => c.id == coreTheme, orElse: () => kCoreThemes.first).color;

  void _renderCore(Canvas canvas) {
    final center = _center;
    final r = _radius;
    final glowPulse = 1 + 0.12 * sin(elapsed * 2);
    final themeColor = cfg.boss ? const Color(0xFFFF6688) : _coreThemeColor;
    canvas.drawCircle(
      center,
      r * 1.7 * glowPulse,
      Paint()
        ..color = themeColor.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );

    if (cfg.colorMode) {
      final rect = Rect.fromCircle(center: center, radius: r);
      final segW = 2 * pi / cfg.segCount;
      final segPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.55;
      for (var i = 0; i < cfg.segCount; i++) {
        final start = i * segW + diskRotation;
        segPaint.color = _colorOf(cfg.segColorIdx[i]).withValues(alpha: 0.85);
        canvas.drawArc(rect, start, segW, false, segPaint);
      }
    }

    canvas.drawCircle(center, r, Paint()..color = const Color(0xFF141F38));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = themeColor,
    );

    if (cfg.deadZones.isNotEmpty) {
      final rect = Rect.fromCircle(center: center, radius: r);
      final zp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xCCFF5A7A);
      for (final z in cfg.deadZones) {
        final world = z.center + diskRotation;
        canvas.drawArc(rect, world - z.halfWidth, 2 * z.halfWidth, false, zp);
      }
    }
  }

  void _renderStars(Canvas canvas) {
    final center = _center;
    final r = _radius;
    final pinLen = _pinLen;
    for (var i = 0; i < stuckAngles.length; i++) {
      final theta = stuckAngles[i] + diskRotation;
      final dir = Offset(cos(theta), sin(theta));
      final end = center + dir * (r + pinLen);
      final col = _colorOf(stuckColors[i]);
      // Ilk cfg.preplaced yildiz engeldir (klasik gorunur); gerisi oyuncunun.
      final isPlayer = i >= cfg.preplaced;
      canvas.drawLine(center, end, Paint()..color = col.withValues(alpha: 0.55)..strokeWidth = 2);
      _drawStar(canvas, end, _baseRadius * 0.17, col, skin: isPlayer ? starSkin : null);
    }
  }

  void _renderFlying(Canvas canvas) {
    final center = _center;
    if (flying) {
      final p = Offset(center.dx, flyingY);
      canvas.drawLine(Offset(center.dx, size.y), p,
          Paint()..color = _colorOf(flyingColor).withValues(alpha: 0.35)..strokeWidth = 2);
      // Kuyruklu yildiz gorunumu: ucarken arkasinda iz birakir
      if (starSkin == 'kuyruklu') {
        for (var k = 1; k <= 4; k++) {
          canvas.drawCircle(
              p + Offset(0, k * 14.0),
              _baseRadius * 0.12 * (1 - k * 0.18),
              Paint()..color = const Color(0xFF66E0FF).withValues(alpha: 0.5 - k * 0.11));
        }
      }
      _drawStar(canvas, p, _baseRadius * 0.17, _colorOf(flyingColor), skin: starSkin);
    } else {
      _drawStar(canvas, Offset(center.dx, size.y - _baseRadius * 1.4), _baseRadius * 0.17,
          _colorOf(nextColor), skin: starSkin);
      _drawText(canvas, t('tapHint'), Offset(center.dx, size.y - _baseRadius * 1.4 - 34), 14,
          const Color(0xAAFFFFFF));
    }
  }

  void _renderShocks(Canvas canvas) {
    for (final s in _shocks) {
      final a = (s.life / s.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        s.pos,
        s.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * a
          ..color = s.color.withValues(alpha: a * 0.8),
      );
    }
  }

  void _renderParticles(Canvas canvas) {
    for (final p in _particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(p.pos, p.radius, Paint()..color = p.color.withValues(alpha: a));
    }
  }

  void _renderFlashes(Canvas canvas) {
    final fullRect = Rect.fromLTWH(0, 0, size.x, size.y);
    if (collisionFlash > 0) {
      canvas.drawRect(fullRect,
          Paint()..color = Color.fromRGBO(255, 70, 70, (collisionFlash / 0.4) * 0.4));
    }
    if (winFlash > 0) {
      canvas.drawRect(fullRect,
          Paint()..color = Color.fromRGBO(120, 230, 255, (winFlash / 0.5) * 0.3));
    }
  }

  void _renderHud(Canvas canvas) {
    _drawText(canvas, t('hudLevel', {'n': '$level'}), Offset(size.x / 2, size.y * 0.06), 24,
        Colors.white, bold: true);
    _drawText(canvas, t('hudStarsLeft', {'n': '${cfg.starCount - pinsPlaced}'}),
        Offset(size.x / 2, size.y * 0.06 + 28), 14, const Color(0xAAFFFFFF));
    // Yildiz Tozu bakiyesi (sag ust)
    _drawText(canvas, '✦ $dust', Offset(size.x - 46, size.y * 0.06), 16,
        const Color(0xFFFFD166), bold: true);
  }

  void _drawStar(Canvas canvas, Offset p, double radius, Color color, {String? skin}) {
    // Skin, oynanis rengini DEGISTIRMEZ; sadece parilti/sekil stilini degistirir.
    var glowColor = color;
    var glowMul = 1.0;
    var sparkleColor = color;
    switch (skin) {
      case 'elmas':
        glowColor = const Color(0xFFBFEFFF);
        sparkleColor = Colors.white;
        break;
      case 'zumrut':
        glowColor = const Color(0xFF7CF5A0);
        sparkleColor = const Color(0xFF7CF5A0);
        break;
      case 'nova':
        glowColor = const Color(0xFFFFB35C);
        sparkleColor = const Color(0xFFFFD166);
        glowMul = 1.8;
        break;
      case 'kuyruklu':
        glowColor = const Color(0xFF66E0FF);
        sparkleColor = const Color(0xFF66E0FF);
        glowMul = 1.4;
        break;
    }

    canvas.drawCircle(
        p,
        radius * 2.4 * glowMul,
        Paint()
          ..color = glowColor.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    final sparkle = Paint()
      ..color = sparkleColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(p + Offset(-radius * 2.6, 0), p + Offset(radius * 2.6, 0), sparkle);
    canvas.drawLine(p + Offset(0, -radius * 2.6), p + Offset(0, radius * 2.6), sparkle);

    if (skin == 'elmas') {
      // Elmas: dondurulmus kare cekirdek
      final path = Path()
        ..moveTo(p.dx, p.dy - radius * 1.2)
        ..lineTo(p.dx + radius * 1.2, p.dy)
        ..lineTo(p.dx, p.dy + radius * 1.2)
        ..lineTo(p.dx - radius * 1.2, p.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = Colors.white);
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = color);
    } else {
      canvas.drawCircle(p, radius, Paint()..color = Colors.white);
      canvas.drawCircle(p, radius * 0.6, Paint()..color = color);
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double fontSize, Color color,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          letterSpacing: bold ? 1.2 : 0.4,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}
