import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../providers/user_provider.dart';

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  // 1. 定義積分方案
  final List<Map<String, dynamic>> _packages = [
    {'points': 100, 'price': '8.00', 'bonus': 0},
    {'points': 550, 'price': '38.00', 'bonus': 50},
    {'points': 1200, 'price': '78.00', 'bonus': 150},
    {'points': 2500, 'price': '158.00', 'bonus': 400},
  ];

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('儲值積分'),
            backgroundColor: Colors.grey[900],
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '選擇儲值方案',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // 遍歷顯示方案
              ..._packages.map((pkg) => _buildPackageCard(pkg)),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.amber,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '儲值中...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 方案卡片元件
  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    int totalPoints = pkg['points'] + pkg['bonus'];

    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _handleRecharge(totalPoints),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.stars, color: Colors.amber, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalPoints 積分',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pkg['bonus'] > 0)
                      Text(
                        '包含 ${pkg['bonus']} 額外贈送',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '港元${pkg['price']}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 處理儲值（假儲值或真實支付）
  Future<void> _handleRecharge(int points) async {
    if (_isLoading) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入')));
      return;
    }

    // 測試環境：直接假儲值
    if (AppConfig.enableMockRecharge) {
      await _mockRecharge(points);
      return;
    }

    // 正式環境：跳轉真實支付（這裡先彈提示，後續可串接 Apple/Google Pay）
    _showRealPaymentDialog(points);
  }

  /// 假儲值流程（1.5-2 秒載入動畫）
  Future<void> _mockRecharge(int points) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() => _isLoading = true);

    // 1.5-2 秒動畫
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    // 1:1 兌換，直接加點
    final ok = await userProvider.performACoinTransaction(
      'att009', // 儲值類型（請確保後端有這個 ACoinTransType）
      customDesc: '儲值 $points 積分',
      points: points,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (ok['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('儲值成功！獲得 $points 積分'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('儲值失敗：${ok['message'] ?? '未知錯誤'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 正式環境支付選擇（BottomSheet）
  void _showRealPaymentDialog(int points) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '確認購買 $points 積分',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('總金額：請選擇支付方式', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              _buildPayButton(
                label: 'Apple Pay',
                icon: Icons.apple,
                color: Colors.white,
                onTap: () => _handleRealPay('Apple Pay'),
              ),
              const SizedBox(height: 12),
              _buildPayButton(
                label: 'Google Pay',
                icon: Icons.account_balance_wallet,
                color: Colors.white,
                onTap: () => _handleRealPay('Google Pay'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.black),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  /// 正式支付（目前僅提示，後續可串接）
  void _handleRealPay(String method) {
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在呼叫 $method 介面...（功能開發中）')));
  }
}
