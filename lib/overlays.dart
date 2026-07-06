import 'package:flutter/material.dart';
import 'game.dart';
import 'strings.dart';

// Tema renkleri
const _bg = Color(0xFF0B1026);
const _cyan = Color(0xFF66E0FF);
const _gold = Color(0xFFFFD166);
const _green = Color(0xFF7CF5A0);
const _red = Color(0xFFFF3B67);
const _ink = Color(0xFF08111F);

/// Oyunun uzerine binen tum menu/arayuz ekranlari.
/// Oyun durumuna (uiState) ve menu acik/kapali (menuOpen) durumuna gore degisir.
class ConstellaUi extends StatelessWidget {
  final ConstellaGame game;
  const ConstellaUi({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([game.uiState, game.panel, game.uiTick, game.toast]),
      builder: (context, _) {
        final s = game.uiState.value;
        Widget screen;
        switch (s) {
          case GState.onboarding:
            screen = _onboarding();
            break;
          case GState.title:
            screen = _title();
            break;
          case GState.levelComplete:
            screen = _levelComplete();
            break;
          case GState.gameOver:
            screen = _gameOver();
            break;
          case GState.playing:
          case GState.connecting:
          case GState.dying:
            // Oyun/orme/olum efekti sirasinda ekran bos: canvas efektleri gorunsun.
            screen = const SizedBox.shrink();
            break;
        }
        return Stack(
          children: [
            screen,
            if (game.panel.value == 'settings') _settings(),
            if (game.panel.value == 'shop') _shop(),
            if (game.toast.value != null) _toastBanner(game.toast.value!),
          ],
        );
      },
    );
  }

  // ---------------- Ekranlar ----------------

  Widget _onboarding() {
    return _fullScreen(
      children: [
        _logo(40),
        const SizedBox(height: 6),
        _text(t('howtoTitle'), 18, const Color(0xCC99DDFF)),
        const SizedBox(height: 26),
        _howtoLine('1', t('howto1')),
        _howtoLine('2', t('howto2')),
        _howtoLine('3', t('howto3')),
        _howtoLine('4', t('howto4')),
        const SizedBox(height: 32),
        _bigButton(t('start'), game.uiOnboardingDone),
      ],
    );
  }

  Widget _title() {
    return Positioned.fill(
      child: Container(
        color: _bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Stack(
            children: [
              // Sol ust: gunluk seri (HUD kosesi)
              if (game.streak > 0)
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _cornerChip(
                      const _FlameBadge(Color(0xFFFF8A50)),
                      '${game.streak}',
                      valueColor: const Color(0xFFF2B27A),
                    ),
                  ),
                ),
              // Sag ust: yildiz tozu bakiyesi (HUD kosesi)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _cornerChip(const _StarBadge(_gold), '${game.dust}',
                      valueColor: const Color(0xFFFFE0A3)),
                ),
              ),
              // Orta govde
              Align(
                alignment: const Alignment(0, -0.35),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _logoBlock(),
                      const SizedBox(height: 4),
                      _text(t('tagline'), 14, const Color(0xCC99DDFF)),
                      const SizedBox(height: 26),
                      _questCard(),
                      const SizedBox(height: 22),
                      _bigButton(
                          game.savedLevel > 1
                              ? t('playLevel', {'n': '${game.savedLevel}'})
                              : t('play'),
                          game.uiStart),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: _iconButton(
                                  const _GemIcon(_gold), t('store'), game.openShop,
                                  accent: _gold)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _iconButton(const _SlidersIcon(Color(0xFFB9A6FF)),
                                  t('menu'), game.openMenu,
                                  accent: const Color(0xFFB9A6FF))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _statsRow(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kose HUD gostergesi: kutu/cerceve YOK — ikon ve sayi gece gogunde
  /// serbestce durur, kendi isigini sacar. Sol ust seri, sag ust toz.
  Widget _cornerChip(CustomPainter icon, String value, {required Color valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 18, height: 19, child: CustomPaint(painter: icon)),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              shadows: [
                Shadow(color: valueColor.withValues(alpha: 0.9), blurRadius: 12),
                Shadow(color: valueColor.withValues(alpha: 0.5), blurRadius: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Marka amblemi: kucuk pirilti kumesi + parlayan gradyanli "CONSTELLA" yazisi.
  Widget _logoBlock() {
    return SizedBox(
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_cyan.withValues(alpha: 0.24), Colors.transparent],
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 46, height: 16, child: CustomPaint(painter: _TwinkleCluster())),
              const SizedBox(height: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFCDF3FF)],
                ).createShader(bounds),
                child: _logo(46),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton(CustomPainter icon, String label, VoidCallback onTap,
      {required Color accent}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.02)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.30), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 24, height: 24, child: CustomPaint(painter: icon)),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                  color: Color(0xDDFFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                )),
          ],
        ),
      ),
    );
  }

  /// En uzak bolum rozeti (toz artik sag ust kosede).
  Widget _statsRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
            width: 15,
            height: 15,
            child: CustomPaint(painter: _MiniConstellationBadge(_cyan))),
        const SizedBox(width: 8),
        Text(t('bestLevel', {'n': '${game.bestLevel}'}),
            style: const TextStyle(
                color: Color(0x99FFFFFF), fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _levelComplete() {
    return _fullScreen(
      children: [
        _text(t('level', {'n': '${game.level - 1}'}), 22, const Color(0xCCFFFFFF), bold: true),
        const SizedBox(height: 6),
        _text(t('completed'), 40, _green, bold: true),
        const SizedBox(height: 14),
        _text(t('dustEarned', {'n': '${game.lastDustEarned}'}), 20, _gold, bold: true),
        _text(t('dustTotal', {'n': '${game.dust}'}), 13, const Color(0x88FFFFFF)),
        const SizedBox(height: 30),
        _bigButton(t('nextLevel'), game.uiNext),
        const SizedBox(height: 12),
        _outlineButton(t('mainMenu'), game.uiToMenu),
        const SizedBox(height: 16),
        _text(t('upNext', {'n': '${game.level}'}), 13, const Color(0x88FFFFFF)),
      ],
    );
  }

  Widget _gameOver() {
    return _fullScreen(
      children: [
        // aa tarzi kirmizi cerceveli FAIL kutusu
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          decoration: BoxDecoration(
            border: Border.all(color: _red, width: 3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _text(t('failed'), 44, _red, bold: true),
              _text(t('retryLevelCaps'), 18, _red, bold: true),
            ],
          ),
        ),
        const SizedBox(height: 30),
        // Devam etmenin iki yolu (bolum basina 1 kez): reklam izle ya da toz harca
        if (!game.continueUsed) ...[
          _goldButton(t('continueWithAd'), game.uiContinueWithAd),
          const SizedBox(height: 10),
          _outlineButton(
              t('continueWithDust', {'cost': '$kContinueDustCost'}), game.uiContinueWithDust),
          const SizedBox(height: 12),
        ],
        _bigButton(t('retryLevel', {'n': '${game.savedLevel}'}), game.uiRetry),
        const SizedBox(height: 12),
        _outlineButton(t('mainMenu'), game.uiToMenu),
      ],
    );
  }

  Widget _settings() {
    return Positioned.fill(
      child: Container(
        color: _bg,
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _logo(24),
                    const SizedBox(height: 14),

                    _sectionTitle(t('language')),
                    const SizedBox(height: 6),
                    _languageRow(),
                    const SizedBox(height: 16),

                    _sectionTitle(t('sound')),
                    const SizedBox(height: 6),
                    _audioRow(t('music'), game.musicOn, game.toggleMusic, game.musicVolume,
                        game.setMusicVolume),
                    const SizedBox(height: 6),
                    _audioRow(t('effects'), game.sfxOn, game.toggleSfx, game.sfxVolume,
                        game.setSfxVolume),
                    const SizedBox(height: 16),

                    _sectionTitle(t('store')),
                    const SizedBox(height: 8),
                    _shopButton(t('skipLevelItem'), t('skipLevelDesc'),
                        () => game.showToast(t('comingSoon'))),
                    const SizedBox(height: 8),
                    _shopButton(t('godMode'), t('godModeDesc'),
                        () => game.showToast(t('comingSoon'))),
                    const SizedBox(height: 8),
                    _shopButton(t('monthlyMembership'), t('monthlyDesc'),
                        () => game.showToast(t('comingSoon'))),
                    const SizedBox(height: 16),

                    _sectionTitle(t('other')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _outlineButton(
                                t('share'), () => game.showToast(t('comingSoon')))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _outlineButton(
                                t('rate'), () => game.showToast(t('comingSoon')))),
                      ],
                    ),
                    if (game.uiState.value == GState.playing) ...[
                      const SizedBox(height: 8),
                      _outlineButton(t('mainMenu'), game.uiToMenu),
                    ],
                    const SizedBox(height: 14),
                    _bigButton(t('close'), game.closeMenu),
                  ],
                ),
              ),
              // Sag ust kapatma (X)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: GestureDetector(
                    onTap: game.closeMenu,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x55FFFFFF), width: 1.5),
                      ),
                      child: const Text('✕',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Baslikta gunluk gorev karti: "Gorev: 3 bolum gec (1/3)  → +50 ✦"
  /// Gunluk gorev karti. Ilerleme, oyunun temasina uygun sekilde
  /// "isiklanan mini takimyildiz" olarak gosterilir: her hedef bir yildiz,
  /// tamamladikca yildizlar yanar ve aralarindaki iplik parlar.
  Widget _questCard() {
    final label = game.questType == 'levels'
        ? t('questLevels', {'n': '${game.questTarget}'})
        : t('questNearmiss', {'n': '${game.questTarget}'});
    final done = game.questDone;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 15),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: done ? _green.withValues(alpha: 0.45) : const Color(0x26FFFFFF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t('dailyQuestLabel'),
                  style: const TextStyle(
                    color: Color(0x77FFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.2,
                  )),
              const Spacer(),
              if (!done)
                Row(
                  children: [
                    const SizedBox(
                        width: 11, height: 11, child: CustomPaint(painter: _StarBadge(_gold))),
                    const SizedBox(width: 5),
                    const Text('+50',
                        style: TextStyle(
                            color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                )
              else
                Text('${game.questProgress}/${game.questTarget}',
                    style: const TextStyle(
                        color: _green, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            done ? t('dailyQuestDone') : label,
            style: TextStyle(
              color: done ? _green : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 20,
            child: CustomPaint(
              painter: _QuestConstellationPainter(
                total: game.questTarget,
                lit: done ? game.questTarget : game.questProgress,
                done: done,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Satin alma onay penceresi. true = onaylandi, false/null = vazgecildi.
  /// Genel satin alma onay penceresi (yildiz gorunumu ya da cekirdek temasi
  /// icin ortak). true = onaylandi, false/null = vazgecildi.
  Future<bool?> _confirmPurchase(BuildContext context,
      {required String name, required int price, required CustomPainter preview}) {
    final enough = game.dust >= price;
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0xCC000000),
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF141F38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 56, height: 56, child: CustomPaint(painter: preview)),
              const SizedBox(height: 14),
              Text(t('confirmPurchaseTitle', {'name': name}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                enough
                    ? t('confirmPurchaseBody', {'price': '$price', 'balance': '${game.dust}'})
                    : t('insufficientBalanceBody',
                        {'price': '$price', 'balance': '${game.dust}'}),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: enough ? const Color(0xCCFFFFFF) : const Color(0xFFFF7AB3),
                    fontSize: 14),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _outlineButton(t('cancel'), () => Navigator.of(ctx).pop(false)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: enough
                        ? _goldButton(t('buy'), () => Navigator.of(ctx).pop(true))
                        : _disabledButton(t('buy')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Magazadaki tek bir urun sirasi (yildiz gorunumu ya da cekirdek temasi
  /// icin ortak kullanilir): onizleme + ad + sec/satin-al durumu.
  Widget _productRow({
    required CustomPainter preview,
    required String name,
    required bool owned,
    required bool selected,
    required int price,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? _gold : const Color(0x44FFFFFF), width: selected ? 2 : 1.4),
        ),
        child: Row(
          children: [
            SizedBox(width: 44, height: 44, child: CustomPaint(painter: preview)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? _gold : (owned ? const Color(0x33FFFFFF) : Colors.transparent),
                borderRadius: BorderRadius.circular(10),
                border: owned ? null : Border.all(color: _gold, width: 1.2),
              ),
              child: Text(
                selected ? t('selected') : (owned ? t('select') : '✦ $price'),
                style: TextStyle(
                  color: selected ? _ink : (owned ? Colors.white : _gold),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disabledButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label,
            maxLines: 1,
            style: const TextStyle(
                color: Color(0x66FFFFFF), fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ---------------- MAGAZA: yildiz gorunumleri + cekirdek temalari ----------------
  Widget _shop() {
    return _panelScaffold(
      title: t('store'),
      subtitle: t('dustBalance', {'n': '${game.dust}'}),
      child: Builder(builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _sectionTitle(t('starsSection')),
            const SizedBox(height: 10),
            for (final s in kSkins) ...[
              _productRow(
                preview: _SkinPreviewPainter(s.id),
                name: skinName(s.id),
                owned: game.unlockedSkins.contains(s.id),
                selected: game.starSkin == s.id,
                price: s.price,
                onTap: () async {
                  if (game.unlockedSkins.contains(s.id)) {
                    game.tapSkin(s.id);
                    return;
                  }
                  final confirmed = await _confirmPurchase(context,
                      name: skinName(s.id), price: s.price, preview: _SkinPreviewPainter(s.id));
                  if (confirmed == true) game.tapSkin(s.id);
                },
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 18),
            _sectionTitle(t('coresSection')),
            const SizedBox(height: 10),
            for (final c in kCoreThemes) ...[
              _productRow(
                preview: _CoreThemePreviewPainter(c.color),
                name: coreThemeName(c.id),
                owned: game.unlockedCoreThemes.contains(c.id),
                selected: game.coreTheme == c.id,
                price: c.price,
                onTap: () async {
                  if (game.unlockedCoreThemes.contains(c.id)) {
                    game.tapCoreTheme(c.id);
                    return;
                  }
                  final confirmed = await _confirmPurchase(context,
                      name: coreThemeName(c.id),
                      price: c.price,
                      preview: _CoreThemePreviewPainter(c.color));
                  if (confirmed == true) game.tapCoreTheme(c.id);
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      }),
    );
  }

  /// Shop icin ortak iskelet: baslik + kapat + kaydirilabilir icerik.
  Widget _panelScaffold(
      {required String title, required String subtitle, required Widget child}) {
    return Positioned.fill(
      child: Container(
        color: _bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
                          Text(subtitle,
                              style: const TextStyle(color: _gold, fontSize: 14)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: game.closeMenu,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x55FFFFFF), width: 1.5),
                        ),
                        child:
                            const Text('✕', style: TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toastBanner(String msg) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 60,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xEE1B2A4A),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0x5566E0FF)),
          ),
          child: Text(msg,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  /// Kompakt dil secici: mevcut dili gosteren kucuk bir satir; dokununca
  /// tum diller bir alt-panelde (bottom sheet) acilir.
  Widget _languageRow() {
    return Builder(builder: (context) {
      return GestureDetector(
        onTap: () => _openLanguageSheet(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.language_rounded, color: Color(0xCCFFFFFF), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(kLangNames[L.current]!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0x99FFFFFF), size: 22),
            ],
          ),
        ),
      );
    });
  }

  void _openLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141F38),
      barrierColor: const Color(0xAA000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    shrinkWrap: true,
                    children: [
                      for (final lang in Lang.values) _langSheetRow(ctx, lang),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _langSheetRow(BuildContext ctx, Lang lang) {
    final selected = L.current == lang;
    return GestureDetector(
      onTap: () {
        game.setLanguage(lang);
        Navigator.of(ctx).pop();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _gold.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _gold : const Color(0x22FFFFFF), width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(kLangNames[lang]!,
                  style: TextStyle(
                    color: selected ? _gold : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  )),
            ),
            if (selected) const Icon(Icons.check_rounded, color: _gold, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _audioRow(String label, bool on, VoidCallback onToggle, double vol,
      ValueChanged<double> onVol) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            _miniToggle(on, onToggle),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.volume_mute, color: Color(0x88FFFFFF), size: 18),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: vol.clamp(0.0, 1.0),
                  activeColor: _cyan,
                  inactiveColor: const Color(0x33FFFFFF),
                  onChanged: on ? onVol : null,
                ),
              ),
            ),
            const Icon(Icons.volume_up, color: Color(0x88FFFFFF), size: 18),
          ],
        ),
      ],
    );
  }

  Widget _miniToggle(bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: on ? _gold : const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          on ? t('on') : t('off'),
          style: TextStyle(
            color: on ? _ink : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _shopButton(String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x55FFFFFF), width: 1.6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('PRO',
                  style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Yapi taslari ----------------

  Widget _fullScreen({required List<Widget> children, Alignment alignment = Alignment.center}) {
    return Positioned.fill(
      child: Container(
        color: _bg, // tam opak: arkadaki oyun gorunmez
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _logo(double size) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          t('appName'),
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _text(String s, double size, Color color, {bool bold = false}) {
    return Text(
      s,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        letterSpacing: bold ? 1.2 : 0.3,
      ),
    );
  }

  Widget _sectionTitle(String s) {
    return Text(
      s,
      style: const TextStyle(
        color: Color(0x88FFFFFF),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }

  Widget _howtoLine(String num, String s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _cyan.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(num, style: const TextStyle(color: _cyan, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _bigButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 17),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8FEBFF), _cyan],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: _cyan.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// Odullu reklam butonu: altin renkli, dikkat ceker.
  Widget _goldButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE29A), _gold],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: _gold.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlineButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.01)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x66FFFFFF), width: 1.6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Magazadaki yildiz gorunumu onizlemesi.
/// Magazadaki cekirdek temasi onizlemesi: oyun ici merkez diskin kucuk hali.
class _CoreThemePreviewPainter extends CustomPainter {
  final Color color;
  const _CoreThemePreviewPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.3;
    canvas.drawCircle(
        c,
        r * 1.9,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF141F38));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color);
  }

  @override
  bool shouldRepaint(_CoreThemePreviewPainter old) => old.color != color;
}

class _SkinPreviewPainter extends CustomPainter {
  final String skin;
  _SkinPreviewPainter(this.skin);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Offset(size.width / 2, size.height / 2);
    const r = 6.0;

    Color glow;
    switch (skin) {
      case 'elmas':
        glow = const Color(0xFFBFEFFF);
        break;
      case 'zumrut':
        glow = const Color(0xFF7CF5A0);
        break;
      case 'nova':
        glow = const Color(0xFFFFB35C);
        break;
      case 'kuyruklu':
        glow = const Color(0xFF66E0FF);
        break;
      default:
        glow = const Color(0xFF66E0FF);
    }

    canvas.drawCircle(
        p,
        r * 2.6,
        Paint()
          ..color = glow.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    final sparkle = Paint()
      ..color = glow.withValues(alpha: 0.7)
      ..strokeWidth = 1.4;
    canvas.drawLine(p + const Offset(-r * 2.4, 0), p + const Offset(r * 2.4, 0), sparkle);
    canvas.drawLine(p + const Offset(0, -r * 2.4), p + const Offset(0, r * 2.4), sparkle);

    if (skin == 'kuyruklu') {
      for (var k = 1; k <= 3; k++) {
        canvas.drawCircle(p + Offset(k * 6.0, k * 6.0), r * (1 - k * 0.22),
            Paint()..color = glow.withValues(alpha: 0.5 - k * 0.13));
      }
    }

    if (skin == 'elmas') {
      final path = Path()
        ..moveTo(p.dx, p.dy - r * 1.3)
        ..lineTo(p.dx + r * 1.3, p.dy)
        ..lineTo(p.dx, p.dy + r * 1.3)
        ..lineTo(p.dx - r * 1.3, p.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = Colors.white);
    } else {
      canvas.drawCircle(p, r, Paint()..color = Colors.white);
      canvas.drawCircle(p, r * 0.6, Paint()..color = glow);
    }
  }

  @override
  bool shouldRepaint(_SkinPreviewPainter old) => old.skin != skin;
}

/// Gokyuzu haritasindaki takimyildiz karti cizimi.
/// Logo ustundeki mini pirilti kumesi: emoji/Material ikon yerine,
/// oyunun kendi yildiz gorseline uyan ozgun bir amblem.
class _TwinkleCluster extends CustomPainter {
  const _TwinkleCluster();

  void _star(Canvas canvas, Offset c, double r, double alpha) {
    canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: alpha));
    final spark = Paint()
      ..color = const Color(0xFF9FE8FF).withValues(alpha: alpha * 0.9)
      ..strokeWidth = 1;
    canvas.drawLine(c - Offset(r * 2.4, 0), c + Offset(r * 2.4, 0), spark);
    canvas.drawLine(c - Offset(0, r * 2.4), c + Offset(0, r * 2.4), spark);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _star(canvas, Offset(size.width * 0.5, size.height * 0.55), 3.2, 1.0);
    _star(canvas, Offset(size.width * 0.16, size.height * 0.75), 1.6, 0.7);
    _star(canvas, Offset(size.width * 0.84, size.height * 0.35), 1.8, 0.75);
  }

  @override
  bool shouldRepaint(covariant _TwinkleCluster oldDelegate) => false;
}

/// Kucuk parlayan yildiz rozeti (emoji '✦' yerine): stat pillerinde kullanilir.
class _StarBadge extends CustomPainter {
  final Color color;
  const _StarBadge(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.22;
    canvas.drawCircle(
        c,
        r * 2.4,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    final spark = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.3;
    canvas.drawLine(c - Offset(r * 2.1, 0), c + Offset(r * 2.1, 0), spark);
    canvas.drawLine(c - Offset(0, r * 2.1), c + Offset(0, r * 2.1), spark);
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(c, r * 0.55, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StarBadge old) => old.color != color;
}

/// Kucuk parlayan alev rozeti (emoji '🔥' yerine): gunluk seri gostergesi.
class _FlameBadge extends CustomPainter {
  final Color color;
  const _FlameBadge(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Yumusak arka isima
    canvas.drawCircle(
        Offset(w * 0.5, h * 0.62),
        w * 0.5,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Dis alev: kivrik uc + sol omuz + genis govde (klasik ates silueti)
    final flame = Path()
      // uc (hafif saga yatik)
      ..moveTo(w * 0.60, h * 0.02)
      // sag yanak: disa dogru sisip govdeye inen buyuk kavis
      ..cubicTo(w * 0.68, h * 0.20, w * 0.94, h * 0.32, w * 0.91, h * 0.58)
      // sag alt -> tabana
      ..cubicTo(w * 0.89, h * 0.83, w * 0.72, h * 0.99, w * 0.50, h * 0.99)
      // taban -> sol alt
      ..cubicTo(w * 0.28, h * 0.99, w * 0.11, h * 0.83, w * 0.09, h * 0.58)
      // sol yanak: yukari incelerek omuza
      ..cubicTo(w * 0.075, h * 0.40, w * 0.20, h * 0.31, w * 0.30, h * 0.14)
      // centik: iceri cukur yapip kivrilarak uca baglanir (alevi alev yapan detay)
      ..cubicTo(w * 0.33, h * 0.27, w * 0.43, h * 0.34, w * 0.50, h * 0.29)
      ..cubicTo(w * 0.56, h * 0.24, w * 0.585, h * 0.13, w * 0.60, h * 0.02)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFFFB25C), color, const Color(0xFFE03A18)],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Ic alev: govdenin icinde sicak sari-beyaz damla cekirdek
    final inner = Path()
      ..moveTo(w * 0.50, h * 0.46)
      ..cubicTo(w * 0.66, h * 0.62, w * 0.66, h * 0.82, w * 0.50, h * 0.88)
      ..cubicTo(w * 0.34, h * 0.82, w * 0.34, h * 0.62, w * 0.50, h * 0.46)
      ..close();
    canvas.drawPath(
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF3C4), Color(0xFFFFD166)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(_FlameBadge old) => old.color != color;
}

/// Gunluk gorev ilerlemesi: hedef sayisi kadar yildiz, aralarinda iplik.
/// Tamamlanan yildizlar yanar, iplikleri parlar — oyunun kendi metaforu.
class _QuestConstellationPainter extends CustomPainter {
  final int total;
  final int lit;
  final bool done;
  const _QuestConstellationPainter({required this.total, required this.lit, required this.done});

  @override
  void paint(Canvas canvas, Size size) {
    if (total < 1) return;
    final cy = size.height / 2;
    final pad = 8.0;
    // Duz cizgi degil, hafif zikzak: gercek takimyildiz hissi
    final pts = <Offset>[];
    for (var i = 0; i < total; i++) {
      final x = total == 1
          ? size.width / 2
          : pad + (size.width - 2 * pad) * i / (total - 1);
      final y = cy + (i.isEven ? -3.0 : 3.0);
      pts.add(Offset(x, y));
    }

    final litColor = done ? _green : _cyan;
    // Iplikler
    for (var i = 0; i < total - 1; i++) {
      final isLit = (i + 1) < lit || (lit >= total);
      final segLit = i < lit - 1;
      canvas.drawLine(
        pts[i],
        pts[i + 1],
        Paint()
          ..color = (segLit || isLit)
              ? litColor.withValues(alpha: 0.8)
              : const Color(0x24FFFFFF)
          ..strokeWidth = segLit ? 1.6 : 1.1,
      );
    }
    // Yildizlar
    for (var i = 0; i < total; i++) {
      final isLit = i < lit;
      final p = pts[i];
      if (isLit) {
        canvas.drawCircle(
            p,
            6,
            Paint()
              ..color = litColor.withValues(alpha: 0.45)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        final spark = Paint()
          ..color = litColor.withValues(alpha: 0.8)
          ..strokeWidth = 1;
        canvas.drawLine(p - const Offset(6, 0), p + const Offset(6, 0), spark);
        canvas.drawLine(p - const Offset(0, 6), p + const Offset(0, 6), spark);
        canvas.drawCircle(p, 2.6, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(
            p,
            2.4,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = const Color(0x44FFFFFF));
      }
    }
  }

  @override
  bool shouldRepaint(_QuestConstellationPainter old) =>
      old.total != total || old.lit != lit || old.done != done;
}


/// STORE butonu ikonu: fasetli mucevher (magazanin kozmetik dogasina uygun).
class _GemIcon extends CustomPainter {
  final Color color;
  const _GemIcon(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final top = h * 0.18, mid = h * 0.42, bot = h * 0.88;
    final l = w * 0.12, r = w * 0.88;
    final tl = Offset(w * 0.32, top), tr = Offset(w * 0.68, top);
    final ml = Offset(l, mid), mr = Offset(r, mid);
    final bp = Offset(w * 0.5, bot);

    final gem = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(mr.dx, mr.dy)
      ..lineTo(bp.dx, bp.dy)
      ..lineTo(ml.dx, ml.dy)
      ..close();
    canvas.drawPath(
        gem,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(
      gem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, color],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // Faset cizgileri
    final facet = Paint()
      ..color = const Color(0x55081120)
      ..strokeWidth = 1;
    canvas.drawLine(ml, mr, facet);
    canvas.drawLine(tl, Offset(w * 0.38, mid), facet);
    canvas.drawLine(tr, Offset(w * 0.62, mid), facet);
    canvas.drawLine(Offset(w * 0.38, mid), bp, facet);
    canvas.drawLine(Offset(w * 0.62, mid), bp, facet);
  }

  @override
  bool shouldRepaint(_GemIcon old) => old.color != color;
}

/// MENU butonu ikonu: uc ayar surgusu (dislinin daha zarif alternatifi).
class _SlidersIcon extends CustomPainter {
  final Color color;
  const _SlidersIcon(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final knobGlow = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final knob = Paint()..color = Colors.white;
    final knobCore = Paint()..color = color;

    final rows = [h * 0.24, h * 0.52, h * 0.80];
    final knobX = [w * 0.68, w * 0.32, w * 0.55];
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(Offset(w * 0.10, rows[i]), Offset(w * 0.90, rows[i]), track);
      final k = Offset(knobX[i], rows[i]);
      canvas.drawCircle(k, 4.2, knobGlow);
      canvas.drawCircle(k, 3.0, knob);
      canvas.drawCircle(k, 1.6, knobCore);
    }
  }

  @override
  bool shouldRepaint(_SlidersIcon old) => old.color != color;
}

/// Kucuk baglantili yildiz rozeti (emoji '🏆' yerine): en uzak bolum gostergesi.
/// Oyunun kendi "yildizlari birbirine bagla" temasina birebir uyar.
class _MiniConstellationBadge extends CustomPainter {
  final Color color;
  const _MiniConstellationBadge(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [
      Offset(size.width * 0.2, size.height * 0.78),
      Offset(size.width * 0.56, size.height * 0.2),
      Offset(size.width * 0.84, size.height * 0.62),
    ];
    final line = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1.3;
    canvas.drawLine(pts[0], pts[1], line);
    canvas.drawLine(pts[1], pts[2], line);
    for (final p in pts) {
      canvas.drawCircle(
          p,
          3,
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawCircle(p, 1.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_MiniConstellationBadge old) => old.color != color;
}
