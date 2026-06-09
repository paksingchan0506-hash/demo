import 'dart:convert';
import 'package:http/http.dart' as http;

class RankApiService {
  // 基礎路徑
  static const String baseUrl = 'http://3.25.85.107/mysqlconnect';
  
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // 獲取排行榜數據 (GET)
  static Future<Map<String, dynamic>> getHomeRankings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_home_ranks.php'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Rank API 調用失敗: $e');
    }
  }
}