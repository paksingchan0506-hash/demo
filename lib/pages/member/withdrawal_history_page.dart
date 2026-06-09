import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/aws_service.dart';

class WithdrawalHistoryPage extends StatefulWidget {
  final String teacherId;

  const WithdrawalHistoryPage({super.key, required this.teacherId});

  @override
  State<WithdrawalHistoryPage> createState() => _WithdrawalHistoryPageState();
}

class _WithdrawalHistoryPageState extends State<WithdrawalHistoryPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await ApiService.getWithdrawalRequests(widget.teacherId);
    if (res is! Map) {
      throw Exception('讀取失敗：回傳格式不正確');
    }
    if (res['status'] != 'success') {
      throw Exception((res['message'] ?? '讀取提款記錄失敗').toString());
    }
    final data = (res['data'] as List?) ?? const [];
    return data
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return '成功';
      case 'rejected':
        return '失敗';
      case 'pending':
      default:
        return '審核中';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
      default:
        return Colors.orangeAccent;
    }
  }

  String _fmtAmount(dynamic v) {
    final n = double.tryParse(v?.toString() ?? '');
    if (n == null) return v?.toString() ?? '-';
    return n.toStringAsFixed(2);
  }

  Future<void> _openInvoice(String invoicePath) async {
    try {
      final url = AWSService.getPresignedUrl(invoicePath);
      // 因為 URL 裡面可能包含沒有被 encode 好的非法字元，使用 Uri.parse 較嚴格
      // 我們使用 Uri.tryParse 並稍微清理一下
      final cleanUrl = url.trim().replaceAll('\n', '').replaceAll('\r', '');
      final uri = Uri.tryParse(cleanUrl);
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('打開收據失敗: $e');
    }
  }

  void _showDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WithdrawalDetailPage(
          teacherId: widget.teacherId,
          requestId: (item['requestId'] ?? '').toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('提取記錄'),
        backgroundColor: Colors.grey[900],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                '讀取失敗：${snap.error}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            );
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const Center(
              child: Text('暫無提取記錄', style: TextStyle(color: Colors.white54)),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _load();
              });
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                final status = (item['status'] ?? 'pending').toString();
                final statusText = _statusLabel(status);
                final invoicePath = (item['invoicePath'] ?? '').toString();
                final subtitleBits = <String>[];
                final requestDate = (item['requestDate'] ?? '').toString();
                if (requestDate.isNotEmpty) subtitleBits.add(requestDate);
                
                // 從 API 拿到的 paymentMethod 有可能是我們剛剛組合的中文「提款方式: FPS\n帳戶資訊: 123...」
                // 這會包含換行符號和中文字，導致後面 UI 或 URI 處理時如果意外解析會出錯
                // 我們只取第一行作為簡單顯示即可
                final methodRaw = (item['paymentMethod'] ?? '').toString();
                if (methodRaw.isNotEmpty) {
                  final firstLine = methodRaw.split('\n').first;
                  subtitleBits.add(firstLine);
                }
                
                final subtitle = subtitleBits.join(' • ');

                return Card(
                  color: Colors.white.withOpacity(0.05),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () => _showDetail(item),
                    title: Text(
                      '\$ ${_fmtAmount(item['amount'])}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(color: _statusColor(status)),
                        ),
                        if (status == 'approved' && invoicePath.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: '收據',
                            icon: const Icon(
                              Icons.receipt_long,
                              color: Colors.amber,
                            ),
                            onPressed: () => _openInvoice(invoicePath),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class WithdrawalDetailPage extends StatefulWidget {
  final String teacherId;
  final String requestId;

  const WithdrawalDetailPage({
    super.key,
    required this.teacherId,
    required this.requestId,
  });

  @override
  State<WithdrawalDetailPage> createState() => _WithdrawalDetailPageState();
}

class _WithdrawalDetailPageState extends State<WithdrawalDetailPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final res = await ApiService.getWithdrawalRequestDetail(
      teacherId: widget.teacherId,
      requestId: widget.requestId,
    );
    if (res is! Map) {
      throw Exception('讀取失敗：回傳格式不正確');
    }
    if (res['status'] != 'success') {
      throw Exception((res['message'] ?? '讀取提款詳情失敗').toString());
    }
    final data = (res['data'] as Map?)?.cast<String, dynamic>() ?? {};
    return data;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return '成功';
      case 'rejected':
        return '失敗';
      case 'pending':
      default:
        return '審核中';
    }
  }

  String _fmtAmount(dynamic v) {
    final n = double.tryParse(v?.toString() ?? '');
    if (n == null) return v?.toString() ?? '-';
    return n.toStringAsFixed(2);
  }

  Future<void> _openInvoice(String invoicePath) async {
    try {
      final url = AWSService.getPresignedUrl(invoicePath);
      final cleanUrl = url.trim().replaceAll('\n', '').replaceAll('\r', '');
      // 有些包含中文或特殊符號的路徑可能需要 encode
      final uri = Uri.tryParse(cleanUrl) ?? Uri.parse(Uri.encodeFull(cleanUrl));
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('打開收據失敗: $e');
    }
  }

  bool _isImagePath(String invoicePath) {
    final p = invoicePath.toLowerCase().split('?').first;
    return p.endsWith('.png') ||
        p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.gif') ||
        p.endsWith('.webp');
  }

  bool _isPdfPath(String invoicePath) {
    final p = invoicePath.toLowerCase().split('?').first;
    return p.endsWith('.pdf');
  }

  Widget _receiptBlock(String invoicePath) {
    try {
      final url = AWSService.getPresignedUrl(invoicePath);
      final cleanUrl = url.trim().replaceAll('\n', '').replaceAll('\r', '');
      final uri = Uri.tryParse(cleanUrl) ?? Uri.parse(Uri.encodeFull(cleanUrl));
      
      if (_isImagePath(invoicePath)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            const Text(
              '收據預覽',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  final expected = progress.expectedTotalBytes;
                  final loaded = progress.cumulativeBytesLoaded;
                  final v = expected == null ? null : loaded / expected;
                  return Container(
                    height: 180,
                    color: Colors.white.withOpacity(0.06),
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      value: v,
                      color: Colors.amber,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  return Container(
                    height: 180,
                    color: Colors.white.withOpacity(0.06),
                    alignment: Alignment.center,
                    child: const Text(
                      '收據載入失敗',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }

      final label = _isPdfPath(invoicePath) ? 'PDF 收據' : '收據檔案';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(invoicePath, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => _openInvoice(invoicePath),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('開啟收據文件'),
          ),
        ],
      );
    } catch (e) {
      debugPrint('收據預覽生成失敗: $e');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          const Text(
            '收據檔案',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('無法解析收據連結，格式錯誤', style: TextStyle(color: Colors.redAccent)),
        ],
      );
    }
  }

  Widget _row(String l, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('提取詳情'),
        backgroundColor: Colors.grey[900],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                '讀取失敗：${snap.error}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            );
          }
          final d = snap.data ?? {};
          final status = (d['status'] ?? 'pending').toString();
          final statusText = _statusLabel(status);
          final invoicePath = (d['invoicePath'] ?? '').toString();
          final rejectionReason = (d['rejectionReason'] ?? '').toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row('申請編號', (d['requestId'] ?? '').toString()),
                  _row('申請日期', (d['requestDate'] ?? '').toString()),
                  _row('申請金額', '\$ ${_fmtAmount(d['amount'])}'),
                  _row('狀態', statusText),
                  const SizedBox(height: 10),
                  if (status == 'approved') ...[
                    if ((d['processedDate'] ?? '').toString().isNotEmpty)
                      _row('處理時間', (d['processedDate'] ?? '').toString()),
                    if (d['approvedAmount'] != null)
                      _row('批准金額', '\$ ${_fmtAmount(d['approvedAmount'])}'),
                    if (d['fee'] != null)
                      _row('手續費', '\$ ${_fmtAmount(d['fee'])}'),
                    if (d['netAmount'] != null)
                      _row('實付金額', '\$ ${_fmtAmount(d['netAmount'])}'),
                    if (invoicePath.isNotEmpty) _receiptBlock(invoicePath),
                  ] else if (status == 'rejected') ...[
                    Text(
                      '失敗原因',
                      style: TextStyle(
                        color: Colors.redAccent[100],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rejectionReason.isNotEmpty ? rejectionReason : '未提供',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ] else ...[
                    Text(
                      '審核中',
                      style: TextStyle(
                        color: Colors.orangeAccent[100],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '系統已收到申請，請稍後於提取記錄查看結果。',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
