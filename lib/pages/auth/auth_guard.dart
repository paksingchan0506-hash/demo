import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../auth/register_page.dart';

class AuthGuard {
  static bool check(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // 檢查是否為訪客身份
    if (userProvider.currentUser != null && userProvider.currentUser!.userType == 'guest') {
      _showRegisterDialog(context);
      return false;
    }
    return true;
  }

  static void _showRegisterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('需要註冊', style: TextStyle(color: Colors.white)),
        content: const Text('此功能僅限正式用戶使用。現在註冊即可解鎖完整體驗！', 
          style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍後再說', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage()));
            },
            child: const Text('立即註冊'),
          ),
        ],
      ),
    );
  }
}