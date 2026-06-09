import 'package:flutter/material.dart';

import '../config/admob_config.dart';
import 'rewarded_ad_service.dart';
import 'storage_service.dart';

enum MiniGameId { roulette, memory }

class MiniGameAccessService {
  static final MiniGameAccessService _instance =
      MiniGameAccessService._internal();
  factory MiniGameAccessService() => _instance;
  MiniGameAccessService._internal();

  final StorageService _storage = StorageService();
  final RewardedAdService _ads = RewardedAdService();

  Future<bool> ensureCanPlay(BuildContext context, MiniGameId gameId) async {
    final key = 'mini_game_first_play_used_${gameId.name}';
    final firstPlayUsed = (await _storage.getBool(key)) ?? false;

    if (!firstPlayUsed) {
      await _storage.saveBool(key, true);
      return true;
    }

    final shouldWatch = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('觀看廣告開始遊玩'),
          content: const Text('從第二次開始需完整觀看獎勵式廣告，才能獲得一次遊玩機會。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('觀看'),
            ),
          ],
        );
      },
    );

    if (shouldWatch != true) return false;

    if (!context.mounted) return false;

    final loading = showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    final rewarded = await _ads.showForReward(
      adUnitId: AdMobConfig.rewardedAdUnitId,
    );

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    await loading;

    if (!rewarded && context.mounted) {
      final errorSummary = _ads.lastErrorSummary;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorSummary == null
                ? '未成功取得獎勵，請完整觀看廣告後再試一次'
                : '未成功取得獎勵，請再試一次（$errorSummary）',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }

    return rewarded;
  }
}
