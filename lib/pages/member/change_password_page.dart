import 'package:flutter/material.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../services/user_api_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // --- 新增：密碼強度狀態變數 ---
  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    // 監聽新密碼輸入，即時更新強度顯示
    _newPasswordController.addListener(_checkPasswordStrength);
  }

  // --- 新增：強度檢查邏輯 (與 Register 相同) ---
  void _checkPasswordStrength() {
    final password = _newPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
      _hasLowerCase = password.contains(RegExp(r'[a-z]'));
      _hasDigit = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  double _getPasswordStrength() {
    int strength = 0;
    if (_hasMinLength) strength++;
    if (_hasUpperCase) strength++;
    if (_hasLowerCase) strength++;
    if (_hasDigit) strength++;
    if (_hasSpecialChar) strength++;
    return strength / 5;
  }

  Color _getPasswordStrengthColor() {
    final strength = _getPasswordStrength();
    if (strength <= 0.2) return Colors.red;
    if (strength <= 0.4) return Colors.orange;
    if (strength <= 0.6) return Colors.yellow;
    if (strength <= 0.8) return Colors.lightGreen;
    return Colors.green;
  }

  String _getPasswordStrengthText() {
    final strength = _getPasswordStrength();
    if (strength <= 0.2) return 'Very Weak';
    if (strength <= 0.4) return 'Weak';
    if (strength <= 0.6) return 'Fair';
    if (strength <= 0.8) return 'Good';
    return 'Strong';
  }

  // --- 新增：驗證器 (與 Register 相同) ---
  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '請輸入新密碼';
    }
    if (value.length < 8) {
      return '密碼必須至少8個字符';
    }
    if (!_hasUpperCase || !_hasLowerCase || !_hasDigit) {
      return '必須包含大、小寫字母及數字';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final mId = userProvider.currentUser?.memberId;

      if (mId == null) throw '無法獲取會員編號';

      final result = await UserApiService.changePassword(
        mId,
        _oldPasswordController.text,
        _newPasswordController.text,
      );

      final success = result['success'] == true || result['status'] == 'success';
      if (!success) {
        throw result['message'] ?? '修改失敗';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密碼修改成功'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修改失敗: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 新增：強度 UI 組件 (與 Register 相同) ---
  Widget _buildPasswordStrengthIndicator() {
    if (_newPasswordController.text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('密碼強度:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                _getPasswordStrengthText(),
                style: TextStyle(
                  color: _getPasswordStrengthColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _getPasswordStrength(),
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(_getPasswordStrengthColor()),
          ),
          const SizedBox(height: 8),
          _buildRequirementRow('至少 8 個字符', _hasMinLength),
          _buildRequirementRow('包含大寫字母', _hasUpperCase),
          _buildRequirementRow('包含小寫字母', _hasLowerCase),
          _buildRequirementRow('包含數字', _hasDigit),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: Colors.grey[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 舊密碼
              AppTextField(
                controller: _oldPasswordController,
                labelText: '舊密碼',
                obscureText: !_showOldPassword,
                suffixIcon: IconButton(
                  icon: Icon(_showOldPassword ? Icons.visibility : Icons.visibility_off, color: Colors.white70),
                  onPressed: () => setState(() => _showOldPassword = !_showOldPassword),
                ),
                validator: (value) => (value == null || value.isEmpty) ? '請輸入舊密碼' : null,
              ),
              const SizedBox(height: 16),

              // 新密碼
              AppTextField(
                controller: _newPasswordController,
                labelText: '新密碼',
                obscureText: !_showNewPassword,
                suffixIcon: IconButton(
                  icon: Icon(_showNewPassword ? Icons.visibility : Icons.visibility_off, color: Colors.white70),
                  onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                ),
                validator: _validateNewPassword, // 使用新驗證邏輯
              ),
              
              // 顯示強度指示器
              _buildPasswordStrengthIndicator(),

              // 確認新密碼
              AppTextField(
                controller: _confirmPasswordController,
                labelText: '確認新密碼',
                obscureText: !_showConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(_showConfirmPassword ? Icons.visibility : Icons.visibility_off, color: Colors.white70),
                  onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '請確認新密碼';
                  if (value != _newPasswordController.text) return '密碼不匹配';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              AppButton(
                text: '更改密碼',
                onPressed: _changePassword,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_checkPasswordStrength);
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}