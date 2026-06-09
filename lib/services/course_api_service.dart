import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../services/aws_service.dart';

class CourseApiService {
  // 基礎路徑
  static const String baseUrl = 'http://3.25.85.107/mysqlconnect';
  // 指定對接檔案
  static const String endpoint = 'course.php';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // 1. 獲取課程列表 (GET)
  static Future<List<dynamic>> getAllCourses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/course.php'),
        // 建議在開發階段先不傳自定義 headers 以排除 CORS 變數
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('狀態碼: ${response.statusCode}');
    } catch (e) {
      debugPrint('API 錯誤: $e');
      throw Exception('API 錯誤: $e');
    }
  }

  // 確保 getCourseDetail 只有一個，不要重複定義
  static Future<Map<String, dynamic>> getCourseDetail(
    String cId, {
    String? mId,
  }) async {
    try {
      final query = (mId != null && mId.trim().isNotEmpty) ? '&mId=$mId' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/course.php?cId=$cId$query'),
        headers: _headers,
      );
      return json.decode(response.body);
    } catch (e) {
      throw Exception('詳情 API 錯誤: $e');
    }
  }

  // 2. 新增課程 (POST)
  static Future<dynamic> addCourse(Map<String, dynamic> courseData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: _headers,
        body: json.encode(courseData),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('新增課程失敗: $e');
    }
  }

  // 3. 刪除課程 (DELETE)
  static Future<dynamic> deleteCourse(String cId) async {
    try {
      // 根據 Course.php 的邏輯，使用 Query Parameter
      final response = await http.delete(
        Uri.parse('$baseUrl/$endpoint?cId=$cId'),
        headers: _headers,
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('刪除課程失敗: $e');
    }
  }

  // 統一回傳處理
  static dynamic _handleResponse(http.Response response) {
    if (response.body.isEmpty) return null;
    final data = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? '伺服器異常');
    }
  }

  // 獲取課時清單
  static Future<List<dynamic>> getLessonsByCourseId(
    String cId,
    String mId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lesson.php?cId=$cId&mId=$mId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('無法獲取課時');
    } catch (e) {
      throw Exception('API 錯誤: $e');
    }
  }

  // 在 CourseApiService 類別內加入
  // 獲取導師詳細資料及其課程列表
  static Future<Map<String, dynamic>> getMentorDetail(String mId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mentor_detail.php?mId=$mId'),
        headers: _headers,
      );
      return json.decode(response.body);
    } catch (e) {
      throw Exception('導師 API 錯誤: $e');
    }
  }

  static Future<void> updateBookmarkCount(String cId, bool isAdding) async {
    final action = isAdding ? 'add' : 'remove';
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/update_bookmark.php?cId=$cId&action=$action'),
      );
      if (response.statusCode != 200) {
        throw Exception('更新失敗');
      }
    } catch (e) {
      debugPrint('Bookmark API Error: $e');
    }
  }

  static Future<Map<String, dynamic>> toggleCourseBookmark({
    required String mId,
    required String cId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/course_bookmark.php'),
      headers: _headers,
      body: json.encode({"action": "toggle", "mId": mId, "cId": cId}),
    );
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<bool> isCourseBookmarked({
    required String mId,
    required String cId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/course_bookmark.php?action=is_bookmarked&mId=$mId&cId=$cId',
      ),
      headers: _headers,
    );
    final data = json.decode(response.body);
    if (data is Map && data['success'] == true) {
      return data['bookmarked'] == true;
    }
    return false;
  }

  static Future<Map<String, dynamic>> listCourseBookmarks({
    required String mId,
    required int page,
    int pageSize = 10,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/course_bookmark.php?action=list&mId=$mId&page=$page&pageSize=$pageSize',
      ),
      headers: _headers,
    );
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getReportReasons({
    required String type,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/report.php?action=reasons&type=$type'),
      headers: _headers,
    );
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> submitReport({
    required String reporterId,
    required String reportType,
    required String reasonId,
    String? courseId,
    String? commentId,
    String? description,
    String? customReason,
  }) async {
    final payload = <String, dynamic>{
      "action": "submit",
      "reporterId": reporterId,
      "reportType": reportType,
      "reasonId": reasonId,
      "description": description ?? '',
    };
    if (customReason != null) payload["customReason"] = customReason;
    if (courseId != null) payload["courseId"] = courseId;
    if (commentId != null) payload["commentId"] = commentId;

    final response = await http.post(
      Uri.parse('$baseUrl/report.php'),
      headers: _headers,
      body: json.encode(payload),
    );
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getMyCourses(String mId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/my_courses.php?mId=$mId'),
      headers: _headers,
    );
    final data = json.decode(response.body);
    if (data is Map && data['success'] == true) {
      final items = data['items'];
      if (items is List) return items;
    }
    return [];
  }

  static Future<List<dynamic>> getCategories() async {
    final response = await http.get(
      Uri.parse('$baseUrl/category_list.php'),
      headers: _headers,
    );
    final data = json.decode(response.body);
    if (data is Map && data['success'] == true) {
      final items = data['items'];
      if (items is List) return items;
    }
    return [];
  }

  static Future<Map<String, dynamic>> isTutorBookmarked({
    required String mId,
    required String tutorId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tutor_bookmark.php?action=is_bookmarked&mId=$mId&tutorId=$tutorId',
      ),
      headers: _headers,
    );
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> toggleTutorBookmark({
    required String mId,
    required String tutorId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tutor_bookmark.php'),
      headers: _headers,
      body: json.encode({"action": "toggle", "mId": mId, "tutorId": tutorId}),
    );
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> listTutorBookmarks({
    required String mId,
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tutor_bookmark.php?action=list&mId=$mId&page=$page&pageSize=$pageSize',
      ),
      headers: _headers,
    );
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getCourseReviews(
    String cId, {
    String? mId,
  }) async {
    try {
      // 如果有 mId，則帶在 URL 中讓 PHP 知道是誰在查詢
      String url = '$baseUrl/review.php?cId=$cId';
      if (mId != null && mId.isNotEmpty) {
        url += '&mId=$mId';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 確保回傳格式正確，如果是 List (舊版) 則包裝成新版格式
        if (data is List) {
          return {"reviews": data, "userRating": 0};
        }
        return data;
      }
      return {"reviews": [], "userRating": 0};
    } catch (e) {
      debugPrint('評論 API 錯誤: $e');
      return {"reviews": [], "userRating": 0};
    }
  }

  // 2. 新增：提交評論方法 (這個就是你報錯找不到的方法)
  static Future<Map<String, dynamic>> submitReview(
    String mId,
    String cId,
    String comment, {
    int? rating,
    String action = 'comment',
  }) async {
    // 預設 action 為 comment
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/review.php'),
        headers: _headers,
        body: json.encode({
          'mId': mId,
          'cId': cId,
          'comment': comment,
          'rating': rating, // 傳送分數
          'action': action, // 傳送動作類型 (rating 或 comment)
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        return {"status": "error", "message": data['message'] ?? '提交失敗'};
      }
    } catch (e) {
      return {"status": "error", "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getMessages(String mId) async {
    try {
      // 注意：確保檔名是 message.php 還是 messages.php (多一個 s)
      // 剛才報 Fatal error 的檔案是 message.php
      final response = await http.get(
        Uri.parse('$baseUrl/message.php?mId=$mId'),
        // 暫時不要傳送自訂 headers 試試看
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load messages');
    } catch (e) {
      debugPrint('通知 API 錯誤: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateRating(
    String mId,
    String lId,
    int rating,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_rating.php'),
        headers: _headers,
        body: json.encode({
          'mId': mId,
          'lId': lId, // 針對該課時評分
          'rating': rating,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      throw Exception('評分失敗: $e');
    }
  }

  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) {
      return AWSService.getPresignedUrl(
        'default/defaultCoursePicture/EDULogo.jpg',
      );
    }
    if (path.startsWith('http')) return path;

    // 如果是 Amazon S3 路徑，進行安全簽名
    if (path.startsWith('File/')) {
      return AWSService.getPresignedUrl(path);
    }

    return '$baseUrl/$path';
  }

}
