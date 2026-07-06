import 'dart:math';

/// Cekirdek uzerinde yasak bir yay (toz bulutu). Buraya saplarsan patlar.
class DeadZone {
  final double center; // radyan (disk-relative)
  final double halfWidth;
  const DeadZone(this.center, this.halfWidth);
}

/// Bir bolumun tum parametreleri.
class LevelConfig {
  final int level;
  final int starCount;
  final double baseSpeed;
  final int direction;
  final double pulseAmp;
  final double pulseFreq;
  final double flipTurns; // yon degistirmeden once atilacak tam tur (0 = degismez)
  final int preplaced;
  final List<DeadZone> deadZones;
  final double radiusPulse;
  final double joltMag;
  final bool colorMode;
  final int segCount;
  final List<int> segColorIdx;
  final bool boss;
  final String descriptor;

  const LevelConfig({
    required this.level,
    required this.starCount,
    required this.baseSpeed,
    required this.direction,
    required this.pulseAmp,
    required this.pulseFreq,
    required this.flipTurns,
    required this.preplaced,
    required this.deadZones,
    required this.radiusPulse,
    required this.joltMag,
    required this.colorMode,
    required this.segCount,
    required this.segColorIdx,
    required this.boss,
    required this.descriptor,
  });
}

const double kGap = 0.45;

/// Bolum numarasindan deterministik bir LevelConfig uretir.
/// Zorluk YAVAS artar: erken bolumler sade, mekanikler gec acilir ve
/// ayni anda cok az mekanik bir arada olur ("zorluk butcesi").
LevelConfig generateLevel(int level) {
  final rng = Random(level * 7919 + 101);

  // --- Yumusak temel ---
  int starCount = 3 + level ~/ 3; // L1-2=3, L3=4, L6=5, L9=6, L12=7...
  if (starCount > 12) starCount = 12;
  double baseSpeed = 0.40 + level * 0.035; // yavas artan hiz
  if (baseSpeed > 1.8) baseSpeed = 1.8;
  int direction = level.isEven ? -1 : 1;

  // --- Zorluk butcesi: ayni anda kac ozel mekanik? ---
  int budget;
  if (level < 5) {
    budget = 0; // ilk bolumler sadece don + sapla
  } else if (level < 10) {
    budget = 1;
  } else if (level < 17) {
    budget = 2;
  } else if (level < 26) {
    budget = 3;
  } else {
    budget = 4;
  }

  // --- Aday mekanikler (acilis seviyesi + sans) ---
  final candidates = <String>[];
  void consider(String key, int unlockLevel, double prob) {
    if (level >= unlockLevel && rng.nextDouble() < prob) candidates.add(key);
  }

  consider('pulse', 5, 0.6);
  consider('preplaced', 8, 0.7);
  consider('color', 10, 0.55);
  consider('flip', 14, 0.5);
  consider('jolt', 16, 0.5);
  consider('dead', 18, 0.6);
  consider('radius', 22, 0.5);

  candidates.shuffle(rng);
  final active = candidates.take(budget).toSet();

  // Renk modu aktifse toz/nefes'i temizle (kafa karistirmasin, cozulebilir kalsin)
  if (active.contains('color')) {
    active.remove('dead');
    active.remove('radius');
  }

  // --- Parametreleri aktif mekaniklere gore ayarla (yumusak degerler) ---
  double pulseAmp = 0;
  double pulseFreq = 0;
  if (active.contains('pulse')) {
    pulseAmp = 0.22 + rng.nextDouble() * min(0.3, level * 0.015);
    pulseFreq = 0.8 + rng.nextDouble() * 1.4;
  }

  int preplaced = 0;
  if (active.contains('preplaced')) {
    preplaced = 1 + rng.nextInt(1 + min(3, level ~/ 10));
  }

  bool colorMode = false;
  int segCount = 0;
  final segColorIdx = <int>[];
  if (active.contains('color')) {
    colorMode = true;
    segCount = 2 + (level - 10) ~/ 12; // yavas buyur: 2 -> 3 -> 4
    if (segCount > 4) segCount = 4;
    if (segCount < 2) segCount = 2;
    final idx = List<int>.generate(segCount, (i) => i);
    idx.shuffle(rng);
    segColorIdx.addAll(idx);
  }

  double flipTurns = 0;
  if (active.contains('flip')) flipTurns = 1.0 + rng.nextDouble();

  double joltMag = 0;
  if (active.contains('jolt')) joltMag = 2.0 + rng.nextDouble() * 2.0;

  final zones = <DeadZone>[];
  if (active.contains('dead')) {
    final count = 1 + rng.nextInt(1 + min(2, level ~/ 14));
    for (var i = 0; i < count; i++) {
      zones.add(DeadZone(rng.nextDouble() * 2 * pi, 0.16 + rng.nextDouble() * 0.16));
    }
  }

  double radiusPulse = 0;
  if (active.contains('radius')) radiusPulse = 0.08 + rng.nextDouble() * 0.10;

  // --- Boss: ilk boss 20. bolumde, sonra her 10'da. Yumusak. ---
  final boss = level >= 20 && level % 10 == 0;
  if (boss) {
    if (pulseAmp == 0) {
      pulseAmp = 0.3;
      pulseFreq = 1.5;
    }
    if (flipTurns == 0) flipTurns = 1.5;
    preplaced = max(preplaced, 2);
    baseSpeed = min(2.0, baseSpeed + 0.25);
  }

  // --- Cozulebilirlik: her sey cembere sigmali ---
  double deadCost() => zones.fold(0.0, (s, z) => s + 2 * z.halfWidth);
  const capacity = 2 * pi * 0.82;
  while ((starCount + preplaced) * kGap + deadCost() > capacity &&
      (starCount > 2 || preplaced > 0)) {
    if (preplaced > 0) {
      preplaced--;
    } else {
      starCount--;
    }
  }
  while (zones.isNotEmpty && (starCount + preplaced) * kGap + deadCost() > capacity) {
    zones.removeLast();
  }

  // --- Bolum adi ---
  final tags = <String>[];
  if (colorMode) tags.add('Renk');
  if (pulseAmp > 0) tags.add('Nabiz');
  if (preplaced > 0) tags.add('Kalabalik');
  if (flipTurns > 0) tags.add('Donus');
  if (zones.isNotEmpty) tags.add('Toz Bulutu');
  if (radiusPulse > 0) tags.add('Nefes');
  if (joltMag > 0) tags.add('Sarsinti');
  var descriptor = tags.isEmpty ? 'Sakin' : tags.join(' + ');
  if (boss) descriptor = '★ BOSS ★  $descriptor';

  return LevelConfig(
    level: level,
    starCount: starCount,
    baseSpeed: baseSpeed,
    direction: direction,
    pulseAmp: pulseAmp,
    pulseFreq: pulseFreq,
    flipTurns: flipTurns,
    preplaced: preplaced,
    deadZones: zones,
    radiusPulse: radiusPulse,
    joltMag: joltMag,
    colorMode: colorMode,
    segCount: segCount,
    segColorIdx: segColorIdx,
    boss: boss,
    descriptor: descriptor,
  );
}
