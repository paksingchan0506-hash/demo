import 'package:flutter/foundation.dart';

class AppConfig {
  /// 測試環境開關：true = 啟用假儲值（跳過真實支付）
  static const bool enableMockRecharge = kDebugMode;
}