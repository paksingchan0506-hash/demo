import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'course_page.dart';
import 'add_course_page.dart';
import '../search/search_page.dart';
import '../../services/course_api_service.dart';

class CourseSuggestionPage extends StatefulWidget {
  const CourseSuggestionPage({super.key});

  @override
  _CourseSuggestionPageState createState() => _CourseSuggestionPageState();
}

class _CourseSuggestionPageState extends State<CourseSuggestionPage> {
  List<dynamic> _phpCourses = [];
  bool _isLoading = true;
  Set<String> _purchasedCourseIds = {};

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  // 1. 抓取 API 資料
  Future<void> _fetchCourses() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final mId = userProvider.currentUser?.memberId ?? '';

      Set<String> purchasedIds = {};
      if (mId.isNotEmpty) {
        try {
          final myCourses = await CourseApiService.getMyCourses(mId);
          purchasedIds = myCourses
              .whereType<Map>()
              .map((e) => (e['cId'] ?? '').toString())
              .where((e) => e.isNotEmpty)
              .toSet();
        } catch (_) {
          purchasedIds = {};
        }
      }

      final data = await CourseApiService.getAllCourses();
      debugPrint('API 返回數據範例: ${data.isNotEmpty ? data[0] : "空列表"}');
      
      if (mounted) {
        setState(() {
          _purchasedCourseIds = purchasedIds;
          _phpCourses = mId.isNotEmpty
              ? data
                  .whereType<Map>()
                  .where(
                    (c) =>
                        !_purchasedCourseIds.contains((c['cId'] ?? '').toString()),
                  )
                  .toList()
              : data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('抓取課程失敗: $e');
    }
  }

  // 2. 關鍵分組邏輯：將課程依照回傳的 categoryName 進行分組
  Map<String, List<dynamic>> get _groupedCourses {
    Map<String, List<dynamic>> groups = {};
    for (var course in _phpCourses) {
      // 確保 categoryName 欄位存在且不為空字串
      String cat = (course['categoryName']?.toString() ?? '未分類').trim();
      if (cat.isEmpty) cat = '未分類';

      if (!groups.containsKey(cat)) {
        groups[cat] = [];
      }
      groups[cat]!.add(course);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final bool isTeacher = userProvider.isTeacher;
    final groups = _groupedCourses;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('探索課程', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (isTeacher)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.purpleAccent),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddCoursePage())),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCourses,
        color: Colors.purpleAccent,
        child: CustomScrollView(
          slivers: [
            // 搜尋欄
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.search, color: Colors.grey, size: 20),
                        SizedBox(width: 10),
                        Text('想學些什麼？', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 分類課程列表
            _isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
                  )
                : groups.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(child: Text("暫無課程資料", style: TextStyle(color: Colors.grey))),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            String category = groups.keys.elementAt(index);
                            List<dynamic> coursesInCat = groups[category]!;
                            return _buildCategoryRow(category, coursesInCat);
                          },
                          childCount: groups.keys.length,
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(String title, List<dynamic> courses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: courses.length,
            itemBuilder: (context, idx) {
              return _buildCourseCard(courses[idx]);
            },
          ),
        ),
        const SizedBox(height: 10),
        const Divider(color: Colors.white10, thickness: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildCourseCard(dynamic course) {
    final String title = course['cName'] ?? '未命名課程';
    final String price = (course['unitPrice'] ?? '0').toString();
    final String mentor = course['mentorName'] ?? '未知導師';
    final String imageUrl = CourseApiService.getFullImageUrl(course['introImg']);
    final double rating = double.tryParse(course['rating'].toString()) ?? 0.0;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CoursePage(
              courseTitle: title,
              courseId: course['cId'] ?? '',
            ),
          ),
        );
        if (mounted) await _fetchCourses();
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                height: 110,
                width: 170,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 110,
                  width: 170,
                  color: Colors.grey[850],
                  child: const Icon(Icons.book, color: Colors.white24, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(mentor, style: TextStyle(color: Colors.grey[400], fontSize: 11), overflow: TextOverflow.ellipsis)),
                const Icon(Icons.star, color: Colors.amber, size: 12),
                const SizedBox(width: 2),
                Text(rating.toString(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
            const Spacer(),
            Text(
              '積分 $price',
              style: const TextStyle(
                color: Colors.purpleAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
