import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'course_page.dart';
import '../../services/course_api_service.dart';
import '../../services/user_api_service.dart';
import '../course/video_player_page.dart';
import '../auth/login_page.dart';
import '../../providers/user_provider.dart';

class MentorDetailPage extends StatefulWidget {
  final String mId;

  const MentorDetailPage({super.key, required this.mId});

  @override
  State<MentorDetailPage> createState() => _MentorDetailPageState();
}

class _MentorDetailPageState extends State<MentorDetailPage> {
  bool _bookmarkLoading = false;
  bool _isBookmarked = false;

  // 統一的頭像組件：處理 S3 URL 轉換，若無圖則顯示首字母
  Widget _buildAvatar({String? url, required String name, double radius = 25}) {
    final String fullUrl = (url != null && url.isNotEmpty)
        ? UserApiService.getFullImageUrl(url)
        : UserApiService.getFullImageUrl(null);

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.purple[800],
      child: ClipOval(
        child: Image.network(
          fullUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          cacheWidth: 120,
          cacheHeight: 120,
          semanticLabel: '$name 的頭像',
          errorBuilder: (context, error, stackTrace) => Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : "?",
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBookmarkState());
  }

  String _cateLabel(Map item) {
    final locale = Localizations.localeOf(context).toString();
    if (locale.startsWith('zh_CN')) return (item['nameSC'] ?? '').toString();
    if (locale.startsWith('zh_HK') || locale.startsWith('zh_TW')) {
      return (item['nameTC'] ?? '').toString();
    }
    if (locale.startsWith('zh')) return (item['nameTC'] ?? '').toString();
    return (item['nameE'] ?? '').toString();
  }

  Future<void> _loadBookmarkState() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final mId = userProvider.currentUser?.memberId ?? '';
    if (mId.isEmpty) return;
    try {
      final res = await CourseApiService.isTutorBookmarked(
        mId: mId,
        tutorId: widget.mId,
      );
      final bookmarked = res['bookmarked'] == true;
      if (mounted) setState(() => _isBookmarked = bookmarked);
    } catch (_) {}
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          '需要登入',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '收藏導師功能僅限會員使用，請先登入。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text('登入', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    if (_bookmarkLoading) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isGuest =
        userProvider.currentUser == null ||
        userProvider.currentUser?.userType == 'guest';
    if (isGuest) {
      _showLoginRequiredDialog();
      return;
    }
    setState(() => _bookmarkLoading = true);
    try {
      final res = await CourseApiService.toggleTutorBookmark(
        mId: userProvider.currentUser!.memberId,
        tutorId: widget.mId,
      );
      if (mounted) {
        setState(() => _isBookmarked = res['bookmarked'] == true);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _bookmarkLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: const Text("導師個人檔案"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '收藏導師',
            onPressed: _bookmarkLoading ? null : _toggleBookmark,
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? Colors.amber : Colors.white70,
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: CourseApiService.getMentorDetail(widget.mId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: SelectableText(
                "報錯內容：${snapshot.error.toString()}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(
              child: Text("找不到導師資料", style: TextStyle(color: Colors.white)),
            );
          }

          // 解析數據
          final mentor = snapshot.data!;
          final List<dynamic> courses = mentor['courses'] ?? [];
          final String selfIntro = (mentor['selfIntro'] ?? '').toString();
          final String selfIntroVideo = (mentor['selfIntroVideo'] ?? '')
              .toString();
          final List<dynamic> categories = (mentor['categories'] is List)
              ? (mentor['categories'] as List)
              : const [];
          final List<dynamic> cateIds = (mentor['cateIds'] is List)
              ? (mentor['cateIds'] as List)
              : const [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 1. 頭像部分
                _buildAvatar(
                  url: mentor['mentorAvatar'],
                  name: mentor['mentorName'] ?? "T",
                  radius: 50,
                ),
                const SizedBox(height: 16),

                // 2. 姓名
                Text(
                  mentor['mentorName'] ?? "未知導師",
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // 3. 導師等級標籤
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Level ${mentor['teacherLevel'] ?? 1} 認證導師",
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4. 數據統計
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem("課程數量", "${mentor['courseCount'] ?? 0}"),
                    _buildStatItem(
                      "平均評分",
                      "${mentor['averageRating'] ?? 0.0} ⭐",
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                if (categories.isNotEmpty || cateIds.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "擅長科目",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.isNotEmpty
                          ? categories.whereType<Map>().map((c) {
                              final label = _cateLabel(c).trim();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  label.isEmpty
                                      ? (c['cateId'] ?? '').toString()
                                      : label,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList()
                          : cateIds.map((id) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  id.toString(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (selfIntro.trim().isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "自我介紹",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      selfIntro,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (selfIntroVideo.trim().isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "自我介紹影片",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.purpleAccent,
                      ),
                      title: const Text(
                        "觀看導師介紹影片",
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white24,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerPage(
                              videoUrl: selfIntroVideo,
                              lessonTitle: '導師自我介紹',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // 5. 課程列表標題
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "所屬課程",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 6. 課程列表
                courses.isEmpty
                    ? const Text("暫無課程", style: TextStyle(color: Colors.grey))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: courses.length,
                        itemBuilder: (context, index) {
                          final course = courses[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CoursePage(
                                    courseId: course['cId'].toString(),
                                    courseTitle: course['cName'],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.book,
                                  color: Colors.blue,
                                ),
                                title: Text(
                                  course['cName'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  "價格: 積分 ${course['unitPrice']}",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white24,
                                  size: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}
