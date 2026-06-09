import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/course_api_service.dart';
import 'payment_page.dart';
import 'mentor_detail_page.dart';
import '../../providers/user_provider.dart';
import '../student/student_lesson_player_page.dart';
import '../auth/auth_guard.dart';
import '../auth/login_page.dart';
import '../../services/user_api_service.dart';
import 'package:intl/intl.dart';
import '../member/member_page.dart';
import 'video_player_page.dart';

class CoursePage extends StatefulWidget {
  final String courseTitle;
  final String courseId;

  const CoursePage({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  _CoursePageState createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  // --- 狀態變數 ---
  bool isLoading = true;
  bool hasError = false;
  Map<String, dynamic>? courseData;
  List<dynamic> lessons = [];
  List<dynamic> reviews = [];

  // --- 評分相關變數 (新增) ---
  int _selectedRating = 5; // 用戶在輸入框選取的星星
  int _currentUserRating = 0; // 從資料庫讀取的用戶現有評分

  bool isPurchased = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isBookmarked = false;
  bool _bookmarkLoading = false;
  DateTime? _courseReportCooldownUntil;
  final Map<String, DateTime> _commentReportCooldownUntil = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String currentMId = userProvider.currentUser?.memberId ?? "";

    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      // 並行執行多個 API 請求提高效率
      final results = await Future.wait([
        CourseApiService.getCourseDetail(widget.courseId, mId: currentMId),
        CourseApiService.getLessonsByCourseId(widget.courseId, currentMId),
        CourseApiService.getCourseReviews(widget.courseId, mId: currentMId),
        if (currentMId.isNotEmpty)
          CourseApiService.isCourseBookmarked(
            mId: currentMId,
            cId: widget.courseId,
          ).catchError((_) => false)
        else
          Future.value(false),
      ]);

      if (mounted) {
        setState(() {
          courseData = results[0] as Map<String, dynamic>;
          lessons = results[1] as List<dynamic>;

          // 處理評論數據
          final reviewData = results[2] as Map<String, dynamic>;
          reviews = reviewData['reviews'] ?? [];
          _currentUserRating = (reviewData['userRating'] as num?)?.toInt() ?? 0;
          _isBookmarked = results[3] == true;

          isPurchased = lessons.any((l) => l['isLocked'] == false);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("載入數據失敗: $e");

      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
    }
  }

  // 修改評分的 Dialog
  void _showRatingDialog() {
    int tempRating = _currentUserRating > 0 ? _currentUserRating : 5;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String currentMId = userProvider.currentUser?.memberId ?? "";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("修改您的評分", style: TextStyle(color: Colors.white)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => IconButton(
                icon: Icon(
                  index < tempRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => setDialogState(() => tempRating = index + 1),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消"),
            ),
            ElevatedButton(
              onPressed: () async {
                await CourseApiService.submitReview(
                  currentMId,
                  widget.courseId,
                  "",
                  rating: tempRating,
                  action: 'rating',
                );
                Navigator.pop(context);
                _loadAllData(); // 重新整理 UI
              },
              child: const Text("提交"),
            ),
          ],
        ),
      ),
    );
  }

  // 提交評論
  void _postReview() async {
    if (_commentController.text.isEmpty) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String currentMId = userProvider.currentUser?.memberId ?? "";

    setState(() => isLoading = true);

    try {
      final res = await CourseApiService.submitReview(
        currentMId,
        widget.courseId,
        _commentController.text,
        rating: _selectedRating,
        action: 'comment',
      );

      if (res['status'] == 'success') {
        _commentController.clear();
        await _loadAllData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("感謝評價！")));
      }
    } catch (e) {
      debugPrint("提交失敗: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _navigateToPayment(String title, double price, {String? lId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          courseTitle: title,
          courseId: widget.courseId,
          price: price,
          lId: lId, // 傳入此參數
        ),
      ),
    ).then((value) {
      if (value == true) {
        _loadAllData();
      }
    });
  }

  void _showLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("課程尚未解鎖", style: TextStyle(color: Colors.white)),
        content: const Text(
          "請先購買單獨課時或完整課程以觀看內容。",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "我知道了",
              style: TextStyle(color: Colors.purpleAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _handleBookmarkToggle(bool currentlyBookmarked) async {
    // --- 新增：身份安全性檢查 ---
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser == null ||
        userProvider.currentUser?.userType == 'guest') {
      _showLoginRequiredDialog();
      return;
    }
    if (_bookmarkLoading) return;
    setState(() => _bookmarkLoading = true);

    try {
      final res = await CourseApiService.toggleCourseBookmark(
        mId: userProvider.currentUser!.memberId,
        cId: widget.courseId,
      );
      if (mounted) {
        setState(() {
          _isBookmarked = res['bookmarked'] == true;
          if (res['bookmarkCount'] is num) {
            courseData?['bookmarkCount'] = (res['bookmarkCount'] as num)
                .toInt();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('收藏更新失敗，請稍後再試')));
      }
    } finally {
      if (mounted) setState(() => _bookmarkLoading = false);
    }
  }

  String _formatReviewTime(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    DateTime? dt;
    try {
      final normalized = dateStr.contains('T')
          ? dateStr
          : dateStr.replaceFirst(' ', 'T');
      dt = DateTime.parse(normalized).toLocal();
    } catch (_) {
      return dateStr;
    }
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inHours < 24 &&
        now.day == dt.day &&
        now.month == dt.month &&
        now.year == dt.year) {
      return '今天 ${DateFormat('HH:mm').format(dt)}';
    }
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  Future<void> _showReportSheet({
    required String reportType,
    required String title,
    required String targetKey,
    String? courseId,
    String? commentId,
  }) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser == null ||
        userProvider.currentUser?.userType == 'guest') {
      _showLoginRequiredDialog();
      return;
    }

    final now = DateTime.now();
    if (reportType == 'course' &&
        _courseReportCooldownUntil != null &&
        now.isBefore(_courseReportCooldownUntil!)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已舉報過，請於 24 小時後再試')));
      return;
    }
    if (reportType == 'comment') {
      final until = _commentReportCooldownUntil[targetKey];
      if (until != null && now.isBefore(until)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已舉報過，請於 24 小時後再試')));
        return;
      }
    }

    List reasons = [];
    try {
      final reasonsRes = await CourseApiService.getReportReasons(
        type: reportType,
      );
      reasons = reasonsRes['items'] is List ? reasonsRes['items'] as List : [];
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('無法載入舉報理由: $e')));
      return;
    }

    String? selectedReasonId;
    final descController = TextEditingController();

    final picked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (ctx, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (reasons.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '目前無可用理由',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: reasons.length,
                          itemBuilder: (ctx, i) {
                            final r = reasons[i] as Map;
                            final rid = (r['reasonId'] ?? '').toString();
                            final rt = (r['title'] ?? '').toString();
                            final rd = (r['description'] ?? '').toString();
                            final selected = selectedReasonId == rid;
                            return ListTile(
                              title: Text(
                                rt,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                rd,
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: selected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.purpleAccent,
                                    )
                                  : null,
                              onTap: () =>
                                  setSheetState(() => selectedReasonId = rid),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: TextField(
                        controller: descController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '補充描述（選填）',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text(
                                '取消',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                              ),
                              onPressed: selectedReasonId == null
                                  ? null
                                  : () => Navigator.pop(ctx, true),
                              child: const Text(
                                '送出',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (picked != true || selectedReasonId == null) return;

    final submitRes = await CourseApiService.submitReport(
      reporterId: userProvider.currentUser!.memberId,
      reportType: reportType,
      reasonId: selectedReasonId!,
      courseId: courseId,
      commentId: commentId,
      description: descController.text,
    );

    if (!mounted) return;

    if (submitRes['success'] == true) {
      DateTime? until;
      try {
        until = DateTime.parse(
          (submitRes['cooldownUntil'] ?? '').toString().replaceFirst(' ', 'T'),
        ).toLocal();
      } catch (_) {}
      setState(() {
        if (reportType == 'course') {
          _courseReportCooldownUntil =
              until ?? DateTime.now().add(const Duration(hours: 24));
        } else {
          _commentReportCooldownUntil[targetKey] =
              until ?? DateTime.now().add(const Duration(hours: 24));
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((submitRes['message'] ?? '感謝回報').toString())),
      );
    } else if (submitRes['code'] == 'DUPLICATE') {
      DateTime? until;
      try {
        until = DateTime.parse(
          (submitRes['cooldownUntil'] ?? '').toString().replaceFirst(' ', 'T'),
        ).toLocal();
      } catch (_) {}
      setState(() {
        if (reportType == 'course') {
          _courseReportCooldownUntil =
              until ?? DateTime.now().add(const Duration(hours: 24));
        } else {
          _commentReportCooldownUntil[targetKey] =
              until ?? DateTime.now().add(const Duration(hours: 24));
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('24 小時內已舉報過相同目標')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((submitRes['message'] ?? '舉報失敗').toString())),
      );
    }
  }

  void _handleReviewerAvatarTap({required String reviewerId}) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final current = userProvider.currentUser;
    if (reviewerId.isEmpty) return;
    if (current != null && current.memberId == reviewerId) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MemberPage()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PublicMemberProfilePage(memberId: reviewerId),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "需要登入",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "收藏課程功能僅限會員使用，請先登入或註冊帳號。",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("稍後再說", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              // 跳轉至登入頁
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text("立即登入", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent),
        ),
      );
    }

    if (hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const Text("無法載入課程資料", style: TextStyle(color: Colors.white)),
              TextButton(onPressed: _loadAllData, child: const Text("重試")),
            ],
          ),
        ),
      );
    }

    final String headerImageUrl = CourseApiService.getFullImageUrl(
      courseData?['introImg'],
    );
    final double coursePrice =
        (courseData?['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final String summary = courseData?['summary'] ?? "暫無課程概要。";
    final String introVideo =
        (courseData?['introVideo'] ?? courseData?['intro_video'] ?? '')
            .toString();
    final int purchased =
        (courseData?['purchasedCount'] ?? courseData?['students'] ?? 0) as int;
    final int bookmarks =
        (courseData?['bookmarkCount'] ?? courseData?['bookmarks'] ?? 0) as int;
    bool isAllUnlocked =
        lessons.isNotEmpty && lessons.every((l) => l['isLocked'] == false);
    final rawPurchased = courseData?['isPurchased'];
    final bool hasOwnedFullCourse =
        rawPurchased == true || rawPurchased == 1 || rawPurchased == '1';
    final String displayRating =
        (courseData?['rating'] ?? courseData?['calculatedRating'] ?? "0.0")
            .toString();
    final bool showPurchased =
        hasOwnedFullCourse || (lessons.isNotEmpty && isAllUnlocked);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Colors.black,
            automaticallyImplyLeading: false,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final topPadding = MediaQuery.paddingOf(context).top;
                const double blackBlockWidth = 14.0;

                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );
                final bool isGuest =
                    userProvider.currentUser == null ||
                    userProvider.currentUser?.userType == 'guest';

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        headerImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: topPadding + kToolbarHeight,
                      child: Container(color: Colors.black.withOpacity(0.55)),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      width: blackBlockWidth,
                      height: topPadding + kToolbarHeight,
                      child: Container(color: Colors.black),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: blackBlockWidth,
                      height: topPadding + kToolbarHeight,
                      child: Padding(
                        padding: EdgeInsets.only(top: topPadding),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: '退出',
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: '收藏',
                              icon: Icon(
                                _isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: _isBookmarked
                                    ? Colors.yellow
                                    : Colors.white,
                              ),
                              onPressed: isGuest
                                  ? _showLoginRequiredDialog
                                  : (_bookmarkLoading
                                        ? null
                                        : () => _handleBookmarkToggle(
                                            _isBookmarked,
                                          )),
                            ),
                            IconButton(
                              tooltip: '舉報課程',
                              icon: Icon(
                                Icons.flag_outlined,
                                color:
                                    (_courseReportCooldownUntil != null &&
                                        DateTime.now().isBefore(
                                          _courseReportCooldownUntil!,
                                        ))
                                    ? Colors.white24
                                    : Colors.white,
                              ),
                              onPressed: () => _showReportSheet(
                                reportType: 'course',
                                title: '舉報課程',
                                targetKey: widget.courseId,
                                courseId: widget.courseId,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTags(),
                  const SizedBox(height: 16),
                  _buildStatRow(purchased, bookmarks),
                  const SizedBox(height: 16),
                  _buildInstructorInfo(),
                  const SizedBox(height: 24),
                  const Text(
                    "課程簡介",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.6,
                      fontSize: 15,
                    ),
                  ),
                  if (introVideo.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
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
                          '課程介紹影片',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          '所有人皆可觀看',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
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
                                videoUrl: introVideo,
                                lessonTitle: '課程介紹影片',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  const Text(
                    "課程章節",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildEpisodeTile(lessons[index]),
                childCount: lessons.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white24, height: 40),

                  _buildCommentSection(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _buildBottomPurchaseAction(
        coursePrice,
        showPurchased,
      ),
    );
  }

  Widget _buildRatingBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text("您的評分: ", style: TextStyle(color: Colors.white70)),
          Text(
            _currentUserRating > 0 ? "$_currentUserRating 星" : "尚未評分",
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _showRatingDialog,
            icon: Icon(Icons.edit, size: 16),
            label: Text("修改評分"),
            style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRatingBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.2),
            Colors.blue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "課程評分",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    "$_currentUserRating",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        Icons.star,
                        size: 16,
                        color: i < _currentUserRating
                            ? Colors.amber
                            : Colors.white24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _showRatingDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text("修改評分", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // --- UI 組件 ---

  Widget _buildEpisodeTile(Map<String, dynamic> ep) {
    final bool isLocked = ep['isLocked'] == true;
    final String lName = ep['title'] ?? '未命名章節'; // 修正：將 lesson 改為 ep
    final double lPrice =
        double.tryParse(ep['price']?.toString() ?? '0') ??
        0.0; // 修正：將 lesson 改為 ep

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          if (isLocked) {
            _showLockDialog();
          } else {
            final userProvider = Provider.of<UserProvider>(
              context,
              listen: false,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentLessonPlayerPage(
                  videoUrl: ep['video'] ?? "",
                  lessonId: (ep['lId'] ?? '').toString(),
                  lessonTitle: lName,
                  memberId: userProvider.currentUser?.memberId,
                ),
              ),
            );
          }
        },
        leading: Icon(
          isLocked ? Icons.lock_outline : Icons.play_circle_fill,
          color: isLocked ? Colors.white24 : Colors.purpleAccent,
        ),
        title: Text(
          lName,
          style: TextStyle(color: isLocked ? Colors.grey : Colors.white),
        ),
        subtitle: isLocked
            ? Text(
                '積分 ${lPrice.toInt()}',
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 12,
                ),
              )
            : const Text(
                '已解鎖',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
        trailing: isLocked
            ? IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  // --- 加入這段檢查 ---
                  if (AuthGuard.check(context)) {
                    _navigateToPayment(lName, lPrice, lId: ep['lId']);
                  }
                },
              )
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _buildBottomPurchaseAction(double price, bool isOwned) {
    // 加入 bool isOwned 參數
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 15,
        bottom: MediaQuery.of(context).padding.bottom + 15,
      ),
      decoration: BoxDecoration(color: Colors.grey[900]),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOwned ? "您已擁有此課程" : "全課優惠價",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  "積分 ${price.toInt()}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isOwned ? Colors.grey[700] : Colors.purpleAccent,
            ),
            onPressed: isOwned
                ? null
                : () {
                    // --- 加入這段檢查 ---
                    if (AuthGuard.check(context)) {
                      _navigateToPayment(widget.courseTitle, price);
                    }
                  },
            child: Text(isOwned ? "已擁有此課程" : "立即購買"),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorInfo() {
    // 注意：請檢查你的 course.php 返回的是 mentorName 還是 username
    final String instructorName = courseData?['mentorName'] ?? "導師";
    final String? instructorAvatar = courseData?['mentorAvatar'];

    return InkWell(
      onTap: () {
        final String mId = courseData?['mId']?.toString() ?? "";
        if (mId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MentorDetailPage(mId: mId)),
          );
        }
      },
      child: Row(
        children: [
          _buildAvatar(url: instructorAvatar, name: instructorName, radius: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instructorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Text(
                "查看導師詳細資訊 >",
                style: TextStyle(color: Colors.blueAccent, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(int purchased, int bookmarks) {
    // 確保讀取的是計算後的評分
    final String displayRating = courseData?['rating']?.toString() ?? "0.0";

    return Row(
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 18),
        const SizedBox(width: 4),
        Text(
          displayRating,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.people_outline, color: Colors.blueAccent, size: 18),
        const SizedBox(width: 4),
        Text(
          "$purchased 人已購買",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.favorite_border, color: Colors.redAccent, size: 18),
        const SizedBox(width: 4),
        Text(
          "$bookmarks 收藏",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  // 修改後的 _buildCommentItem
  Widget _buildCommentItem({
    required String reviewerId,
    required String commentId,
    required String name,
    required String comment,
    required String createdAt,
    String? avatarUrl,
  }) {
    final String fullUrl = UserApiService.getFullImageUrl(avatarUrl);
    final disabledUntil = _commentReportCooldownUntil[commentId];
    final isReportDisabled =
        disabledUntil != null && DateTime.now().isBefore(disabledUntil);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _handleReviewerAvatarTap(reviewerId: reviewerId),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.purple[800],
              child: ClipOval(
                child: Image.network(
                  fullUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  cacheWidth: 120,
                  cacheHeight: 120,
                  semanticLabel: '$name 的頭像',
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : "?",
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      _formatReviewTime(createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: isReportDisabled
                          ? null
                          : () => _showReportSheet(
                              reportType: 'comment',
                              title: '舉報評論',
                              targetKey: commentId,
                              courseId: widget.courseId,
                              commentId: commentId,
                            ),
                      child: Text(
                        '舉報',
                        style: TextStyle(
                          color: isReportDisabled
                              ? Colors.white24
                              : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 第一部分：單獨的評分控制區 (只有買了的人能看/改) ---
        if (isPurchased) ...[
          const Text(
            "您的評分",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildUserRatingBar(), // 這裡面有修改按鈕，會彈出 Dialog 改星星
          const SizedBox(height: 30),
        ],

        // --- 第二部分：純文字評論區 ---
        const Text(
          "學員評論",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(color: Colors.white24, height: 30),

        if (isPurchased) ...[
          const Text(
            "發表心得：",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "分享您的學習感想...",
                    hintStyle: const TextStyle(
                      color: Colors.white30,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _postReview,
                icon: const Icon(Icons.send, color: Colors.purpleAccent),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // 評論列表 (現在調用修改後的 _buildCommentItem，不會再顯示星星)
        reviews.isEmpty
            ? const Text("暫無評論", style: TextStyle(color: Colors.grey))
            : Column(
                children: reviews
                    .map(
                      (r) => _buildCommentItem(
                        reviewerId: (r['reviewerId'] ?? '').toString(),
                        commentId: (r['trId'] ?? '').toString(),
                        name: (r['username'] ?? "未知用戶").toString(),
                        comment: (r['comment'] ?? "").toString(),
                        createdAt: (r['createDate'] ?? '').toString(),
                        avatarUrl: (r['avatar'] ?? '').toString(),
                      ),
                    )
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildAvatar({String? url, required String name, double radius = 18}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.purple[800],
      child: ClipOval(
        child: Image.network(
          UserApiService.getFullImageUrl(url),
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
                fontSize: radius,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTags() {
    // 獲取從 API 傳來的 categoryName
    final String categoryName = courseData?['categoryName'] ?? "未分類";

    return Wrap(
      spacing: 8,
      children: [
        Chip(
          label: Text(
            categoryName,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          backgroundColor: Colors.orangeAccent.withOpacity(0.2), // 設定一個顯眼的顏色
          side: const BorderSide(color: Colors.orangeAccent),
        ),
        // 您原本的靜態標籤
      ],
    );
  }

  // 抽取出來的小元件，讓代碼更整潔
  Widget _buildSingleTag(String text, Color bgColor) {
    return Chip(
      label: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: bgColor.withOpacity(0.2),
      side: BorderSide(color: bgColor.withOpacity(0.5)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _PublicMemberProfilePage extends StatelessWidget {
  final String memberId;

  const _PublicMemberProfilePage({required this.memberId});

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('使用者檔案'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: UserApiService.getPublicMemberProfile(memberId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '無法載入使用者資料',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      snapshot.error?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final profile = (data['profile'] is Map)
              ? (data['profile'] as Map)
              : const {};
          final List courses = (data['courses'] is List)
              ? (data['courses'] as List)
              : const [];

          final username = (profile['username'] ?? '未知使用者').toString();
          final avatar = (profile['avatar'] ?? '').toString();
          final mType = (profile['mType'] ?? '').toString();
          final regDate = _formatDate((profile['regDate'] ?? '').toString());
          final gender = (profile['gender'] ?? '').toString();
          final selfIntro = (profile['selfIntro'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.purple.withOpacity(0.2),
                    child: ClipOval(
                      child: Image.network(
                        UserApiService.getFullImageUrl(avatar),
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        cacheWidth: 120,
                        cacheHeight: 120,
                        semanticLabel: '$username 的頭像',
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (mType.isNotEmpty)
                              _tag(mType == 'T' ? '老師' : '學生'),
                            if (gender.isNotEmpty) _tag('性別:$gender'),
                            if (regDate.isNotEmpty) _tag('註冊:$regDate'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (selfIntro.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    selfIntro,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                '已購買課程 (${courses.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              if (courses.isEmpty)
                const Text('尚無購買紀錄', style: TextStyle(color: Colors.white38))
              else
                ...courses.map((it) {
                  final m = it is Map ? it : const {};
                  final cId = (m['cId'] ?? '').toString();
                  final title = (m['title'] ?? '').toString();
                  final mentorName = (m['mentorName'] ?? '未知導師').toString();
                  final introImg = (m['introImg'] ?? '').toString();
                  final purchaseType = (m['purchaseType'] ?? '').toString();
                  final purchaseDate = _formatDate(
                    (m['purchaseDate'] ?? '').toString(),
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
                            CourseApiService.getFullImageUrl(introImg),
                            fit: BoxFit.cover,
                            cacheWidth: 240,
                            cacheHeight: 240,
                            semanticLabel: '$title 封面',
                            errorBuilder: (context, error, stackTrace) =>
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '老師：$mentorName',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            if (purchaseType.isNotEmpty)
                              Text(
                                '購買方式：${purchaseType == 'course' ? '整課' : '單課時'}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            if (purchaseDate.isNotEmpty)
                              Text(
                                '日期：$purchaseDate',
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
                }),
            ],
          );
        },
      ),
    );
  }

  static Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
