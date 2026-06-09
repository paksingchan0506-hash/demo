import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../services/course_api_service.dart';
import '../../services/user_api_service.dart';
import '../course/course_page.dart';
import '../course/mentor_detail_page.dart';
import '../auth/login_page.dart';

class BookmarkPage extends StatefulWidget {
  const BookmarkPage({super.key});

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final ScrollController _courseController = ScrollController();
  final List<Map<String, dynamic>> _courseItems = [];
  bool _courseLoading = false;
  bool _courseHasMore = true;
  int _coursePage = 1;

  final ScrollController _tutorController = ScrollController();
  final List<Map<String, dynamic>> _tutorItems = [];
  bool _tutorLoading = false;
  bool _tutorHasMore = true;
  int _tutorPage = 1;

  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _courseController.addListener(_onCourseScroll);
    _tutorController.addListener(_onTutorScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCourseMore();
      _loadTutorMore();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _courseController.dispose();
    _tutorController.dispose();
    super.dispose();
  }

  void _onCourseScroll() {
    if (!_courseHasMore || _courseLoading) return;
    final pos = _courseController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadCourseMore();
    }
  }

  void _onTutorScroll() {
    if (!_tutorHasMore || _tutorLoading) return;
    final pos = _tutorController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadTutorMore();
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

  Future<void> _loadCourseMore({bool reset = false}) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final mId = userProvider.currentUser?.memberId ?? '';
    if (mId.isEmpty) return;

    if (_courseLoading) return;
    setState(() => _courseLoading = true);
    try {
      if (reset) {
        _courseItems.clear();
        _coursePage = 1;
        _courseHasMore = true;
      }

      final res = await CourseApiService.listCourseBookmarks(
        mId: mId,
        page: _coursePage,
        pageSize: _pageSize,
      );
      final List list = res['items'] is List ? res['items'] as List : [];
      final total = (res['total'] as num?)?.toInt();

      setState(() {
        for (final it in list) {
          if (it is Map) _courseItems.add(it.cast<String, dynamic>());
        }
        _coursePage += 1;
        if (total != null) {
          _courseHasMore = _courseItems.length < total;
        } else {
          _courseHasMore = list.length == _pageSize;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入收藏失敗: $e')));
        setState(() => _courseHasMore = false);
      }
    } finally {
      if (mounted) setState(() => _courseLoading = false);
    }
  }

  Future<void> _loadTutorMore({bool reset = false}) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final mId = userProvider.currentUser?.memberId ?? '';
    if (mId.isEmpty) return;

    if (_tutorLoading) return;
    setState(() => _tutorLoading = true);
    try {
      if (reset) {
        _tutorItems.clear();
        _tutorPage = 1;
        _tutorHasMore = true;
      }

      final res = await CourseApiService.listTutorBookmarks(
        mId: mId,
        page: _tutorPage,
        pageSize: _pageSize,
      );
      final List list = res['items'] is List ? res['items'] as List : [];
      final total = (res['total'] as num?)?.toInt();

      setState(() {
        for (final it in list) {
          if (it is Map) _tutorItems.add(it.cast<String, dynamic>());
        }
        _tutorPage += 1;
        if (total != null) {
          _tutorHasMore = _tutorItems.length < total;
        } else {
          _tutorHasMore = list.length == _pageSize;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入收藏失敗: $e')));
        setState(() => _tutorHasMore = false);
      }
    } finally {
      if (mounted) setState(() => _tutorLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isGuest =
        userProvider.currentUser == null ||
        userProvider.currentUser?.userType == 'guest';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('我的收藏'),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        bottom: isGuest
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.purpleAccent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(text: '課程'),
                  Tab(text: '導師'),
                ],
              ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: isGuest
                ? null
                : () async {
                    if (_tabController.index == 0) {
                      await _loadCourseMore(reset: true);
                    } else {
                      await _loadTutorMore(reset: true);
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isGuest
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 64,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '收藏功能僅限會員使用',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      ),
                      child: const Text(
                        '立即登入',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () => _loadCourseMore(reset: true),
                  child: _courseItems.isEmpty && !_courseLoading
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.bookmark_border,
                                    size: 64,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '尚未收藏任何課程',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _courseController,
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              _courseItems.length + (_courseHasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _courseItems.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Center(
                                  child: _courseLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.purpleAccent,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              );
                            }

                            final it = _courseItems[index];
                            final cId = (it['cId'] ?? '').toString();
                            final title = (it['title'] ?? '').toString();
                            final mentorName = (it['mentorName'] ?? '未知導師')
                                .toString();
                            final introImg = (it['introImg'] ?? '').toString();
                            final date = _formatDate(
                              (it['bookmarkDate'] ?? '').toString(),
                            );

                            return Card(
                              color: Colors.grey[900],
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: Image.network(
                                      CourseApiService.getFullImageUrl(
                                        introImg,
                                      ),
                                      fit: BoxFit.cover,
                                      cacheWidth: 240,
                                      cacheHeight: 240,
                                      semanticLabel: '$title 封面',
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: Colors.black,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '老師：$mentorName',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (date.isNotEmpty)
                                        Text(
                                          '收藏日期：$date',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white30,
                                ),
                                onTap: cId.isEmpty
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CoursePage(
                                            courseId: cId,
                                            courseTitle: title,
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
                RefreshIndicator(
                  onRefresh: () => _loadTutorMore(reset: true),
                  child: _tutorItems.isEmpty && !_tutorLoading
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.bookmark_border,
                                    size: 64,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '尚未收藏任何導師',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _tutorController,
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              _tutorItems.length + (_tutorHasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _tutorItems.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Center(
                                  child: _tutorLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.purpleAccent,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              );
                            }

                            final it = _tutorItems[index];
                            final tutorId = (it['tutorId'] ?? '').toString();
                            final tutorName = (it['tutorName'] ?? '')
                                .toString();
                            final tutorAvatar = (it['tutorAvatar'] ?? '')
                                .toString();
                            final level = (it['teacherLevel'] ?? 1).toString();
                            final avgRating = (it['avgRating'] ?? 0).toString();
                            final date = _formatDate(
                              (it['bookmarkDate'] ?? '').toString(),
                            );

                            return Card(
                              color: Colors.grey[900],
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                leading: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.purpleAccent
                                      .withOpacity(0.15),
                                  child: ClipOval(
                                    child: Image.network(
                                      UserApiService.getFullImageUrl(
                                        tutorAvatar,
                                      ),
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      cacheWidth: 120,
                                      cacheHeight: 120,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.person,
                                                color: Colors.white24,
                                              ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  tutorName.isEmpty ? '未知導師' : tutorName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Level $level · $avgRating ⭐',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (date.isNotEmpty)
                                        Text(
                                          '收藏日期：$date',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white30,
                                ),
                                onTap: tutorId.isEmpty
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              MentorDetailPage(mId: tutorId),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
