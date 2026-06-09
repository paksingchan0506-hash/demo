import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // 1. 引入這個

class AdMobConfig {
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const String androidRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String iosRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  static const List<String> testDeviceIds = <String>[
    'A1C83B99CFE9B3DF38575B69679776C4',
  ];

  static String get rewardedAdUnitId {
    // 2. 首先判斷是不是 Web，如果是，直接回傳空字串或報錯，避免執行 Platform 判斷
    if (kIsWeb) {
      return ''; // 或者處理 Web 版的廣告邏輯
    }

    // 3. 只有不是 Web 的情況下，才呼叫 Platform.isAndroid
    if (Platform.isAndroid) return androidRewardedAdUnitId;
    if (Platform.isIOS) return iosRewardedAdUnitId;
    
    throw UnsupportedError('Unsupported platform');
  }
}
