import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:fl_chart/fl_chart.dart';
import '../../services/aws_config.dart';
import '../../services/aws_service.dart';
import '../../models/course.dart';
import '../../services/user_api_service.dart';
// 確保匯入分析頁面
import 'video_upload_page.dart'; // 導入影片上傳頁面
import '../course/video_player_page.dart'; // 導入影片播放頁面
import '../../services/api_service.dart';
import '../../providers/user_provider.dart';

class CourseManagementPage extends StatefulWidget {
  final Course course;
  final int? initialTab;
  final String? initialStudentIdToOpen;

  const CourseManagementPage({
    super.key,
    required this.course,
    this.initialTab,
    this.initialStudentIdToOpen,
  });

  @override
  State<CourseManagementPage> createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  int _selectedTab = 0;
  List<dynamic> _lessons = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _courseDetails = {};
  bool _isLoadingCourseDetails = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab ?? 0;
    _loadCourseLessons();
    _loadCourseDetails();
    final sid = widget.initialStudentIdToOpen;
    if (sid != null && sid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showStudentDetailDialog(sid);
      });
    }
  }

  Future<void> _loadCourseDetails() async {
    if (mounted) {
      setState(() {
        _isLoadingCourseDetails = true;
      });
    }

    try {
      final response = await ApiService.getCourseStats(widget.course.id);
      if (response['status'] == 'success' && mounted) {
        setState(() {
          _courseDetails = response['stats'] ?? {};
        });
      }
    } catch (e) {
      print('Error loading course details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCourseDetails = false;
        });
      }
    }
  }

  Future<void> _loadCourseLessons() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await ApiService.getCourseLessons(widget.course.id);

      if (mounted) {
        setState(() {
          if (response is Map && response.containsKey('lessons')) {
            _lessons = response['lessons'];
          } else {
            _lessons = [];
          }
        });
      }
    } catch (e) {
      print('Error loading lessons: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '加載章節失敗，請稍後再試';
          _lessons = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.course.title),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.purpleAccent),
            onPressed: _loadCourseLessons,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTab('課程內容', 0),
          _buildTab('學生管理', 1),
          _buildTab('數據分析', 2), // 原為數據統計
          _buildTab('課程設置', 3),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.purpleAccent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.purpleAccent : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildContentList();
      case 1:
        return _buildStudentList();
      case 2:
        // 3. 課程頁面數據分析 (包含收入、收藏、觀看、轉發、趨勢圖)
        return _buildAnalyticsView();
      case 3:
        return _buildCourseSettings();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAnalyticsView() {
    return FutureBuilder(
      future: ApiService.getCourseStudentStats(widget.course.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.purpleAccent),
          );
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data['status'] != 'success') {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  color: Colors.grey,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text('加載數據分析失敗', style: TextStyle(color: Colors.grey[400])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                  ),
                  child: const Text('重新加載'),
                ),
              ],
            ),
          );
        }

        final stats = snapshot.data['stats'] ?? {};
        final revenueTrend = (snapshot.data['revenueTrend'] as List?) ?? [];
        final recentActivities =
            (snapshot.data['recentActivities'] as List?) ?? [];
        final totalIncome = stats['totalIncome'] ?? 0.0;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. 核心指標
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  '總收入',
                  '$totalIncome',
                  Icons.account_balance_wallet,
                  Colors.orangeAccent,
                ),
                _buildStatCard(
                  '已購買人數',
                  '${stats['totalStudents'] ?? 0}',
                  Icons.shopping_cart,
                  Colors.blueAccent,
                ),
                _buildStatCard(
                  '課程收藏數',
                  '${stats['bookmarkCount'] ?? 0}',
                  Icons.bookmark,
                  Colors.pinkAccent,
                ),
                _buildStatCard(
                  '平均評分',
                  '${stats['avgRating'] ?? 0.0}',
                  Icons.star,
                  Colors.amberAccent,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 2. 累計總收入趨勢圖
            _buildChartSection(revenueTrend),

            const SizedBox(height: 24),

            // 3. 最近活動
            _buildRecentActivitiesSection(recentActivities),
          ],
        );
      },
    );
  }

  Widget _buildChartSection(List trendData) {
    if (trendData.isEmpty) return const SizedBox();

    // 計算數據範圍
    final values = trendData
        .map((e) => (e['value'] as num).toDouble())
        .toList();
    double minVal = values.reduce((a, b) => a < b ? a : b);
    double maxVal = values.reduce((a, b) => a > b ? a : b);

    double diff = maxVal - minVal;
    // 確保即使數據全是 0 或全部相同，也能看到一條在中間的線
    double minY = (diff > 0) ? (minVal - diff * 0.5) : (minVal - 100);
    double maxY = (diff > 0) ? (maxVal + diff * 0.5) : (maxVal + 100);

    if (minY < 0) minY = 0;
    if (maxY <= minY) maxY = minY + 500;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '累計總收入趨勢',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.grey[800]!,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        return LineTooltipItem(
                          '累計收入: 積分 ${touchedSpot.y.toStringAsFixed(0)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < trendData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              trendData[index]['date'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max)
                          return const SizedBox();
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: trendData.asMap().entries.map((e) {
                      return FlSpot(
                        e.key.toDouble(),
                        (e.value['value'] as num).toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Colors.purpleAccent, Colors.blueAccent],
                    ),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.purpleAccent.withOpacity(0.2),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesSection(List activities) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              '最近動態',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Center(
                child: Text('暫無活動記錄', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, index) =>
                  Divider(color: Colors.grey[800], height: 1),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purpleAccent.withOpacity(0.1),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.purpleAccent,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    activity['username'] ?? '未知用戶',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    activity['history'] ?? '',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  trailing: Text(
                    activity['regDate']?.toString().split(' ')[0] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(dynamic activity) {
    return ListTile(
      title: Text(
        activity['history'] ?? '未知活動',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        activity['username'] ?? '未知用戶',
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: Text(
        activity['regDate'] ?? '未知時間',
        style: const TextStyle(color: Colors.white24, fontSize: 12),
      ),
    );
  }

  Widget _buildContentList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCourseLessons,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
              ),
              child: const Text('重新加載', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildCourseIntroHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _lessons.length + 1, // 增加一个项目用于添加新内容
            itemBuilder: (context, index) {
              if (index == _lessons.length) {
                // 添加新內容的按鈕
                return Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 24),
                  child: OutlinedButton.icon(
                    onPressed: _showAddContentDialog,
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text(
                      '添加新課程內容',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purpleAccent,
                      side: const BorderSide(
                        color: Colors.purpleAccent,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              }

              final lesson = _lessons[index];
              final hasVideo = lesson['video'] != null && lesson['video'] != '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showLessonDetailDialog(lesson),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: hasVideo
                                    ? Colors.purpleAccent.withOpacity(0.1)
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                hasVideo
                                    ? Icons.play_arrow_rounded
                                    : Icons.videocam_off_outlined,
                                color: hasVideo
                                    ? Colors.purpleAccent
                                    : Colors.grey[500],
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (lesson['lName'] ?? '未命名課程'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.grey[500],
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${lesson['duration'] ?? 0} 分鐘',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.payments_outlined,
                                        color: Colors.grey[500],
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '積分 ${lesson['price'] ?? 0}',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_note_rounded,
                                    color: Colors.grey[400],
                                    size: 26,
                                  ),
                                  onPressed: () => _editLesson(lesson),
                                  tooltip: '編輯名稱/時長與積分',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 24,
                                  ),
                                  onPressed: () =>
                                      _showDeleteLessonDialog(lesson),
                                  tooltip: '刪除章節',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddContentDialog() {
    TextEditingController titleController = TextEditingController();
    TextEditingController priceController = TextEditingController(text: '0');
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              '添加新課程內容',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '請輸入章節名稱與價格，影片時長將在上傳後自動計算。',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '章節名稱',
                    labelStyle: TextStyle(color: Colors.grey),
                    hintText: '例如：第一課：環境架設',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purpleAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '章節價格 (積分)',
                    labelStyle: TextStyle(color: Colors.grey),
                    hintText: '輸入價格',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purpleAccent),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        String title = titleController.text.trim();
                        double price =
                            double.tryParse(priceController.text.trim()) ?? 0.0;

                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請填寫章節名稱')),
                          );
                          return;
                        }

                        setState(() {
                          isLoading = true;
                        });

                        try {
                          final response = await ApiService.createLesson(
                            courseId: widget.course.id,
                            lessonName: title,
                            duration: 0, // 初始時長為0，上傳影片後自動更新
                            price: price,
                            orderNum: _lessons.length + 1,
                          );

                          if (response['status'] == 'success') {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('新章節已創建')),
                            );
                            _loadCourseLessons();
                          } else {
                            throw Exception(response['message'] ?? '創建失敗');
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('創建失敗: ${e.toString()}')),
                          );
                        } finally {
                          setState(() {
                            isLoading = false;
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.purpleAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '確定',
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLessonDetailDialog(dynamic lesson) {
    final hasVideo = lesson['video'] != null && lesson['video'] != '';
    final videoUrl = lesson['video'] ?? '';
    final lId = lesson['lId'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 頂部條
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 標題與基本信息
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      lesson['lName'] ?? '章節詳情',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditLessonDialog(lesson);
                    },
                    icon: const Icon(
                      Icons.edit_note,
                      color: Colors.purpleAccent,
                    ),
                    tooltip: '編輯章節資訊',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildInfoTag(
                    Icons.access_time,
                    '${lesson['duration'] ?? 0} 分鐘',
                    Colors.blueGrey,
                  ),
                  _buildInfoTag(
                    Icons.payments_outlined,
                    '積分 ${lesson['price'] ?? 0}',
                    Colors.orangeAccent,
                  ),
                  _buildInfoTag(
                    hasVideo ? Icons.check_circle : Icons.error_outline,
                    hasVideo ? '已上傳影片' : '尚未上傳影片',
                    hasVideo ? Colors.green : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '上傳時間: ${lesson['uploadDateTime'] ?? '未知'}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.grey, height: 1),
              const SizedBox(height: 24),

              // 影片操作組
              const Text(
                '影片管理',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (hasVideo) ...[
                _buildActionButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerPage(
                          videoUrl: AWSService.getPresignedUrl(videoUrl),
                          lessonTitle: lesson['lName'] ?? '影片播放',
                        ),
                      ),
                    );
                  },
                  icon: Icons.play_circle_fill,
                  label: '播放影片',
                  color: Colors.purpleAccent,
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteVideo(lesson);
                  },
                  icon: Icons.delete_forever,
                  label: '刪除影片',
                  color: Colors.red[400]!,
                  isOutlined: true,
                ),
              ] else
                _buildActionButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _uploadVideo(lesson);
                  },
                  icon: Icons.cloud_upload,
                  label: '上傳影片',
                  color: Colors.purpleAccent,
                ),

              const SizedBox(height: 24),
              // 教材管理組
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '教材管理',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _showAddResourceOptions(lId, setModalState),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加教材'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.purpleAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 資源列表
              FutureBuilder<dynamic>(
                future: ApiService.getLessonResources(lId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final resources = snapshot.data?['resources'] as List? ?? [];
                  if (resources.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '暫無教材檔案',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: resources
                        .map((res) => _buildResourceItem(res, setModalState))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceItem(dynamic res, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            res['resourceType'] == 'FILE'
                ? Icons.description_outlined
                : Icons.link,
            color: Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  res['lrName'] ?? '未命名檔案',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (res['modifiedDate'] != null)
                  Text(
                    res['modifiedDate'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: () => _deleteSingleResource(res, setModalState),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSingleResource(
    dynamic resource,
    StateSetter setModalState,
  ) async {
    final lrId = resource['lrId'];
    final resourcePath = resource['path'] ?? '';
    final resourceType = resource['resourceType'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('確認刪除', style: TextStyle(color: Colors.white)),
        content: const Text(
          '確定要刪除此教材檔案嗎？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 1. 調用 API 刪除資料庫記錄 (API 現在會檢查引用)
        final resp = await ApiService.deleteLessonResource(lrId);

        if (resp['status'] == 'success') {
          if (resp['shouldDeleteS3'] == true && resourceType == 'FILE') {
            try {
              await AWSService.deleteS3Object(_toS3ObjectKey(resourcePath));
            } catch (e) {
              print('S3 刪除失敗 (教材): $e');
            }
          } else if (resp['shouldDeleteS3'] == false) {
            print('S3 檔案保留 (仍有其他引用)');
          }

          setModalState(() {}); // 刷新 Modal 內部
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('教材已刪除')));
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
      }
    }
  }

  void _showEditLessonDialog(dynamic lesson) {
    TextEditingController titleController = TextEditingController(
      text: lesson['lName'],
    );
    TextEditingController durationController = TextEditingController(
      text: '${lesson['duration'] ?? 0}',
    );
    TextEditingController priceController = TextEditingController(
      text: '${lesson['price'] ?? 0}',
    );
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              '編輯章節資訊',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '章節名稱',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: durationController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '時長 (分鐘)',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '價格 (積分)',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        String title = titleController.text.trim();
                        int duration =
                            int.tryParse(durationController.text.trim()) ?? 0;
                        double price =
                            double.tryParse(priceController.text.trim()) ?? 0.0;

                        if (title.isEmpty) return;

                        setState(() {
                          isLoading = true;
                        });

                        try {
                          final response = await ApiService.updateLesson(
                            lessonId: lesson['lId'],
                            lessonName: title,
                            duration: duration,
                            price: price,
                          );

                          if (response['status'] == 'success') {
                            Navigator.pop(context);
                            _loadCourseLessons();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('章節資訊已更新')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('更新失敗: $e')));
                        } finally {
                          setState(() {
                            isLoading = false;
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '儲存',
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddResourceOptions(String lId, StateSetter setModalState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '添加教材方式',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blueAccent),
              title: const Text('上傳檔案', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                '從手機選擇檔案上傳至 S3',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleResourceUpload(lId, setModalState);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.greenAccent),
              title: const Text('添加網址', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                '輸入外部連結（如 Google Drive 或 YouTube）',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleUrlAdd(lId, setModalState);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUrlAdd(String lId, StateSetter setModalState) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('添加教材網址', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '資源名稱',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: '例如：參考講義',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '網址 (URL)',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'https://...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '添加',
              style: TextStyle(color: Colors.purpleAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final name = nameController.text.trim();
      final url = urlController.text.trim();

      if (name.isEmpty || url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('名稱與網址不能為空')));
        }
        return;
      }

      try {
        // 檢查限制
        final currentResourcesResp = await ApiService.getLessonResources(lId);
        final resources = currentResourcesResp['resources'] as List? ?? [];

        if (resources.length >= 3) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('每個章節最多只能添加 3 個教材資源')));
          }
          return;
        }

        final resp = await ApiService.uploadLessonResourceUrl(
          lessonId: lId,
          resourceName: name,
          resourceUrl: url,
        );

        if (resp['status'] == 'success') {
          setModalState(() {}); // 刷新 Modal 內部
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('網址已添加')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
        }
      }
    }
  }

  Future<void> _handleResourceUpload(
    String lId,
    StateSetter setModalState,
  ) async {
    try {
      // 1. 先獲取現有資源，檢查限制
      final currentResourcesResp = await ApiService.getLessonResources(lId);
      final resources = currentResourcesResp['resources'] as List? ?? [];

      if (resources.length >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('每個章節最多只能上傳 3 個教材檔案')));
        }
        return;
      }

      // 2. 選擇檔案
      final result = await FilePicker.platform.pickFiles(allowMultiple: false);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) return;

      // 3. 檢查大小限制 (1GB = 1024 * 1024 * 1024 bytes)
      const int maxTotalSize = 1024 * 1024 * 1024;
      if (file.size > maxTotalSize) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('單個檔案大小不能超過 1GB')));
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('正在上傳教材至 S3...')));
      }

      // 4. 實際執行 S3 上傳
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final mId = userProvider.currentUser?.memberId ?? 'Unknown';

      // 格式：File/member id/年/月/文件
      final objectKey = 'File/$mId/$year/$month/${file.name}';

      final s3Url = await AWSService.uploadFileToS3(File(filePath), objectKey);

      // 5. 將 S3 URL 存入資料庫
      final resp = await ApiService.uploadLessonResource(
        lessonId: lId,
        resourceName: file.name,
        resourcePath: s3Url,
      );

      if (resp['status'] == 'success') {
        setModalState(() {}); // 刷新列表
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('教材上傳成功')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
      }
    }
  }

  Widget _buildInfoTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, color: color, size: 20),
              label: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, color: Colors.white, size: 20),
              label: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }

  String _toS3ObjectKey(String path) {
    var key = path.toString();
    final bucketPrefix = 's3://${AWSConfig.s3BucketName}/';
    if (key.startsWith(bucketPrefix)) {
      key = key.replaceFirst(bucketPrefix, '');
    } else if (key.startsWith('http')) {
      try {
        final uri = Uri.parse(key);
        key = uri.path.replaceFirst(RegExp(r'^/'), '');
      } catch (_) {}
    }
    return key.replaceFirst(RegExp(r'^/'), '');
  }

  Future<void> _deleteS3Paths(List<dynamic> s3Files) async {
    for (final s3Path in s3Files) {
      try {
        final objectKey = _toS3ObjectKey(s3Path.toString());

        bool isVideoFolder =
            objectKey.contains('/transcribe/') ||
            objectKey.contains('lesson_videos/') ||
            objectKey.contains('course_videos/') ||
            (objectKey.startsWith('File/') && !objectKey.contains('/intro/')) ||
            (objectKey.startsWith('File/') &&
                objectKey.contains('/intro/') &&
                !objectKey.toLowerCase().endsWith('.jpg') &&
                !objectKey.toLowerCase().endsWith('.png') &&
                !objectKey.toLowerCase().endsWith('.jpeg'));

        if (isVideoFolder) {
          final segments = objectKey.split('/');
          if (objectKey.startsWith('File/') && segments.length >= 5) {
            final folderPath = segments.sublist(0, 5).join('/') + '/';
            await AWSService.deleteS3Folder(folderPath);
          } else if (segments.length >= 4 && !objectKey.startsWith('File/')) {
            final folderPath = segments.sublist(0, 4).join('/') + '/';
            await AWSService.deleteS3Folder(folderPath);
          } else if (objectKey.contains('/transcribe/')) {
            final tSegments = objectKey.split('/');
            tSegments.removeLast();
            await AWSService.deleteS3Folder(tSegments.join('/') + '/');
          } else {
            await AWSService.deleteS3Object(objectKey);
          }
        } else {
          await AWSService.deleteS3Object(objectKey);
        }
      } catch (e) {
        print('S3 刪除失敗: $e');
      }
    }
  }

  void _showDeleteCourseDialog() {
    bool cleanup = true;
    bool permanent = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '確認刪除整門課程？',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('您確定要刪除這門課程嗎？', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              CheckboxListTile(
                title: const Text(
                  '永久刪除 (需無購買/收藏)',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                value: permanent,
                onChanged: (val) =>
                    setModalState(() => permanent = val ?? true),
                activeColor: Colors.purpleAccent,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text(
                  '同時清理雲端影片與檔案',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  '系統會自動保留被其他課程引用的檔案',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                value: cleanup,
                onChanged: (val) => setModalState(() => cleanup = val ?? true),
                activeColor: Colors.purpleAccent,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (permanent) {
                  _purgeCourse(cleanup: cleanup);
                } else {
                  _deleteCourse(cleanup: cleanup);
                }
              },
              child: const Text(
                '確認刪除',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purgeCourse({bool cleanup = true}) async {
    try {
      final response = await ApiService.purgeCourse(
        widget.course.id,
        cleanup: cleanup,
      );
      if (response['status'] == 'success') {
        if (cleanup &&
            response['shouldDeleteS3'] == true &&
            response['s3Files'] != null) {
          final List<dynamic> s3Files = response['s3Files'];
          await _deleteS3Paths(s3Files);
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('課程已永久刪除')));
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失敗: ${response['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作發生錯誤: $e')));
      }
    }
  }

  Future<void> _deleteCourse({bool cleanup = true}) async {
    try {
      final response = await ApiService.deleteCourse(
        widget.course.id,
        cleanup: cleanup,
      );
      if (response['status'] == 'success') {
        if (cleanup &&
            response['shouldDeleteS3'] == true &&
            response['s3Files'] != null) {
          final List<dynamic> s3Files = response['s3Files'];
          await _deleteS3Paths(s3Files);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(cleanup ? '課程已刪除並清理雲端空間' : '課程已刪除 (保留檔案)')),
          );
          // 導回課程列表頁面
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失敗: ${response['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作發生錯誤: $e')));
      }
    }
  }

  void _showDeleteLessonDialog(dynamic lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '確認刪除章節？',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '您確定要刪除「${lesson['lName'] ?? '此章節'}」嗎？此操作將移除相關影片與檔案。',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLesson(lesson['lId'], cleanup: true);
            },
            child: const Text(
              '確認刪除',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLesson(String lessonId, {bool cleanup = true}) async {
    try {
      final response = await ApiService.deleteLesson(
        lessonId,
        cleanup: cleanup,
      );
      if (response['status'] == 'success') {
        if (cleanup &&
            response['shouldDeleteS3'] == true &&
            response['s3Files'] != null) {
          final List<dynamic> s3Files = response['s3Files'];
          await _deleteS3Paths(s3Files);
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('章節已刪除並清理相關存儲')));
          _loadCourseLessons();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失敗: ${response['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作發生錯誤: $e')));
      }
    }
  }

  void _editLesson(dynamic lesson) {
    _showEditLessonDialog(lesson);
  }

  void _uploadVideo(dynamic lesson) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final memberId = userProvider.currentUser?.memberId ?? 'default';
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoUploadPage(
          memberId: memberId,
          courseId: widget.course.id,
          lessonId: lesson['lId'],
          lessonName: lesson['lName'] ?? '',
        ),
      ),
    );
  }

  Widget _buildCourseIntroHeader() {
    final introImg = _courseDetails['introImg'];
    final introVideo = _courseDetails['introVideo'];
    final hasImg = introImg != null && introImg != '';
    final hasVideo = introVideo != null && introVideo != '';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '課程介紹媒體',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isLoadingCourseDetails)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.purpleAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // 介紹圖片
              Expanded(
                child: _buildMediaPickerCard(
                  title: '介紹圖片',
                  subtitle: hasImg ? '已上傳' : '未設置',
                  icon: Icons.image_outlined,
                  hasMedia: hasImg,
                  onTap: () => _pickAndUploadCourseMedia(isImage: true),
                  onPreview: hasImg
                      ? () => _showMediaPreview(introImg, isImage: true)
                      : null,
                  onDelete: hasImg
                      ? () => _deleteCourseMedia(isImage: true)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // 介紹影片
              Expanded(
                child: _buildMediaPickerCard(
                  title: '介紹影片',
                  subtitle: hasVideo ? '已上傳' : '未設置',
                  icon: Icons.video_library_outlined,
                  hasMedia: hasVideo,
                  onTap: () => _pickAndUploadCourseMedia(isImage: false),
                  onPreview: hasVideo
                      ? () => _showMediaPreview(introVideo, isImage: false)
                      : null,
                  onDelete: hasVideo
                      ? () => _deleteCourseMedia(isImage: false)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPickerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool hasMedia,
    required VoidCallback onTap,
    VoidCallback? onPreview,
    VoidCallback? onDelete,
  }) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasMedia
              ? Colors.purpleAccent.withOpacity(0.5)
              : Colors.grey[800]!,
        ),
      ),
      child: InkWell(
        onTap: hasMedia ? onPreview : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: hasMedia ? Colors.purpleAccent : Colors.grey[600],
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: hasMedia ? Colors.purpleAccent : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (hasMedia)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  onPressed: onDelete,
                ),
              ),
            if (!hasMedia)
              Positioned(
                bottom: 4,
                right: 4,
                child: Icon(
                  Icons.add_circle,
                  color: Colors.purpleAccent.withOpacity(0.8),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadCourseMedia({required bool isImage}) async {
    if (!isImage) {
      // 介紹影片：跳轉至 VideoUploadPage，並提示 5 分鐘限制
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final mId = userProvider.currentUser?.memberId ?? 'Unknown';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('上傳課程介紹影片', style: TextStyle(color: Colors.white)),
          content: const Text(
            '介紹影片將支援 2D 面具、內容審核與自動字幕。\n\n⚠️ 注意：影片時長建議不超過 5 分鐘。',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                '前往上傳',
                style: TextStyle(color: Colors.purpleAccent),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoUploadPage(
              memberId: mId,
              courseId: widget.course.id,
              lessonName: '課程介紹影片 (5分鐘內)',
              isCourseIntro: true,
            ),
          ),
        );
        // 上傳完成後刷新
        _loadCourseDetails();
      }
      return;
    }

    // 介紹圖片：限制 20MB
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final fileSize = await file.length();

      if (fileSize > 20 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('圖片大小不能超過 20MB')));
        }
        return;
      }

      setState(() => _isLoadingCourseDetails = true);

      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final mId = userProvider.currentUser?.memberId ?? 'Unknown';
        final now = DateTime.now();
        final year = now.year.toString();
        final month = now.month.toString().padLeft(2, '0');

        // S3 路徑格式: File/memberId/year/month/intro/fileName
        final objectKey = 'File/$mId/$year/$month/intro/$fileName';

        final s3Url = await AWSService.uploadFileToS3(file, objectKey);

        final response = await ApiService.updateCourseMedia(
          courseId: widget.course.id,
          introImg: s3Url,
        );

        if (response['status'] == 'success') {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('介紹圖片已更新')));
          _loadCourseDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('上傳失敗: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingCourseDetails = false);
        }
      }
    }
  }

  void _showMediaPreview(String url, {required bool isImage}) {
    if (isImage) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  AWSService.getPresignedUrl(url),
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const CircularProgressIndicator(),
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.grey[900],
                    child: const Column(
                      children: [
                        Icon(Icons.broken_image, color: Colors.red, size: 40),
                        SizedBox(height: 8),
                        Text('圖片載入失敗', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(
            videoUrl: AWSService.getPresignedUrl(url),
            lessonTitle: '課程介紹影片',
          ),
        ),
      );
    }
  }

  Future<void> _deleteCourseMedia({required bool isImage}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('刪除介紹${isImage ? '圖片' : '影片'}'),
        content: const Text('確定要刪除此媒體資源嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoadingCourseDetails = true);
      try {
        final mediaUrl = isImage
            ? _courseDetails['introImg']
            : _courseDetails['introVideo'];
        if (mediaUrl != null && mediaUrl != '') {
          // 如果是 S3 路徑或 URL，執行 S3 刪除
          try {
            await AWSService.deleteS3Object(mediaUrl);
          } catch (e) {
            print('S3 媒體刪除失敗: $e');
          }
        }

        final response = await ApiService.updateCourseMedia(
          courseId: widget.course.id,
          introImg: isImage ? '' : null, // 傳送空字串讓 PHP 設為 NULL
          introVideo: isImage ? null : '',
        );

        if (response['status'] == 'success') {
          _loadCourseDetails();
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
      } finally {
        setState(() => _isLoadingCourseDetails = false);
      }
    }
  }

  Future<void> _pickAndUploadFile(dynamic lesson) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final memberId = userProvider.currentUser?.memberId;

    if (memberId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法取得會員ID，請重新登入')));
      return;
    }

    if (!AWSConfig.isConfigured()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AWS 設定不完整')));
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      final fileName = path.basename(filePath);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('正在上傳 $fileName...')));

      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');

      final s3ObjectKey = 'File/$memberId/$year/$month/$fileName';

      await AWSService.uploadFileToS3(file, s3ObjectKey);

      await ApiService.uploadLessonResource(
        lessonId: lesson['lId'],
        resourceName: fileName,
        resourcePath: s3ObjectKey,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上傳成功: $fileName')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('上傳失敗，請稍後再試')));
    }
  }

  void _uploadFiles(dynamic lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('上傳文件', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '為 ${lesson['lName'] ?? '課程'} 上傳文件',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              '文件數量沒有限制',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _pickAndUploadFile(lesson);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
              ),
              child: const Text('選擇文件', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _uploadFileByUrl(lesson);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
              ),
              child: const Text(
                '通過URL上傳',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _uploadFileByUrl(dynamic lesson) {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('通過URL上傳文件', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '為 ${lesson['lName'] ?? '課程'} 通過URL上傳文件',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '文件URL',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purpleAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '文件名稱',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purpleAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '文件URL數量沒有限制',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final url = urlController.text.trim();
              final name = nameController.text.trim();
              final lessonId = lesson['lId'];

              if (url.isEmpty || name.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('請填寫完整的URL和文件名稱')));
                return;
              }

              if (lessonId == null || lessonId.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('課程ID不存在')));
                return;
              }

              // 禁用按鈕避免重複點擊
              // 這裡我們不關閉對話框，而是在後台執行操作

              try {
                print('上傳URL: $url');
                print('課程ID: $lessonId');
                print('資源名稱: $name');

                // 直接調用API
                final result = await ApiService.uploadLessonResourceUrl(
                  lessonId: lessonId,
                  resourceName: name,
                  resourceUrl: url,
                );

                print('上傳成功: $result');

                // 重新加載數據
                await _loadCourseLessons();
                print('課程數據重新加載完成');

                // 關閉當前對話框
                Navigator.pop(context);

                // 顯示成功消息
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text(
                      '成功',
                      style: TextStyle(color: Colors.green),
                    ),
                    content: const Text('文件URL已成功添加'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '確定',
                          style: TextStyle(color: Colors.purpleAccent),
                        ),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                print('上傳失敗: $e');

                // 關閉當前對話框
                Navigator.pop(context);

                // 顯示錯誤消息
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text(
                      '失敗',
                      style: TextStyle(color: Colors.red),
                    ),
                    content: Text('上傳失敗: ${e.toString()}'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '確定',
                          style: TextStyle(color: Colors.purpleAccent),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text(
              '確定',
              style: TextStyle(color: Colors.purpleAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteVideo(dynamic lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('刪除影片', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '確定要刪除 ${lesson['lName'] ?? '課程'} 的影片嗎？',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              '此操作不可撤銷',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);

              try {
                // 1. 調用 API 刪除資料庫記錄 (API 現在會檢查引用)
                final response = await ApiService.deleteLessonVideo(
                  lesson['lId'],
                );

                if (response['status'] == 'success') {
                  // 2. 如果 API 告訴我們需要刪除 S3 影片 (無其他引用)
                  if (response['shouldDeleteS3'] == true) {
                    final videoUrl = response['videoPath'] ?? '';
                    print('準備刪除影片, URL: $videoUrl');

                    if (videoUrl.toString().isNotEmpty) {
                      try {
                        final objectKey = _toS3ObjectKey(videoUrl.toString());
                        if (objectKey.isNotEmpty) {
                          final segments = objectKey.split('/');
                          if (segments.length >= 2) {
                            segments.removeLast(); // 移除影片檔案名，獲取資料夾
                            final folderPath = segments.join('/');
                            print('正在刪除 S3 資料夾: $folderPath (無其他引用)');
                            await AWSService.deleteS3Folder(folderPath);
                            print('S3 資料夾刪除成功');
                          }
                        }
                      } catch (e) {
                        print('S3 刪除異常 (影片資料夾): $e');
                      }
                    }
                  } else {
                    print('S3 影片資料夾保留 (仍有其他引用)');
                  }

                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('影片已刪除')),
                  );

                  if (mounted) {
                    setState(() {
                      final index = _lessons.indexWhere(
                        (l) => l['lId'] == lesson['lId'],
                      );
                      if (index != -1) {
                        _lessons[index]['video'] = null;
                      }
                    });
                    _loadCourseLessons();
                  }
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('資料庫刪除失敗: ${response['message']}')),
                  );
                }
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('刪除失敗: ${e.toString()}')),
                );
              }
            },
            child: const Text('確定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteFiles(dynamic lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('刪除文件', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '確定要刪除 ${lesson['lName'] ?? '課程'} 的所有文件嗎？',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              '此操作不可撤銷',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              // 調用API刪除文件
              Navigator.pop(context);
              try {
                final response = await ApiService.deleteLessonFiles(
                  lesson['lId'],
                );
                if (response['status'] == 'success') {
                  // 如果 API 告訴我們需要刪除 S3 文件
                  if (response['shouldDeleteS3'] == true &&
                      response['s3Files'] != null) {
                    final List<dynamic> s3Files = response['s3Files'];
                    await _deleteS3Paths(s3Files);
                  }

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('文件已刪除')));
                  setState(() {
                    final index = _lessons.indexWhere(
                      (l) => l['lId'] == lesson['lId'],
                    );
                    if (index != -1) {
                      _lessons[index]['files'] = [];
                    }
                  });
                  _loadCourseLessons();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('刪除失敗: ${response['message']}')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('刪除失敗: ${e.toString()}')),
                );
              }
            },
            child: const Text('確定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    return StatefulBuilder(
      builder: (context, setListState) {
        return FutureBuilder(
          future: ApiService.getCourseStudents(widget.course.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.purpleAccent),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data['status'] != 'success') {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '加載學生列表失敗',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                      ),
                      child: const Text('重新加載'),
                    ),
                  ],
                ),
              );
            }

            final List students = snapshot.data['students'] ?? [];

            if (students.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      color: Colors.grey[700],
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暫無學生購買此課程',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: _buildStudentAvatar(student),
                    title: Text(
                      student['username'] ?? '未知學生',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: Colors.grey[500],
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              student['email'] ?? '無郵箱',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              color: Colors.grey[500],
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '購買於 ${student['purchaseDate']?.toString().split(' ')[0] ?? '未知'}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white24,
                    ),
                    onTap: () => _showStudentDetailDialog(student['mId']),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showStudentDetailDialog(String mId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: FutureBuilder(
            future: ApiService.getStudentDetail(
              courseId: widget.course.id,
              memberId: mId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.purpleAccent),
                );
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data['status'] != 'success') {
                return const Center(
                  child: Text(
                    '加載學生詳情失敗',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              final data = snapshot.data;
              final student = data['student'];
              final lessons = data['lessons'] as List;
              final completedCount = lessons
                  .where((l) => l['completed'] == true)
                  .length;
              final progress = lessons.isEmpty
                  ? 0.0
                  : completedCount / lessons.length;

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  // 頂部把手
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 學生基本資料
                  Row(
                    children: [
                      _buildStudentAvatar(student),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['username'] ?? '未知學生',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '會員 ID: ${student['mId']}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 進度概覽
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.purpleAccent.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '課程總體進度',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.purpleAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[800],
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.purpleAccent,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '已完成 $completedCount / ${lessons.length} 個章節',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 聯絡資訊
                  const Text(
                    '基本資料',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailItem(
                    Icons.email_outlined,
                    '電子郵件',
                    student['email'] ?? '未提供',
                  ),
                  _buildDetailItem(
                    Icons.phone_outlined,
                    '聯絡電話',
                    student['tel']?.toString() ?? '未提供',
                  ),
                  _buildDetailItem(
                    Icons.star_outline,
                    '學生評分',
                    student['rating']?.toString() ?? '未評價',
                  ),
                  if (student['comment'] != null)
                    _buildDetailItem(
                      Icons.comment_outlined,
                      '學生評價',
                      student['comment'],
                    ),

                  const SizedBox(height: 32),

                  // 每堂課詳細資料
                  const Text(
                    '章節學習記錄',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...lessons
                      .map(
                        (lesson) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: lesson['completed']
                                      ? Colors.greenAccent.withOpacity(0.1)
                                      : Colors.grey[800],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  lesson['completed']
                                      ? Icons.check
                                      : Icons.access_time,
                                  color: lesson['completed']
                                      ? Colors.greenAccent
                                      : Colors.grey[500],
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '第 ${lesson['orderNum']} 課：${lesson['lName']}',
                                      style: TextStyle(
                                        color: lesson['completed']
                                            ? Colors.white
                                            : Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (lesson['completed'])
                                      Text(
                                        '完成於：${lesson['completionDate']}',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.purpleAccent.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStudentProgress(String studentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('學生學習進度', style: TextStyle(color: Colors.white)),
        content: FutureBuilder(
          future: ApiService.getStudentCourseProgress(
            studentId: studentId,
            courseId: widget.course.id,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.purpleAccent),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data['status'] != 'success') {
              return const Center(
                child: Text(
                  '加載學習進度失敗',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              );
            }

            final progress = snapshot.data['progress'] ?? {};
            final lessons = snapshot.data['lessons'] ?? [];

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('總課時數', style: TextStyle(color: Colors.grey)),
                    Text(
                      '${progress['totalLessons'] ?? 0}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('已完成課時', style: TextStyle(color: Colors.grey)),
                    Text(
                      '${progress['completedLessons'] ?? 0}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('學習進度', style: TextStyle(color: Colors.grey)),
                    Text(
                      '${progress['percentage'] ?? 0}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  '課時學習狀態',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                for (var lesson in lessons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          lesson['completed'] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: lesson['completed'] == true
                              ? Colors.green
                              : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lesson['lName'] ?? '未命名課時',
                            style: TextStyle(
                              color: lesson['completed'] == true
                                  ? Colors.white
                                  : Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (lesson['completed'] == true)
                          Text(
                            '${lesson['firstLesson']?.split(' ')[0] ?? ''}',
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseSettings() {
    String _langLabelFromId(String? id) {
      switch (id) {
        case 'Lg000002':
          return '粵語';
        case 'Lg000003':
          return '普通話';
        case 'Lg000001':
          return '英文';
        default:
          return '粵語';
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. 基本資訊分組
        _buildSettingsGroup('基本資訊', [
          _buildSettingItem(
            '課程標題',
            _courseDetails['cName'] ?? widget.course.title,
            Icons.title,
            () => _editSetting(
              '課程標題',
              _courseDetails['cName'] ?? widget.course.title,
            ),
          ),
          _buildSettingItem(
            '課程分類',
            _courseDetails['subject'] ?? widget.course.subject,
            Icons.category_outlined,
            () => _editSetting(
              '課程分類',
              _courseDetails['subject'] ?? widget.course.subject,
            ),
          ),
          _buildSettingItem(
            '課程語言',
            _langLabelFromId(_courseDetails['langId']?.toString()),
            Icons.language,
            () => _editSetting(
              '課程語言',
              _langLabelFromId(_courseDetails['langId']?.toString()),
            ),
          ),
          _buildSettingItem(
            '課程簡介',
            _courseDetails['summary'] ?? widget.course.description,
            Icons.description_outlined,
            () => _editSetting(
              '課程簡介',
              _courseDetails['summary'] ?? widget.course.description,
            ),
          ),
        ]),

        const SizedBox(height: 24),

        // 2. 銷售資訊分組
        _buildSettingsGroup('銷售與權限', [
          _buildSettingItem(
            '課程價格',
            '積分 ${_courseDetails['unitPrice'] ?? 0}',
            Icons.payments_outlined,
            () => _editSetting('課程價格', '${_courseDetails['unitPrice'] ?? 0}'),
          ),
          _buildSettingItem(
            '課程時長 (小時)',
            '${_courseDetails['totalLesson'] ?? 0}',
            Icons.access_time,
            () => _editSetting('課程時長', '${_courseDetails['totalLesson'] ?? 0}'),
          ),
        ]),

        const SizedBox(height: 32),

        // 3. 危險操作
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: TextButton.icon(
            onPressed: _showDeleteCourseDialog,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text(
              '刪除課程',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 刷新按鈕
        Center(
          child: TextButton.icon(
            onPressed: _loadCourseDetails,
            icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
            label: const Text(
              '同步雲端數據',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        icon,
        color: Colors.purpleAccent.withOpacity(0.7),
        size: 22,
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.edit_note, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  void _editSetting(String settingName, String currentValue) {
    if (settingName == '課程分類') {
      _editCategorySetting(currentValue);
      return;
    }
    if (settingName == '課程語言') {
      _editLanguageSetting(currentValue);
      return;
    }

    TextEditingController controller = TextEditingController(
      text: currentValue,
    );
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(
              '編輯 $settingName',
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: '新值',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purpleAccent),
                    ),
                  ),
                  keyboardType: settingName == '課程價格'
                      ? TextInputType.number
                      : TextInputType.text,
                  maxLines: settingName == '課程簡介' ? 3 : 1,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        String newValue = controller.text.trim();
                        if (newValue.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請填寫新值')),
                          );
                          return;
                        }

                        setState(() {
                          isLoading = true;
                        });

                        try {
                          Map<String, dynamic> updateData = {
                            'cId': widget.course.id,
                          };

                          switch (settingName) {
                            case '課程標題':
                              updateData['cName'] = newValue;
                              break;
                            case '課程簡介':
                              updateData['cDescription'] = newValue;
                              break;
                            case '課程價格':
                              updateData['unitPrice'] = double.parse(newValue);
                              break;
                            case '課程時長':
                              updateData['totalLesson'] = int.parse(newValue);
                              break;
                            case '課程分類':
                              updateData['subject'] = newValue;
                              break;
                          }

                          final response = await ApiService.updateCourse(
                            courseId: widget.course.id,
                            courseName: updateData['cName'],
                            unitPrice: updateData['unitPrice'],
                            description: updateData['cDescription'],
                            totalLesson: updateData['totalLesson'],
                            subject: updateData['subject'],
                          );

                          if (response['status'] == 'success') {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$settingName 已更新')),
                            );
                            // 更新成功后重新加载课程详情，以显示最新数据
                            _loadCourseDetails();
                          } else {
                            throw Exception(response['message'] ?? '更新失敗');
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('更新失敗: ${e.toString()}')),
                          );
                        } finally {
                          setState(() {
                            isLoading = false;
                          });
                        }
                      },
                child: isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.purpleAccent,
                        strokeWidth: 2,
                      )
                    : const Text(
                        '確定',
                        style: TextStyle(color: Colors.purpleAccent),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentAvatar(dynamic student) {
    final avatar = (student is Map ? student['avatar'] : null)?.toString();
    final username = (student is Map ? student['username'] : null)?.toString();
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.purpleAccent.withOpacity(0.1),
      child: ClipOval(
        child: Image.network(
          UserApiService.getFullImageUrl(avatar),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Text(
              (username?.isNotEmpty == true ? username![0] : '?').toUpperCase(),
              style: const TextStyle(
                color: Colors.purpleAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _editCategorySetting(String currentValue) {
    bool isLoading = false;
    String? selected = currentValue;
    final Future<Map<String, dynamic>> categoriesFuture =
        ApiService.getCategories();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return FutureBuilder<Map<String, dynamic>>(
            future: categoriesFuture,
            builder: (context, snapshot) {
              final categories =
                  (snapshot.data?['categories'] as List?)?.cast<dynamic>() ??
                  [];
              if (selected == null || selected!.isEmpty) {
                selected =
                    categories
                        .map((c) => c['cateNameTC']?.toString())
                        .firstWhere(
                          (name) => name == currentValue,
                          orElse: () => null,
                        ) ??
                    categories
                        .map((c) => c['cateNameTC']?.toString())
                        .firstWhere(
                          (name) => name != null && name.isNotEmpty,
                          orElse: () => currentValue,
                        );
              }

              return AlertDialog(
                backgroundColor: Colors.grey[900],
                title: const Text(
                  '編輯 課程分類',
                  style: TextStyle(color: Colors.white),
                ),
                content: snapshot.connectionState == ConnectionState.waiting
                    ? const SizedBox(
                        height: 80,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.purpleAccent,
                          ),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: selected,
                        dropdownColor: Colors.grey[900],
                        decoration: const InputDecoration(
                          labelText: '分類',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.purpleAccent),
                          ),
                        ),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['cateNameTC']?.toString() ?? '',
                                child: Text(
                                  c['cateNameTC']?.toString() ?? '',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                            .where(
                              (i) => i.value != null && i.value!.isNotEmpty,
                            )
                            .toList(),
                        onChanged: isLoading
                            ? null
                            : (v) => setState(() => selected = v),
                      ),
                actions: [
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        (isLoading ||
                            selected == null ||
                            selected!.trim().isEmpty)
                        ? null
                        : () async {
                            setState(() => isLoading = true);
                            try {
                              final response = await ApiService.updateCourse(
                                courseId: widget.course.id,
                                subject: selected,
                              );
                              if (response['status'] == 'success') {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('課程分類 已更新')),
                                );
                                _loadCourseDetails();
                              } else {
                                throw Exception(response['message'] ?? '更新失敗');
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('更新失敗: ${e.toString()}'),
                                ),
                              );
                            } finally {
                              setState(() => isLoading = false);
                            }
                          },
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.purpleAccent,
                            strokeWidth: 2,
                          )
                        : const Text(
                            '確定',
                            style: TextStyle(color: Colors.purpleAccent),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _editLanguageSetting(String currentValue) {
    bool isLoading = false;
    String selected = currentValue;

    String toLangId(String label) {
      switch (label) {
        case '粵語':
          return 'Lg000002';
        case '普通話':
          return 'Lg000003';
        case '英文':
          return 'Lg000001';
        default:
          return 'Lg000002';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('編輯 課程語言', style: TextStyle(color: Colors.white)),
            content: DropdownButtonFormField<String>(
              value: selected,
              dropdownColor: Colors.grey[900],
              decoration: const InputDecoration(
                labelText: '語言',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purpleAccent),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: '粵語',
                  child: Text('粵語', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: '普通話',
                  child: Text('普通話', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: '英文',
                  child: Text('英文', style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: isLoading
                  ? null
                  : (v) => setState(() => selected = v ?? selected),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);
                        try {
                          final response = await ApiService.updateCourse(
                            courseId: widget.course.id,
                            langId: toLangId(selected),
                          );
                          if (response['status'] == 'success') {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('課程語言 已更新')),
                            );
                            _loadCourseDetails();
                          } else {
                            throw Exception(response['message'] ?? '更新失敗');
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('更新失敗: ${e.toString()}')),
                          );
                        } finally {
                          setState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.purpleAccent,
                        strokeWidth: 2,
                      )
                    : const Text(
                        '確定',
                        style: TextStyle(color: Colors.purpleAccent),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
