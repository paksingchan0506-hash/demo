import 'package:flutter/material.dart';

class PasswordStrength extends StatelessWidget {
  final String password;
  final bool hasMinLength;
  final bool hasUpperCase;
  final bool hasLowerCase;
  final bool hasDigit;
  final bool hasSpecialChar;

  const PasswordStrength({
    super.key,
    required this.password,
    required this.hasMinLength,
    required this.hasUpperCase,
    required this.hasLowerCase,
    required this.hasDigit,
    required this.hasSpecialChar,
  });

  double get strength {
    int strength = 0;
    if (hasMinLength) strength++;
    if (hasUpperCase) strength++;
    if (hasLowerCase) strength++;
    if (hasDigit) strength++;
    if (hasSpecialChar) strength++;
    return strength / 5;
  }

  Color get strengthColor {
    final strengthValue = strength;
    if (strengthValue <= 0.2) return Colors.red;
    if (strengthValue <= 0.4) return Colors.orange;
    if (strengthValue <= 0.6) return Colors.yellow;
    if (strengthValue <= 0.8) return Colors.lightGreen;
    return Colors.green;
  }

  String get strengthText {
    final strengthValue = strength;
    if (strengthValue <= 0.2) return '非常弱';
    if (strengthValue <= 0.4) return '弱';
    if (strengthValue <= 0.6) return '中等';
    if (strengthValue <= 0.8) return '強';
    return '非常強';
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '密碼強度:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                strengthText,
                style: TextStyle(
                  color: strengthColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: strength,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
          ),
          const SizedBox(height: 8),
          _buildRequirementRow('至少8個字符', hasMinLength),
          _buildRequirementRow('包含大寫字母', hasUpperCase),
          _buildRequirementRow('包含小寫字母', hasLowerCase),
          _buildRequirementRow('包含數字', hasDigit),
          _buildRequirementRow('包含特殊字符', hasSpecialChar, optional: true),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : (optional ? Colors.grey : Colors.red),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text + (optional ? ' (可選)' : ' (必需)'),
              style: TextStyle(
                color: isMet ? Colors.green : Colors.white70,    
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}