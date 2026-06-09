import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SearchService {
  static const String _historyKey = 'search_history';
  static const int _maxHistory = 10;
  static const String baseUrl = 'http://3.25.85.107/mysqlconnect';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ─── 搜尋歷史 ───

  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  static Future<List<String>> addHistory(String query) async {
    if (query.trim().isEmpty) return await getHistory();
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    history.removeWhere((h) => h.toLowerCase() == query.toLowerCase());
    history.insert(0, query.trim());
    if (history.length > _maxHistory) {
      history = history.sublist(0, _maxHistory);
    }
    await prefs.setStringList(_historyKey, history);
    return history;
  }

  static Future<List<String>> removeHistory(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    if (index >= 0 && index < history.length) {
      history.removeAt(index);
      await prefs.setStringList(_historyKey, history);
    }
    return history;
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // ─── 熱門搜尋 ───

  static Future<List<String>> getPopularSearches() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/search_popular.php'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final List<dynamic> data = json.decode(response.body);
        final keywords = data
            .map<String>((item) => item['keyword']?.toString() ?? '')
            .where((k) => k.isNotEmpty)
            .toList();
        return keywords.isNotEmpty ? keywords : _fallbackPopular;
      }
      return _fallbackPopular;
    } catch (_) {
      return _fallbackPopular;
    }
  }

  // ─── 課程搜尋（關鍵字）───

  static Future<List<dynamic>> searchCourses(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$baseUrl/search_course.php').replace(
        queryParameters: {'search': query.trim()},
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data is List) return data;
      }
      return [];
    } catch (e) {
      throw Exception('搜尋課程失敗: $e');
    }
  }

  // ─── 按老師 mId 取得課程（新增）───
  // 搜尋到老師後，用此方法取得他們教的所有課程
  // mIds：老師的 mId 列表（可傳多個）

  static Future<List<dynamic>> searchCoursesByMIds(List<String> mIds) async {
    if (mIds.isEmpty) return [];
    try {
      final uri = Uri.parse('$baseUrl/search_course.php').replace(
        queryParameters: {'mId': mIds.join(',')},
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data is List) return data;
      }
      return [];
    } catch (e) {
      throw Exception('取得老師課程失敗: $e');
    }
  }

  // ─── 老師搜尋 ───

  static Future<List<dynamic>> searchTeachers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$baseUrl/search_teacher.php').replace(
        queryParameters: {'search': query.trim()},
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data is List) return data;
      }
      return [];
    } catch (e) {
      throw Exception('搜尋老師失敗: $e');
    }
  }

  // ─── 取得所有類別 ───

  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/search_category.php'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data is List) {
          return data
              .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─── 按類別搜尋課程 ───

  static Future<List<dynamic>> searchByCategory(String category) async {
    if (category.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$baseUrl/search_category.php').replace(
        queryParameters: {'category': category.trim()},
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data is List) return data;
      }
      return [];
    } catch (e) {
      throw Exception('按類別搜尋失敗: $e');
    }
  }

  // ─── 記錄課程被搜尋次數 ───

  static Future<void> recordCourseSearch(String cId) async {
    if (cId.trim().isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('$baseUrl/search_popular.php'),
            headers: _headers,
            body: json.encode({'cId': cId.trim()}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static const List<String> _fallbackPopular = [
    'AI 人工智能',
    'ChatGPT 應用',
    '數據科學',
    '手機App開發',
    '深度學習',
    '區塊鏈技術',
    '雲端計算',
    '大數據分析',
    '物聯網 IoT',
    '網絡安全',
  ];
}