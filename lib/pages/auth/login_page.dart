import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ★ 新增 import
import '../../providers/user_provider.dart';
import '../../models/user.dart';
import 'register_page.dart';
import '../../services/api_service.dart';
import '../../main.dart';
import 'dart:convert'; // 必須要有這一行
import '../onboarding/onboarding_video_page.dart'; // ★ 新增 import

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 控制器定義（無更改）
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phonePasswordController = TextEditingController();

  String? _errorMessage;
  bool _isLoading = false;
  bool _isPhoneLogin = false;

  void _login({bool isGuest = false}) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (isGuest) {
        // --- 訪客登入：直接進 HomeScreen，不播影片 ---
        final guestUser = User(
          id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
          email: 'guest@edu.com',
          name: '訪客用戶',
          userType: 'guest',
          mType: 'S',
          hasRelation: false,
          memberId: 'GUEST',
        );
        await userProvider.setUser(guestUser);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // --- 正式登入邏輯 ---
        Map<String, dynamic>? res;

        if (_isPhoneLogin) {
          res = await ApiService.loginWithPhone(
            _phoneController.text.trim(),
            _phonePasswordController.text.trim(),
          );
        } else {
          res = await ApiService.loginUser(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
        }

        if (res != null) {
          res['userType'] = 'student';
          res['mType'] = res['mType'] ?? 'S';

          final user = User.fromMap(res);
          await userProvider.setUser(user);

          if (!mounted) return;

          // ★ 新增：查詢該用戶是否已看過引導影片
          final prefs = await SharedPreferences.getInstance();
          final hasWatched =
              prefs.getBool('intro_watched_${user.id}') ?? false;

          if (!mounted) return;

          if (hasWatched) {
            // 已看過：正常進入 HomeScreen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          } else {
            // 未看過：前往新手引導影片頁
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OnboardingVideoPage(userId: user.id),
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = '帳號或密碼錯誤';
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      setState(() {
        String errorRaw = e.toString();
        
        if (errorRaw.contains('{') && errorRaw.contains('}')) {
          try {
            // 擷取 JSON 字串部分
            int startIndex = errorRaw.indexOf('{');
            int endIndex = errorRaw.lastIndexOf('}') + 1;
            String jsonString = errorRaw.substring(startIndex, endIndex);
            
            // 解碼並將其轉換為 Map
            final dynamic decodedData = json.decode(jsonString);
            if (decodedData is Map) {
              _errorMessage = decodedData['message']?.toString() ?? '登入失敗';
            } else {
              _errorMessage = '帳號或密碼錯誤';
            }
          } catch (parseError) {
            _errorMessage = '帳號或密碼錯誤'; 
          }
        } else {
          // 清理非 JSON 的系統錯誤訊息
          _errorMessage = errorRaw
              .replaceAll("ApiException: ", "")
              .replaceAll("Exception: ", "")
              .replaceAll("Failed to login: ", "")
              .split(':').last.trim();
        }
        
        _isLoading = false;
      });
      print("Login Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ════════════════════════════════════════════════════
    // 以下 build() 方法完全無修改，與原版一致
    // ════════════════════════════════════════════════════
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 48.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/eduicon.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.school, size: 60, color: Colors.purpleAccent);
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'EDU Online',
                  style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                if (!_isPhoneLogin) ...[
                  _buildTextField(_emailController, '電子郵件', Icons.email_outlined),
                  const SizedBox(height: 15),
                  _buildTextField(_passwordController, '密碼', Icons.lock_outline, isObscure: true),
                ] else ...[
                  _buildTextField(_phoneController, '手機號碼', Icons.phone_android),
                  const SizedBox(height: 15),
                  _buildTextField(
                    _phonePasswordController,
                    '密碼',
                    Icons.lock_outline,
                    isObscure: true,
                  ),
                ],

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _isPhoneLogin = !_isPhoneLogin),
                    child: Text(
                      _isPhoneLogin ? '切換電子郵件登入' : '切換手機密碼登入',
                      style: const TextStyle(color: Colors.purpleAccent),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _login(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('登入', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 20),

                InkWell(
                  onTap: () => _login(isGuest: true),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '稍後再說，以訪客身份探索',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white10)),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: TextStyle(color: Colors.white24))),
                    Expanded(child: Divider(color: Colors.white10)),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialBtn(Icons.apple, Colors.white, 'Apple'),
                    const SizedBox(width: 20),
                    _buildSocialBtn(Icons.wechat, Colors.greenAccent, 'WeChat'),
                    const SizedBox(width: 20),
                    _buildSocialBtn(Icons.g_mobiledata, Colors.blueAccent, 'Google'),
                  ],
                ),

                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('沒有帳號？', style: TextStyle(color: Colors.white70)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                      child: const Text('立即註冊', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isObscure = false, Widget? suffix}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.purpleAccent, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.black,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSocialBtn(IconData icon, Color color, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: Colors.white10)),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _phonePasswordController.dispose();
    super.dispose();
  }
}