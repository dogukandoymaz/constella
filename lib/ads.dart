import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Reklam servisi.
/// SU AN GOOGLE'IN RESMI TEST ID'LERI KULLANILIYOR — gercek gelir icin
/// yayina cikmadan once AdMob hesabi acilip bu ID'ler degistirilecek.
class AdsService {
  static const bannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const interstitialId = 'ca-app-pub-3940256099942544/4411468910';
  static const rewardedId = 'ca-app-pub-3940256099942544/1712485313';

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool initDone = false;

  Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      initDone = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (_) {}
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (err) => _interstitial = null,
      ),
    );
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (err) => _rewarded = null,
      ),
    );
  }

  bool get interstitialReady => _interstitial != null;
  bool get rewardedReady => _rewarded != null;

  /// Tam ekran gecis reklami goster; kapaninca (ya da yoksa) onDone calisir.
  void showInterstitial(VoidCallback onDone) {
    final ad = _interstitial;
    if (ad == null) {
      onDone();
      return;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        a.dispose();
        _loadInterstitial();
        onDone();
      },
    );
    ad.show();
  }

  /// Odullu reklam: izlerse onReward, izleyemezse/yoksa onUnavailable.
  void showRewarded({
    required VoidCallback onReward,
    required VoidCallback onUnavailable,
  }) {
    final ad = _rewarded;
    if (ad == null) {
      onUnavailable();
      return;
    }
    _rewarded = null;
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        if (earned) onReward();
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        a.dispose();
        _loadRewarded();
        onUnavailable();
      },
    );
    ad.show(onUserEarnedReward: (ad, reward) => earned = true);
  }
}
