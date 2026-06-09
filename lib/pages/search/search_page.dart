import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../services/course_api_service.dart';
import '../../services/user_api_service.dart';
import '../course/course_page.dart';
import '../course/mentor_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // ── 搜尋結果 ──
  List<dynamic> _courseResults = [];
  List<dynamic> _teacherResults = [];

  // ── 歷史 & 熱門 ──
  List<String> _historyResults = [];
  List<String> _popularResults = [];
  bool _isLoadingPopular = true;

  // ── 類別 ──
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;

  // ── 狀態 ──
  bool _showResults = false;
  bool _isSearching = false;
  String _noResultsMessage = '';

  // ── Tab 篩選：0=課程, 1=老師, 2=類別 ──
  int _selectedTab = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _selectedTab = _tabController.index);
    });
    _loadHistory();
    _loadPopular();
    _loadCategories();
  }

  Future<void> _loadHistory() async {
    final history = await SearchService.getHistory();
    if (mounted) setState(() => _historyResults = history);
  }

  Future<void> _loadPopular() async {
    setState(() => _isLoadingPopular = true);
    final popular = await SearchService.getPopularSearches();
    if (mounted) {
      setState(() {
        _popularResults = popular;
        _isLoadingPopular = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    final cats = await SearchService.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoadingCategories = false;
      });
    }
  }

  // ── 執行搜尋（同時查課程和老師，並補充老師的課程）──
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _courseResults.clear();
        _teacherResults.clear();
        _noResultsMessage = '';
        _showResults = false;
        _isSearching = false;
      });
      return;
    }

    _focusNode.unfocus();

    setState(() {
      _isSearching = true;
      _showResults = true;
      _courseResults.clear();
      _teacherResults.clear();
    });

    // ══════════════════════════════════════════════════════════
    // 修正：各自獨立 catchError，避免其中一個失敗導致全部清空
    // ══════════════════════════════════════════════════════════
    List<dynamic> courses = [];
    List<dynamic> teachers = [];

    await Future.wait([
      SearchService.searchCourses(query.trim())
          .then((r) {
            courses = r;
          })
          .catchError((_) {
            courses = [];
          }),
      SearchService.searchTeachers(query.trim())
          .then((r) {
            teachers = r;
          })
          .catchError((_) {
            teachers = [];
          }),
    ]);

    // ── 找到老師後，補充老師的課程到課程結果 ──
    if (teachers.isNotEmpty) {
      // 取出所有老師的 mId
      final mIds = teachers
          .map((t) => t['mId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (mIds.isNotEmpty) {
        // 修正：用獨立 try/catch，避免此步驟失敗影響已有的 courses
        try {
          final teacherCourses = await SearchService.searchCoursesByMIds(mIds);

          // 合併，避免重複（以 cId 去重）
          final existingCIds = courses.map((c) => c['cId']?.toString()).toSet();
          final newCourses = teacherCourses
              .where((c) => !existingCIds.contains(c['cId']?.toString()))
              .toList();

          courses = [...courses, ...newCourses];
        } catch (_) {
          // 取老師課程失敗時，保留已有的 courses，不清空
        }
      }
    }

    // 有任何結果才寫入歷史
    if (courses.isNotEmpty || teachers.isNotEmpty) {
      final updated = await SearchService.addHistory(query.trim());
      if (mounted) setState(() => _historyResults = updated);
    }

    if (mounted) {
      setState(() {
        _courseResults = courses;
        _teacherResults = teachers;
        _isSearching = false;
        final total = courses.length + teachers.length;
        _noResultsMessage = total == 0 ? '沒有找到相關結果，請嘗試其他關鍵詞' : '';
      });
    }
  }

  // ── 點擊類別 Chip 進行類別搜尋 ──
  Future<void> _searchByCategory(String category) async {
    _searchController.text = category;
    _focusNode.unfocus();

    setState(() {
      _isSearching = true;
      _showResults = true;
      _courseResults.clear();
      _teacherResults.clear();
      _selectedTab = 0; // 類別搜尋結果顯示在課程 Tab
      _tabController.animateTo(0);
    });

    try {
      final results = await SearchService.searchByCategory(category);
      if (mounted) {
        setState(() {
          _courseResults = results;
          _teacherResults = [];
          _isSearching = false;
          _noResultsMessage = results.isEmpty ? '此類別暫無課程' : '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _noResultsMessage = '搜尋失敗，請檢查網絡連接';
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _courseResults.clear();
      _teacherResults.clear();
      _noResultsMessage = '';
      _showResults = false;
      _isSearching = false;
    });
  }

  Future<void> _removeHistoryItem(int index) async {
    final updated = await SearchService.removeHistory(index);
    if (mounted) setState(() => _historyResults = updated);
  }

  Future<void> _clearAllHistory() async {
    await SearchService.clearHistory();
    if (mounted) setState(() => _historyResults = []);
  }

  String _getString(dynamic item, List<String> keys, String fallback) {
    for (final key in keys) {
      final val = item[key];
      if (val != null && val.toString().isNotEmpty) return val.toString();
    }
    return fallback;
  }

  // ════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _showResults ? _buildResultsBody() : _buildHomebody(),
    );
  }

  // ── AppBar ──
  AppBar _buildAppBar() {
    return AppBar(
      toolbarHeight: 70,
      backgroundColor: const Color.fromARGB(255, 27, 27, 27),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
          color: const Color.fromARGB(255, 104, 99, 104),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: '搜索課程、老師、科目...',
                  hintStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.search, color: Colors.black),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.black),
                    onPressed: _clearSearch,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 56, 55, 56),
                      width: 1,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: _performSearch,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  //  搜尋前主頁（歷史 + 熱門 + 類別 Chips）
  // ════════════════════════════════════════════
  Widget _buildHomebody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 類別快捷 Chips ──
          const Text(
            '瀏覽類別',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _isLoadingCategories
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: Colors.orange),
                  ),
                )
              : _categories.isEmpty
              ? Text('暫無類別資料', style: TextStyle(color: Colors.grey[500]))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final subject = cat['subject']?.toString() ?? '';
                    final count = cat['courseCount'] ?? 0;
                    return GestureDetector(
                      onTap: () => _searchByCategory(subject),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[700]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              subject,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '($count)',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

          const SizedBox(height: 24),

          // ── 搜索歷史 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '搜索歷史',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_historyResults.isNotEmpty)
                TextButton(
                  onPressed: _clearAllHistory,
                  child: const Text(
                    '清除全部',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_historyResults.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('暫無搜索歷史', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _historyResults.length,
              itemBuilder: (context, index) {
                final history = _historyResults[index];
                return Card(
                  color: Colors.grey[800],
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.history, color: Colors.grey),
                    title: Text(
                      history,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => _removeHistoryItem(index),
                    ),
                    onTap: () {
                      _searchController.text = history;
                      _performSearch(history);
                    },
                  ),
                );
              },
            ),

          const SizedBox(height: 24),

          // ── 熱門搜索 ──
          const Text(
            '熱門搜索',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingPopular)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _popularResults.length,
              itemBuilder: (context, index) {
                final popular = _popularResults[index];
                return Card(
                  color: Colors.grey[800],
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: index < 3 ? Colors.orange : Colors.grey[700],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: index < 3 ? 14 : 12,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      popular,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      _searchController.text = popular;
                      _performSearch(popular);
                    },
                  ),
                );
              },
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  //  搜尋結果頁（Tab: 課程 / 老師 / 類別）
  // ════════════════════════════════════════════
  Widget _buildResultsBody() {
    return Column(
      children: [
        // ── Tab 列 ──
        Container(
          color: const Color.fromARGB(255, 27, 27, 27),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: '課程 (${_courseResults.length})'),
              Tab(text: '老師 (${_teacherResults.length})'),
              const Tab(text: '類別'),
            ],
          ),
        ),

        // ── 內容 ──
        Expanded(
          child: _isSearching
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.orange),
                      SizedBox(height: 10),
                      Text('搜索中...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCourseTab(),
                    _buildTeacherTab(),
                    _buildCategoryTab(),
                  ],
                ),
        ),
      ],
    );
  }

  // ── 課程 Tab ──
  Widget _buildCourseTab() {
    if (_courseResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.menu_book_outlined,
        message: _noResultsMessage.isNotEmpty ? _noResultsMessage : '沒有找到相關課程',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _courseResults.length,
      itemBuilder: (context, index) => _buildCourseCard(_courseResults[index]),
    );
  }

  // ── 老師 Tab ──
  Widget _buildTeacherTab() {
    if (_teacherResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search_outlined,
        message: '沒有找到相關老師',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _teacherResults.length,
      itemBuilder: (context, index) =>
          _buildTeacherCard(_teacherResults[index]),
    );
  }

  // ── 類別 Tab ──
  Widget _buildCategoryTab() {
    if (_isLoadingCategories) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }
    if (_categories.isEmpty) {
      return _buildEmptyState(icon: Icons.category_outlined, message: '暫無類別資料');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final subject = cat['subject']?.toString() ?? '';
        final count = cat['courseCount'] ?? 0;
        return GestureDetector(
          onTap: () => _searchByCategory(subject),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.label_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        subject,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$count 門課程',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════
  //  課程卡片（左縮圖 + 右資訊）
  // ════════════════════════════════════════════
  Widget _buildCourseCard(dynamic item) {
    final String courseId = _getString(item, ['cId'], '');
    final String title = _getString(item, ['cName'], '未命名課程');
    final String instructor = _getString(item, [
      'instructor',
      'instructorName',
      'mId',
    ], '');
    final String price = _getString(item, ['unitPrice'], '0');
    final String subject = _getString(item, ['subject', 'categoryName'], '');
    final String introImg = _getString(item, ['introImg'], '');

    // 取得縮圖網址
    final String imageUrl = introImg.isNotEmpty
        ? CourseApiService.getFullImageUrl(introImg)
        : CourseApiService.getFullImageUrl(null);

    return GestureDetector(
      onTap: () {
        SearchService.recordCourseSearch(courseId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CoursePage(courseTitle: title, courseId: courseId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 左側縮圖 ──
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: SizedBox(
                width: 120,
                height: 90,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.play_circle_outline,
                      color: Colors.orange,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),

            // ── 右側資訊 ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 標題
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 講師
                    if (instructor.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: Colors.grey,
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              instructor,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 4),

                    // 類別 + 價格
                    Row(
                      children: [
                        if (subject.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              subject,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(
                          Icons.attach_money,
                          color: Colors.orange,
                          size: 14,
                        ),
                        Text(
                          price,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  //  老師卡片（頭像縮圖 + 資訊）
  // ════════════════════════════════════════════
  Widget _buildTeacherCard(dynamic item) {
    final String mId = _getString(item, ['mId'], '');
    final String username = _getString(item, ['username'], '未知老師');
    final String avatar = _getString(item, ['avatar'], '');
    final int courseCount = (item['courseCount'] as num?)?.toInt() ?? 0;
    final double avgRating = (item['avgRating'] as num?)?.toDouble() ?? 0.0;

    // 頭像網址
    final String avatarUrl = UserApiService.getFullImageUrl(avatar);

    return GestureDetector(
      onTap: () {
        if (mId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MentorDetailPage(mId: mId)),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // ── 左側頭像 ──
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: SizedBox(
                width: 90,
                height: 90,
                child: Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildAvatarFallback(username),
                ),
              ),
            ),

            // ── 右側資訊 ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名稱
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // 身份標籤
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '老師',
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 課程數 + 評分
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          color: Colors.grey,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$courseCount 門課程',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        if (avgRating > 0) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── 右箭頭 ──
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ── 頭像 Fallback（首字母）──
  Widget _buildAvatarFallback(String name) {
    return Container(
      color: Colors.purple[800],
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── 空狀態 ──
  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '建議：檢查拼寫、嘗試更通用的關鍵詞',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
