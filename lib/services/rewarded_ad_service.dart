import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  LoadAdError? _lastLoadError;
  AdError? _lastShowError;

  String? get lastErrorSummary {
    final showError = _lastShowError;
    if (showError != null) {
      return 'show(${showError.code}): ${showError.message}';
    }
    final loadError = _lastLoadError;
    if (loadError != null) {
      return 'load(${loadError.code}): ${loadError.message}';
    }
    return null;
  }

  Future<void> preload({required String adUnitId}) async {
    if (_rewardedAd != null || _isLoading) return;
    _isLoading = true;

    final completer = Completer<void>();
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          _lastLoadError = null;
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
          _lastLoadError = error;
          debugPrint(
            'RewardedAd load failed: ${error.code} ${error.message} ${error.domain}',
          );
          completer.completeError(error);
        },
      ),
    );

    return completer.future;
  }

  Future<bool> showForReward({required String adUnitId}) async {
    _lastShowError = null;
    if (_rewardedAd == null) {
      try {
        await preload(adUnitId: adUnitId);
      } catch (_) {
        return false;
      }
    }

    final ad = _rewardedAd;
    if (ad == null) return false;

    final rewardedCompleter = Completer<bool>();
    bool earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        unawaited(preload(adUnitId: adUnitId));
        if (!rewardedCompleter.isCompleted) rewardedCompleter.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _lastShowError = error;
        ad.dispose();
        _rewardedAd = null;
        unawaited(preload(adUnitId: adUnitId));
        if (!rewardedCompleter.isCompleted) rewardedCompleter.complete(false);
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
      },
    );

    return rewardedCompleter.future;
  }
}
