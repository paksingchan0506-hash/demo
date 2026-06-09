import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'withdrawal_history_page.dart';

class WithdrawalPage extends StatefulWidget {
  const WithdrawalPage({super.key});

  @override
  State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  String _paymentMethod = 'FPS'; // 預設提款方式
  final _formKey = GlobalKey<FormState>();
  String? _teacherId;
  Future<Map<String, dynamic>>? _summaryFuture;
  Map<String, dynamic>? _summary;
  bool _isSubmitting = false;

  // 控制器
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _fpsController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankAccountController = TextEditingController();
  final TextEditingController _accountHolderController =
      TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _fpsController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = context.watch<UserProvider>();
    final resolved =
        userProvider.linkedTeacherId ?? userProvider.currentUser?.memberId;
    if (resolved != null && resolved.isNotEmpty && resolved != _teacherId) {
      _teacherId = resolved;
      _summaryFuture = _loadSummary();
    }
  }

  Future<Map<String, dynamic>> _loadSummary() async {
    final teacherId = _teacherId;
    if (teacherId == null || teacherId.isEmpty) {
      throw Exception('找不到老師帳號，請先登入或切換身份');
    }
    final res = await ApiService.getWithdrawalSummary(teacherId);
    if (res is! Map) {
      throw Exception('讀取失敗：回傳格式不正確');
    }
    if (res['status'] != 'success') {
      throw Exception((res['message'] ?? '讀取提款資訊失敗').toString());
    }
    final data = (res['data'] as Map?)?.cast<String, dynamic>() ?? {};
    if (mounted) {
      setState(() {
        _summary = data;
      });
    }
    return data;
  }

  double _availableHkd() {
    final s = _summary;
    if (s == null) return 0.0;

    // 優先使用後端直接算好的 availableWithdrawableHkd
    final availableDirect = _parseDouble(s['availableWithdrawableHkd']);
    if (availableDirect != null && availableDirect >= 0) {
      return availableDirect;
    }

    final points = _parseDouble(s['pointsBalance']) ?? 0.0;
    final rate = _parseDouble(s['aCoinToHkdRate']) ?? 0.01;
    
    final v = points * rate;
    return v < 0 ? 0.0 : v;
  }

  double _minHkd() {
    final v = _summary?['minWithdrawAmountHkd'];
    return _parseDouble(v) ?? 100.0;
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _buildAccountInfo() {
    if (_paymentMethod == 'FPS') return _fpsController.text.trim();
    final bank = _bankNameController.text.trim();
    final holder = _accountHolderController.text.trim();
    final account = _bankAccountController.text.trim();
    return 'bankName=$bank;accountHolder=$holder;bankAccount=$account';
  }

  Future<void> _submitWithdrawal() async {
    if (_isSubmitting) return;
    final teacherId = _teacherId;
    if (teacherId == null || teacherId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到老師帳號，請先登入或切換身份')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) return;

    final min = _minHkd();
    if (amount < min) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最低提款金額為 HKD ${min.toStringAsFixed(0)}')),
      );
      return;
    }

    final available = _availableHkd();
    
    if (available <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前沒有可提款餘額')));
      return;
    }
    if (amount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('可提款餘額不足（可提取：HKD ${available.toStringAsFixed(2)}）'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      final res = await ApiService.createWithdrawalRequest(
        teacherId: teacherId,
        amountHkd: amount,
        paymentMethod: _paymentMethod,
        accountInfo: _buildAccountInfo(),
      );

      if (res is! Map) {
        throw Exception('申請失敗：回傳格式不正確');
      }
      if (res['status'] != 'success') {
        throw Exception((res['message'] ?? '申請失敗').toString());
      }
      final data = (res['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final requestId = (data['requestId'] ?? '').toString();
      if (requestId.isEmpty) {
        throw Exception('申請失敗：缺少申請編號');
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('提款申請已提交', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('申請編號', requestId.isNotEmpty ? requestId : '-'),
              _row('申請金額', '\$ ${amount.toStringAsFixed(2)}'),
              _row('狀態', '審核中'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉', style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      );

      _amountController.clear();
      if (_paymentMethod == 'FPS') {
        _fpsController.clear();
      } else {
        _bankNameController.clear();
        _accountHolderController.clear();
        _bankAccountController.clear();
      }

      setState(() {
        _summaryFuture = _loadSummary();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('申請失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('收益提款', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: '重新載入',
            onPressed: () {
              final teacherId = _teacherId;
              if (teacherId == null || teacherId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('找不到老師帳號，請先登入或切換身份')),
                );
                return;
              }
              setState(() {
                _summaryFuture = _loadSummary();
              });
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          // ★ 右上角：領取記錄按鈕
          TextButton.icon(
            onPressed: () {
              final teacherId = _teacherId;
              if (teacherId == null || teacherId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('找不到老師帳號，請先登入或切換身份')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WithdrawalHistoryPage(teacherId: teacherId),
                ),
              );
            },
            icon: const Icon(Icons.history, color: Colors.amber, size: 20),
            label: const Text('記錄', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 30),
              const Text(
                '提款金額',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                _amountController,
                '輸入金額',
                Icons.attach_money,
                isNumber: true,
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  if (raw.isEmpty) return '此欄位不能為空';
                  final n = double.tryParse(raw);
                  if (n == null) return '請輸入數字';
                  if (n < _minHkd()) {
                    return '最低提款金額為 HKD ${_minHkd().toStringAsFixed(0)}';
                  }
                  final available = _availableHkd();
                  if (available <= 0) return '目前沒有可提款餘額';
                  if (n > available) {
                    return '可提款餘額不足（可提取：HKD ${available.toStringAsFixed(2)}）';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              const Text(
                '選擇收款方式',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildMethodChip('FPS', Icons.bolt),
                  const SizedBox(width: 10),
                  _buildMethodChip('銀行轉帳', Icons.account_balance),
                ],
              ),
              const SizedBox(height: 20),
              if (_paymentMethod == 'FPS') ...[
                _buildTextField(
                  _fpsController,
                  '轉數快 (電話/電郵/ID)',
                  Icons.qr_code_scanner,
                ),
              ] else ...[
                _buildTextField(
                  _bankNameController,
                  '銀行名稱 (例如: HSBC)',
                  Icons.business,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _accountHolderController,
                  '持卡人姓名',
                  Icons.person,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _bankAccountController,
                  '銀行戶口號碼',
                  Icons.credit_card,
                  isNumber: true,
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitWithdrawal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      : const Text(
                          '確認申請提款',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final f = _summaryFuture;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[900]!, Colors.blue[900]!],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: f,
        builder: (context, snap) {
          if (f == null) {
            return const Text(
              '請先登入或切換至老師身份',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            );
          }
          if (snap.connectionState != ConnectionState.done) {
            return const Row(
              children: [
                CircularProgressIndicator(
                  color: Colors.white70,
                  strokeWidth: 2,
                ),
                SizedBox(width: 12),
                Text('載入中…', style: TextStyle(color: Colors.white70)),
              ],
            );
          }
          if (snap.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '可提款餘額',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '讀取失敗：${snap.error}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            );
          }
          final data = snap.data ?? const {};
          final hasAvailableKey = data.containsKey('availableWithdrawableHkd');
          final available = _parseDouble(data['availableWithdrawableHkd']);
          final gross = _parseDouble(data['grossWithdrawableHkd']);
          final committed = _parseDouble(data['committedHkd']);
          final computedAvailable = (gross != null && committed != null)
              ? (gross - committed)
              : null;
          final points = (data['pointsBalance'] ?? '').toString();
          final pointsNum = _parseDouble(data['pointsBalance']) ?? 0.0;
          final rate = _parseDouble(data['aCoinToHkdRate']);
          final fallbackRate = rate ?? 0.01; // 100 coin = 1 HKD => 0.01
          final availableDirect = _parseDouble(data['availableWithdrawableHkd']);
          
          double showAvailable = availableDirect ?? (pointsNum * fallbackRate);
          if (showAvailable < 0) showAvailable = 0.0;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '可提款餘額',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'HKD ${showAvailable.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!hasAvailableKey && computedAvailable == null) ...[
                const SizedBox(height: 6),
                const Text(
                  '後端未提供可提款餘額欄位',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
              if (pointsNum > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '可換算積分：${pointsNum.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
              if (rate != null) ...[
                const SizedBox(height: 6),
                Text(
                  '換算率：100 ACoin = HKD 1',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMethodChip(String title, IconData icon) {
    bool isSelected = _paymentMethod == title;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber[700] : Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: isSelected ? Colors.black : Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator:
          validator ??
          (value) => value == null || value.isEmpty ? '此欄位不能為空' : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.amber[700]),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(color: Colors.white60)),
        Flexible(
          child: Text(
            v,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

// ── 成功界面 ──
class WithdrawalSuccessPage extends StatelessWidget {
  const WithdrawalSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
                size: 100,
              ),
              const SizedBox(height: 24),
              const Text(
                '提款申請已提交',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 50),
              OutlinedButton.icon(
                onPressed: () => _showReceiptDialog(context),
                icon: const Icon(Icons.receipt_long, color: Colors.amber),
                label: const Text(
                  '查看電子收據',
                  style: TextStyle(color: Colors.amber),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.amber),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '返回',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('提款收據', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('交易編號', 'WD-882731'),
            _row('提款金額', '\$ 1,000.00'),
            _row('狀態', '審核中'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(color: Colors.white60)),
        Text(v, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );
}
