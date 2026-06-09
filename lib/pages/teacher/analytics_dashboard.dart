import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/user_provider.dart';

class AnalyticsDashboard extends StatefulWidget {
  final String title;
  const AnalyticsDashboard({super.key, required this.title});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<dynamic> _revenueTrend = [];
  Map<String, dynamic> _performance = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final mId = userProvider.currentUser?.memberId ?? '';

      if (mId.isEmpty) {
        throw Exception('無法獲取會員資訊');
      }

      final response = await ApiService.getTeacherOverallStats(mId);
      if (response['status'] == 'success') {
        if (!mounted) return;
        setState(() {
          _stats = response['stats'] ?? {};
          _revenueTrend = response['revenueTrend'] ?? [];
          _performance = response['performance'] ?? {};
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? '加載數據失敗');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 18)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.purpleAccent),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadStats,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                    ),
                    child: const Text('重試'),
                  ),
                ],
              ),
            )
          : _buildDataView(),
    );
  }

  Widget _buildDataView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 數據概覽卡片
          _buildStatGrid(),
          const SizedBox(height: 24),

          // 趨勢圖表
          const Text(
            '累計總收入趨勢',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildChartCard(),

          const SizedBox(height: 24),

          // 表現排行
          const Text(
            '課程表現概覽',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildRankingList(),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    final totalIncome = _stats['totalIncome'] ?? 0;
    final totalStudents = _stats['totalStudents'] ?? 0;
    final totalBookmarks = _stats['totalBookmarks'] ?? 0;
    final totalCourses = _stats['totalCourses'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          '總收入',
          '積分 ${(totalIncome as num).toStringAsFixed(0)}',
          Icons.payments,
          Colors.greenAccent,
        ),
        _buildStatCard(
          '學生總數',
          '$totalStudents',
          Icons.people,
          Colors.blueAccent,
        ),
        _buildStatCard(
          '總收藏數',
          '$totalBookmarks',
          Icons.bookmark,
          Colors.amberAccent,
        ),
        _buildStatCard(
          '課程總數',
          '$totalCourses',
          Icons.book,
          Colors.orangeAccent,
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    if (_revenueTrend.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('暫無趨勢數據', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // 計算數據範圍
    final values = _revenueTrend
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
      height: 240,
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
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
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  // 避免在最頂部或最底部顯示標籤，以免重疊
                  if (value == meta.min || value == meta.max)
                    return const SizedBox();
                  return Text(
                    value >= 1000
                        ? '${(value / 1000).toStringAsFixed(1)}k'
                        : value.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < _revenueTrend.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _revenueTrend[idx]['date'],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _revenueTrend.asMap().entries.map((e) {
                return FlSpot(
                  e.key.toDouble(),
                  (e.value['value'] as num).toDouble(),
                );
              }).toList(),
              isCurved: true,
              color: Colors.purpleAccent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.purpleAccent.withOpacity(0.2),
                    Colors.purpleAccent.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingList() {
    final best = _performance['best'];
    final needsOpt = _performance['needsOptimization'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (best != null)
            _buildRankItem(
              '最高收入',
              best['name'] ?? '未知課程',
              '積分 ${best['value'] ?? 0}',
              Colors.greenAccent,
            ),
          if (best != null && needsOpt != null)
            const Divider(color: Colors.white10, height: 1),
          if (needsOpt != null)
            _buildRankItem(
              '需優化',
              needsOpt['name'] ?? '未知課程',
              needsOpt['value'] ?? '評分低',
              Colors.redAccent,
            ),
          if (best == null && needsOpt == null)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('暫無表現數據', style: TextStyle(color: Colors.grey)),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankItem(String tag, String name, String value, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        value,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
