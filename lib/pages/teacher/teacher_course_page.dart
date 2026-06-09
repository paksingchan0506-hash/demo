import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../models/course.dart';
import '../course/add_course_page.dart';
import 'course_management_page.dart';
import 'analytics_dashboard.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/channel_service.dart';

class TeacherCoursePage extends StatefulWidget {
  const TeacherCoursePage({super.key});

  @override
  State<TeacherCoursePage> createState() => _TeacherCoursePageState();
}

class _TeacherCoursePageState extends State<TeacherCoursePage> {
  List<Course> _myCourses = [];
  bool _isLoading = true;
  String? _errorMessage;

  static const _mediaPipeBaseUrl =
      'https://d2kry3pmi7k9be.cloudfront.net/MediaPipe.html';

  @override
  void initState() {
    super.initState();
    _loadTeacherCourses();
  }

  Future<void> _loadTeacherCourses() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      if (currentUser != null && currentUser.mType == 'T') {
        final response = await ApiService.getTeacherCourses(currentUser.id);
        if (response is List) {
          _myCourses = response.map((item) => Course.fromJson(item)).toList();
        } else if (response is Map && response.containsKey('courses')) {
          _myCourses = (response['courses'] as List)
              .map((item) => Course.fromJson(item))
              .toList();
        } else {
          _myCourses = [];
        }
        _myCourses = _myCourses.where((c) => !c.isDeleted).toList();
      }
    } catch (e) {
      _errorMessage = '加載課程失敗，請稍後再試';
      _myCourses = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ★ 直播按鈕邏輯
  Future<void> _handleLive() async {
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    final mId = user?.memberId ?? '';
    final name = user?.name ?? 'Teacher';

    if (mId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法取得導師 ID'), backgroundColor: Colors.red),
      );
      return;
    }

    // 顯示 loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      ),
    );

    try {
      // 取得或建立頻道
      final ch = await ChannelService.getOrCreateChannel(mId, name);

      if (!mounted) return;
      Navigator.pop(context); // 關 loading

      if (ch == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('頻道建立失敗，請稍後再試'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // 彈出直播設置對話框
      final result = await _showLiveDialog(name);
      if (result == null) return;

      // 更新直播資訊
      await ChannelService.updateBroadcastInfo(
        mId: mId,
        roomTitle: result['title'] ?? '$name 的直播',
        thumbnailUrl: result['coverUrl'],
      );
      await ChannelService.updateLastLiveTime(mId);

      // 開啟 MediaPipe 直播頁面
      final uri = Uri.parse(_mediaPipeBaseUrl).replace(queryParameters: {
        'channelId':    mId,
        'ingestServer': ch.ingestServer,
        'streamKey':    ch.streamKey,
        'playbackUrl':  ch.playbackUrl,
        'teacherName':  name,
      });

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('無法開啟直播頁面'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 關 loading（如果還開著）
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('錯誤: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<Map<String, String?>?> _showLiveDialog(String teacherName) async {
    final titleCtrl = TextEditingController(text: '$teacherName 的直播');

    return showDialog<Map<String, String?>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.live_tv, color: Colors.amber),
          SizedBox(width: 10),
          Text('直播設置',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('直播標題',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: titleCtrl,
              maxLength: 30,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                counterStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'title': titleCtrl.text.trim().isEmpty
                  ? '$teacherName 的直播'
                  : titleCtrl.text.trim(),
              'coverUrl': null,
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('開始直播',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Text('我的課程'),
        backgroundColor: Colors.black,
        actions: [
          // ★ 直播按鈕
          GestureDetector(
            onTap: _handleLive,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.podcasts_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('直播',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          // 數據分析
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.purpleAccent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AnalyticsDashboard(title: '教師數據總覽')),
            ),
          ),
          // 新增課程
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddCoursePage()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTeacherCourses,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent),
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : _myCourses.isEmpty
                  ? const Center(
                      child: Text('暫無課程，點擊右上角添加',
                          style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _loadTeacherCourses,
                      color: Colors.purpleAccent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _myCourses.length,
                        itemBuilder: (context, index) {
                          return _buildCourseCard(_myCourses[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CourseManagementPage(course: course)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(course.subject,
                      style: const TextStyle(
                          color: Colors.purpleAccent, fontSize: 12)),
                  const Icon(Icons.more_vert, color: Colors.white),
                ],
              ),
              const SizedBox(height: 8),
              Text(course.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.people, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  Text('${course.purchased} 位學生',
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(width: 16),
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text('${course.rating}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}