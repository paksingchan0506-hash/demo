import 'package:flutter/material.dart';

class CourseProvider with ChangeNotifier {
  // 1. 收藏清單
  final List<String> _bookmarkedTitles = [];
  
  // 2. 購買紀錄 (整課或單集)
  final List<Map<String, dynamic>> _purchasedItems = [];

  // 3. 轉發數據
  final Map<String, int> _shareCounts = {};

  final Map<String, Map<String, List<double>>> _analyticsData = {
    'Flutter 進階開發': {
      '收入': [1200, 1500, 800, 2200], // 模擬：今日, 本週, 本月, 累計
      '收藏': [5, 20, 45, 120],
      '收看': [50, 200, 450, 1500],
      '轉發': [2, 10, 25, 80],
    },
  };

  // 獲取特定課程或全局的數據
  List<double> getData(String courseTitle, String type) {
    // 如果傳入 'Total'，就加總所有課程
    if (courseTitle == 'Total') {
      // 這裡簡單回傳一組模擬的總數
      return [5000, 15000, 45000, 120000];
    }
    return _analyticsData[courseTitle]?[type] ?? [0, 0, 0, 0];
  }

  // --- Getters ---
  List<String> get bookmarkedTitles => _bookmarkedTitles;
  List<Map<String, dynamic>> get purchasedItems => _purchasedItems;
  // 相容舊代碼的別名
  List<Map<String, dynamic>> get purchasedOrders => _purchasedItems;

  // --- 核心方法 ---

  // 檢查是否已購 (支援檢查整課或特定單集)
  bool isPurchased(String courseTitle, {String? episodeTitle}) {
    bool hasFullCourse = _purchasedItems.any((item) => item['title'] == courseTitle && item['episode'] == null);
    if (hasFullCourse) return true;
    if (episodeTitle != null) {
      return _purchasedItems.any((item) => item['title'] == courseTitle && item['episode'] == episodeTitle);
    }
    return false;
  }

  // 收藏相關
  bool isInWishlist(String title) => _bookmarkedTitles.contains(title);
  bool isBookmarked(String title) => _bookmarkedTitles.contains(title);

  void toggleBookmark(String title) {
    if (_bookmarkedTitles.contains(title)) {
      _bookmarkedTitles.remove(title);
    } else {
      _bookmarkedTitles.add(title);
    }
    notifyListeners();
  }

  // 購買功能
  void addOrder({required String title, String? episode, required String price}) {
    _purchasedItems.add({
      'title': title,
      'episode': episode,
      'price': price,
      'date': DateTime.now().toString().split(' ')[0],
    });
    _bookmarkedTitles.remove(title); // 買了就從收藏移出
    notifyListeners();
  }

  // 模擬收據發送 (修正 payment_page 的紅字)
  Future<void> sendMockReceipt(String email, String title, double amount) async {
    await Future.delayed(const Duration(seconds: 1));
    print('收據已發送至 $email');
  }

  // --- 社交功能 (修正 course_page 的紅字) ---
  
  // 增加分享次數
  void incrementShare(String title) {
    _shareCounts[title] = (_shareCounts[title] ?? 0) + 1;
    notifyListeners();
  }

  // 獲取分享次數
  int getShareCount(String title) => _shareCounts[title] ?? 0;
}