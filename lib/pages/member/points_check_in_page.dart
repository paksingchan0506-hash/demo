import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../auth/auth_guard.dart';

class PointsCheckInPage extends StatefulWidget {
  const PointsCheckInPage({super.key});

  @override
  State<PointsCheckInPage> createState() => _PointsCheckInPageState();
}

class _PointsCheckInPageState extends State<PointsCheckInPage> {
  bool _isProcessing = false; // 確保定義了這個變數

  // 正確的異步簽到方法
void _handleCheckIn() async {
    if (!AuthGuard.check(context)) return;

    setState(() => _isProcessing = true);

    try {
      // 呼叫 UserProvider 中的簽到方法
      final result = await Provider.of<UserProvider>(context, listen: false).performCheckIn();

      if (!mounted) return;

      if (result['status'] == 'success') {
        // --- 修改點：傳入 PHP 回傳的 message (包含連續簽到獎勵訊息) ---
        _showSuccessDialog(
          result['reward'] ?? 10, 
          customMessage: result['message'] // 將 PHP 的「簽到成功 (含連續簽到獎勵 +5)」傳進去
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "簽到失敗"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("系統錯誤: $e")),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

void _showSuccessDialog(int reward, {String? customMessage}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("簽到成功！", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: Colors.orange, size: 60),
            const SizedBox(height: 16),
            Text(
              "獲得 $reward 積分",
              style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            if (customMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                customMessage, // 這裡會顯示 "簽到成功 (含連續簽到獎勵 +5)"
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("太棒了", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    // 檢查今天是否能簽到
    bool canClick = userProvider.canCheckIn();
    // 取得連續簽到天數
    int days = userProvider.continuousCheckInDays;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("每日簽到"),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 顯示連續簽到天數
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Text(
                "已連續簽到 $days 天", 
                style: const TextStyle(
                  color: Colors.orangeAccent, 
                  fontSize: 16, 
                  fontWeight: FontWeight.w600
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // 星星圖標
            Icon(
              Icons.stars, 
              size: 120, 
              color: canClick ? Colors.orange : Colors.grey // 已簽到則變灰色
            ),
            const SizedBox(height: 30),
            
            // 狀態提示文字
            Text(
              canClick ? "完成簽到可領取 10 積分" : "今日已完成簽到",
              style: TextStyle(
                color: canClick ? Colors.white : Colors.greenAccent, 
                fontSize: 20, 
                fontWeight: FontWeight.bold
              ),
            ),
            
            const SizedBox(height: 10),
            
            // 如果不能簽到，顯示提示
            if (!canClick)
              const Text(
                "請明天 00:00 後再來吧！", 
                style: TextStyle(color: Colors.grey)
              ),
              
            const SizedBox(height: 50),
            
            // 簽到按鈕
            SizedBox(
              width: 220,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  // 如果不能簽到，顏色變深灰色
                  backgroundColor: canClick ? Colors.orange : Colors.grey[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: canClick ? 5 : 0,
                ),
                // 如果不能簽到或正在處理中，按鈕禁用
                onPressed: (canClick && !_isProcessing) ? _handleCheckIn : null,
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        canClick ? "立即簽到" : "明日再戰", 
                        style: const TextStyle(
                          fontSize: 18, 
                          color: Colors.white,
                          fontWeight: FontWeight.bold
                        )
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}