import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../services/course_api_service.dart';
import '../course/course_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final mId = userProvider.currentUser?.memberId ?? '';
    if (mId.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
        _items = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await CourseApiService.getMyCourses(mId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr.replaceFirst(' ', 'T')).toLocal();
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final mId = userProvider.currentUser?.memberId ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('購買紀錄'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _fetch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: mId.isEmpty
          ? const Center(
              child: Text('請先登入查看購買紀錄', style: TextStyle(color: Colors.white38)),
            )
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.purpleAccent),
                )
              : (_error != null)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off, color: Colors.white24, size: 48),
                            const SizedBox(height: 12),
                            const Text('載入失敗', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                              onPressed: _fetch,
                              child: const Text('重試', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _items.isEmpty
                      ? const Center(
                          child: Text('暫無購買紀錄', style: TextStyle(color: Colors.white24)),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final raw = _items[index];
                              final item = raw is Map ? raw : const {};
                              final cId = (item['cId'] ?? '').toString();
                              final title = (item['title'] ?? '未知課程').toString();
                              final mentorName = (item['mentorName'] ?? '未知導師').toString();
                              final introImg = (item['introImg'] ?? '').toString();
                              final purchaseType = (item['purchaseType'] ?? '').toString();
                              final purchaseDate = _formatDate(item['purchaseDate']?.toString());

                              return Card(
                                color: Colors.grey[900],
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Image.network(
                                        CourseApiService.getFullImageUrl(introImg),
                                        fit: BoxFit.cover,
                                        cacheWidth: 240,
                                        cacheHeight: 240,
                                        semanticLabel: '$title 封面',
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.black,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.image_not_supported, color: Colors.white24),
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (purchaseType.isNotEmpty)
                                        _badge(purchaseType == 'course' ? '整課' : '單課時'),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '老師：$mentorName',
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                        if (purchaseDate.isNotEmpty)
                                          Text(
                                            '購買日期：$purchaseDate',
                                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                                  onTap: cId.isEmpty
                                      ? null
                                      : () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CoursePage(courseId: cId, courseTitle: title),
                                            ),
                                          );
                                          if (mounted) await _fetch();
                                        },
                                ),
                              );
                            },
                          ),
                        ),
    );
  }

  static Widget _badge(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.35)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.purpleAccent, fontSize: 11)),
    );
  }
}
