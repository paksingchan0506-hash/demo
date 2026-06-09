import 'package:flutter/material.dart';
import 'mini_games_page.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user.dart'; // 確保導入 PointRecord 定義
import 'points_check_in_page.dart';
import 'purchase_page.dart';

class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  @override
  void initState() {
    super.initState();
    // 進入頁面同步資料庫積分
    Future.microtask(() {
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).syncPointsWithDb();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('積分與獎勵'),
        backgroundColor: Colors.grey[800],
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. 積分總覽卡片 (傳入 userProvider)
          _buildPointsOverviewCard(userProvider),
          const SizedBox(height: 20),
          
          // 2. 功能選項
          _buildFunctionCard(
            '小遊戲',
            '玩遊戲賺取積分',
            Icons.casino,
            Colors.orange,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MiniGamesPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          
          _buildFunctionCard(
            '每日簽到',
            '連續簽到獲得額外獎勵',
            Icons.calendar_today,
            Colors.green,
            () {
              // 導向簽到頁面
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PointsCheckInPage()),
              );
            },
          ),
          const SizedBox(height: 12),

          
        _buildFunctionCard(
          '積分儲值',
          '獲取更多積分以兌換獎勵',
          Icons.add_shopping_cart,
          Colors.amber,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PurchasePage()),
            );
          },
        ),
          
          const SizedBox(height: 20),
          
          // 3. 積分紀錄列表 (由 Provider 提供數據)
          _buildPointsHistory(userProvider),
        ],
      ),
    );
  }

  // 積分總覽卡片
  Widget _buildPointsOverviewCard(UserProvider userProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[800]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '當前積分',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '${userProvider.currentUser?.points ?? 0}',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              
              // 修改這裡：傳入動態計算的連續天數
              _buildStatItem(
                '連續簽到', 
                '${userProvider.continuousCheckInDays}天', 
                Icons.star
              ),

            ],
          ),
        ],
      ),
    );
  }

  String _calculateWeeklyPoints(UserProvider userProvider) {
    if (userProvider.currentUser == null) return '0';
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStartStr = startOfWeek.toString().substring(0, 10);
    
    int total = 0;
    for (var record in userProvider.currentUser!.pointsHistory) {
      if (record.amount > 0 && record.date.compareTo(weekStartStr) >= 0) {
        total += record.amount;
      }
    }
    return total.toString();
  }

  String _calculateLevel(int points) {
    if (points >= 5000) return 'Lv.5';
    if (points >= 2000) return 'Lv.4';
    if (points >= 1000) return 'Lv.3';
    if (points >= 500) return 'Lv.2';
    return 'Lv.1';
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildFunctionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      color: Colors.grey[800],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[400]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
        onTap: onTap,
      ),
    );
  }

  // 積分紀錄部分
  Widget _buildPointsHistory(UserProvider userProvider) {
    // 從 User 模型中取得 pointsHistory 清單
    final List<PointRecord> history = userProvider.currentUser?.pointsHistory ?? [];
    final List<PointRecord> latest10 =
        history.length > 10 ? history.take(10).toList() : history;

    return Card(
      color: Colors.grey[800],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近積分記錄',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('暫無積分紀錄', style: TextStyle(color: Colors.grey))),
              )
            else
              // 遍歷紀錄列表並生成 UI
              ...latest10.map((record) {
                final isPositive = record.amount >= 0;
                return _buildHistoryItem(
                  record.title,
                  isPositive ? '+${record.amount}' : '${record.amount}',
                  record.date,
                  isPositive ? Colors.green : Colors.red,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String points, String date, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 根據正負顯示圖標
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 16,
            child: Icon(
              points.startsWith('+') ? Icons.add : Icons.remove,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                Text(
                  date,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
