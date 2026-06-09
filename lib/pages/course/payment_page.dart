import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/user_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentPage extends StatefulWidget {
  final String courseTitle;
  final double price;
  final String courseId;
  final String? lId;

  const PaymentPage({
    super.key,
    required this.courseTitle,
    required this.price,
    required this.courseId,
    this.lId,
  });

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  // 狀態管理變數，預設改為 'points'
  String _selectedMethod = 'points';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    double finalAmount = widget.price;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('確認付款'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('訂單摘要'),
                _buildPaymentCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      widget.courseTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Text(
                      '${widget.price.toInt()} 積分',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('支付方式'),
                // 已刪除其他支付方式，僅保留積分支付
                _buildPointsOption(context),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '總計金額',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      '${finalAmount.toInt()} 積分',
                      style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => _handlePayment(finalAmount),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            '確認並支付',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePayment(double amount) async {
    final userProvider = context.read<UserProvider>();
    final courseProvider = context.read<CourseProvider>();
    final String? mId = userProvider.currentUser?.memberId;

    if (mId == null || mId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請先登入再進行購買")));
      return;
    }

    try {
      final checkResponse = await http.post(
        Uri.parse("http://3.25.85.107/mysqlconnect/purchase.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "check",
          "mId": mId,
          "cId": widget.courseId,
          "lId": widget.lId,
        }),
      );
      final checkResult = json.decode(checkResponse.body);
      if (checkResult is Map && checkResult['status'] != 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(checkResult['message']?.toString() ?? '已購買')),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("檢查購買狀態失敗: $e")));
      return;
    }

    // 積分支付邏輯
    int requiredPoints = amount.toInt();
    if ((userProvider.currentUser?.points ?? 0) < requiredPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "A幣不足！需要 $requiredPoints，當前僅有 ${userProvider.currentUser?.points}",
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success = await userProvider.purchaseWithCoins(
      requiredPoints,
      "購買課程：${widget.courseTitle}",
    );

    if (!success) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("http://3.25.85.107/mysqlconnect/purchase.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "mId": mId,
          "cId": widget.courseId,
          "lId": widget.lId,
          "payMethod": _selectedMethod,
        }),
      );

      final result = json.decode(response.body);

      if (result['status'] == 'success') {
        courseProvider.addOrder(
          title: widget.courseTitle,
          price: '${amount.toInt()} A幣',
        );

        if (!mounted) return;
        _showSuccessDialog(userProvider.currentUser?.email ?? '', amount);
      } else {
        await userProvider.refundCoins(
          requiredPoints,
          "退款：${widget.courseTitle}",
        );
        throw Exception(result['message'] ?? "購買失敗");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("支付失敗: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String email, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              "支付成功",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                const Text(
                  "項目內容：",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                Text(
                  widget.courseTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "消耗 A幣",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    Text(
                      "${amount.toInt()} A幣",
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "支付方式",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const Text("A幣支付", style: TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "您現在可以開始觀看課程了。",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                child: const Text(
                  "開始學習",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsOption(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    int currentPoints = userProvider.currentUser?.points ?? 0;
    // 既然只剩一個選項，這裡預設就是選中狀態
    bool isSelected = _selectedMethod == 'points';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2), // 既然是唯一選項，直接亮起
      ),
      child: RadioListTile<String>(
        value: 'points',
        groupValue: _selectedMethod,
        activeColor: Colors.orange,
        title: Row(
          children: [
            const Icon(Icons.stars, color: Colors.orange, size: 20),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A幣支付',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  Text(
                    '可用 A幣: $currentPoints',
                    style: TextStyle(color: Colors.orange[300], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        onChanged: (val) => setState(() => _selectedMethod = val!),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4, top: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaymentCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
