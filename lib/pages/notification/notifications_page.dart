import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/course_api_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 確保組件渲染完成後再抓取資料
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNotifications();
    });
  }

  // 從 API 抓取通知資料
  Future<void> _fetchNotifications() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser == null) {
      setState(() {
        _isLoading = false;
        _error = null;
        _notifications = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 呼叫 CourseApiService 取得資料
      final res = await CourseApiService.getMessages(userProvider.currentUser!.memberId);
      
      if (mounted) {
        final List<dynamic> messages = (res['messages'] is List)
            ? (res['messages'] as List)
            : const <dynamic>[];
        setState(() {
          _notifications = messages;
          _isLoading = false;
        });
        userProvider.updateUnreadCountFromMessages(messages);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _openNotification(Map item) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final messageId = (item['messageId'] ?? item['id'] ?? '').toString();
    final title = (item['title'] ?? '系統通知').toString();
    final content = (item['content'] ?? '').toString();
    final createdAt = _formatDate(item['created_at']?.toString());

    if (messageId.isNotEmpty) {
      await userProvider.markMessageRead(messageId);
      if (mounted) {
        userProvider.updateUnreadCountFromMessages(_notifications);
        setState(() {});
      }
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (createdAt.isNotEmpty)
                Text(createdAt, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              if (createdAt.isNotEmpty) const SizedBox(height: 8),
              Text(content, style: const TextStyle(color: Colors.white70, height: 1.4)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('通知'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(
              child: Text('請先登入查看通知', style: TextStyle(color: Colors.white38)),
            )
          : _isLoading
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
                            const Text('通知載入失敗', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                              onPressed: _fetchNotifications,
                              child: const Text('重試', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _notifications.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _fetchNotifications,
                          child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: _notifications.length,
                            separatorBuilder: (context, index) =>
                                const Divider(color: Colors.white10, indent: 70),
                            itemBuilder: (context, index) {
                              final itemRaw = _notifications[index];
                              final item = itemRaw is Map ? itemRaw : const {};
                              final messageId = (item['messageId'] ?? item['id'] ?? '').toString();
                              final isRead = userProvider.isMessageRead(messageId);
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.purple.withOpacity(0.2),
                                  child: Icon(
                                    isRead ? Icons.notifications_none : Icons.notifications,
                                    color: Colors.purpleAccent,
                                  ),
                                ),
                                title: Text(
                                  (item['title'] ?? '系統通知').toString(),
                                  style: TextStyle(
                                    color: isRead ? Colors.white60 : Colors.white.withOpacity(0.95),
                                    fontSize: 14,
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  (item['content'] ?? '').toString(),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  _formatDate(item['created_at']?.toString()),
                                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                                ),
                                onTap: () => _openNotification(item),
                              );
                            },
                          ),
                        ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.length < 10) return "";
    try {
      // 假設資料庫回傳 2024-05-20 10:30:00，截取為 05-20 10:30
      return dateStr.substring(5, 16); 
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, color: Colors.white10, size: 60),
          SizedBox(height: 16),
          Text('目前沒有任何通知', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}
