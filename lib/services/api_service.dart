import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://3.25.85.107/mysqlconnect',
  );
  static String mysqlconnect = 'login_app.php';

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static dynamic _handleResponse(http.Response response) {
    try {
      final responseBody = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        final errorMsg =
            responseBody['message'] ??
            'Request failed with status: ${response.statusCode}';
        throw ApiException(errorMsg, response.statusCode);
      }
    } catch (e) {
      throw ApiException(
        'Failed to parse response: ${response.body} (Status: ${response.statusCode})',
      );
    }
  }

  // ── 認證 ──────────────────────────────────────────────────

  static Future<dynamic> registerUser({
    required String email,
    required String password,
    required String name,
    required String userType,
    String? phone,
    String? address,
    String? langId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$mysqlconnect'),
        headers: defaultHeaders,
        body: json.encode({
          'email': email,
          'password': password,
          'fName': name,
          'mtype': userType,
          'tel': phone,
          'address': address,
          'langId': langId ?? 'Lg000001',
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to register: ${e.toString()}');
    }
  }

  static Future<dynamic> loginUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$mysqlconnect'),
        headers: defaultHeaders,
        body: json.encode({'email': email, 'password': password}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to login: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>?> loginWithPhone(
    String phone,
    String otp,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login_app.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone, "otp": otp}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final msg = jsonDecode(response.body)['message'];
      throw Exception(msg ?? "登入失敗");
    }
  }

  // ★ 修改密碼（賬戶頁面用）
  static Future<Map<String, dynamic>> changePassword({
    required String mId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/change_password.php'),
        headers: defaultHeaders,
        body: json.encode({
          'mId': mId,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 15));
      return Map<String, dynamic>.from(_handleResponse(response) as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ★ 通知列表（通知 Tab 用）
  static Future<List<dynamic>> getNotifications(String mId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_notifications', 'mId': mId}),
      ).timeout(const Duration(seconds: 15));
      final data = _handleResponse(response);
      if (data is Map) {
        return (data['notifications'] ?? data['data'] ?? []) as List;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── 用戶 ──────────────────────────────────────────────────

  static Future<List<dynamic>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$mysqlconnect'),
        headers: defaultHeaders,
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to load users: ${e.toString()}');
    }
  }

  static Future<dynamic> createUser(
    String fName, String nName, String mType, String password,
    String address, String email, int tel, String loginMethod,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$mysqlconnect'),
        headers: defaultHeaders,
        body: json.encode({
          'fName': fName, 'nName': nName, 'mType': mType,
          'password': password, 'address': address, 'email': email,
          'tel': tel, 'loginMethod': loginMethod,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to create user: ${e.toString()}');
    }
  }

  static Future<dynamic> updateUser(
    String mId, String fName, String nName, String mType, String password,
    String address, String email, int tel, String loginMethod,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$mysqlconnect'),
        headers: defaultHeaders,
        body: json.encode({
          'mId': mId, 'fName': fName, 'nName': nName, 'mType': mType,
          'password': password, 'address': address, 'email': email,
          'tel': tel, 'loginMethod': loginMethod,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to update user: ${e.toString()}');
    }
  }

  static Future<dynamic> deleteUser(String mId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$mysqlconnect?mId=$mId'),
        headers: defaultHeaders,
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to delete user: ${e.toString()}');
    }
  }

  static Future<dynamic> switchIdentity(String currentMid) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/switch_identity.php'),
        headers: defaultHeaders,
        body: json.encode({'currentMid': currentMid}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to switch identity: ${e.toString()}');
    }
  }

  // ── 提款 ──────────────────────────────────────────────────

  static Future<dynamic> getWithdrawalSummary(String teacherId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_withdrawal_summary', 'mId': teacherId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get withdrawal summary: ${e.toString()}');
    }
  }

  static Future<dynamic> createWithdrawalRequest({
    required String teacherId,
    required double amountHkd,
    required String paymentMethod,
    required String accountInfo,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'create_withdrawal_request',
          'mId': teacherId,
          'amount': amountHkd,
          'paymentMethod': paymentMethod,
          'accountInfo': accountInfo,
          if (reason != null) 'reason': reason,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to create withdrawal request: ${e.toString()}');
    }
  }

  static Future<dynamic> getWithdrawalRequests(String teacherId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_withdrawal_requests', 'mId': teacherId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get withdrawal requests: ${e.toString()}');
    }
  }

  static Future<dynamic> getWithdrawalRequestDetail({
    required String teacherId,
    required String requestId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'get_withdrawal_request_detail',
          'mId': teacherId,
          'requestId': requestId,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get withdrawal detail: ${e.toString()}');
    }
  }

  // ── 課程 ──────────────────────────────────────────────────

  static Future<dynamic> getTeacherCourses(String teacherId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_teacher_courses', 'mId': teacherId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get teacher courses: ${e.toString()}');
    }
  }

  static Future<dynamic> createCourse({
    required String courseName,
    required double unitPrice,
    required String summary,
    required int totalLesson,
    required String categoryId,
    required String teacherId,
    String languageId = 'Lg000001',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'create_course',
          'cName': courseName,
          'unitPrice': unitPrice,
          'summary': summary,
          'totalLesson': totalLesson,
          'cateId': categoryId,
          'mId': teacherId,
          'langId': languageId,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to create course: ${e.toString()}');
    }
  }

  static Future<dynamic> updateCourse({
    required String courseId,
    String? courseName,
    double? unitPrice,
    String? description,
    int? totalLesson,
    String? subject,
    String? langId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'update_course',
          'cId': courseId,
          if (courseName != null) 'cName': courseName,
          if (unitPrice != null) 'unitPrice': unitPrice,
          if (description != null) 'cDescription': description,
          if (totalLesson != null) 'totalLesson': totalLesson,
          if (subject != null) 'subject': subject,
          if (langId != null) 'langId': langId,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to update course: ${e.toString()}');
    }
  }

  static Future<dynamic> deleteCourse(String courseId, {bool cleanup = true}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'delete_course',
          'cId': courseId,
          'cleanup': cleanup ? 1 : 0,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to delete course: ${e.toString()}');
    }
  }

  static Future<dynamic> purgeCourse(String courseId, {bool cleanup = true}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'purge_course',
          'cId': courseId,
          'cleanup': cleanup ? 1 : 0,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to purge course: ${e.toString()}');
    }
  }

  static Future<dynamic> restoreCourse(String courseId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'restore_course', 'cId': courseId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to restore course: ${e.toString()}');
    }
  }

  static Future<dynamic> getCourseStats(String courseId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_course_stats', 'cId': courseId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get course stats: ${e.toString()}');
    }
  }

  static Future<dynamic> getCourseStudentStats(String courseId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_course_student_stats', 'cId': courseId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get course student stats: ${e.toString()}');
    }
  }

  static Future<dynamic> updateCourseMedia({
    required String courseId,
    String? introImg,
    String? introVideo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'update_course_media',
          'cId': courseId,
          'introImg': introImg,
          'introVideo': introVideo,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to update course media: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getCategories() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_categories'}),
      );
      return Map<String, dynamic>.from(_handleResponse(response) as Map);
    } catch (e) {
      throw ApiException('Failed to get categories: ${e.toString()}');
    }
  }

  // ── 章節 ──────────────────────────────────────────────────

  static Future<dynamic> getCourseLessons(String courseId, {bool showDeleted = false}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'get_course_lessons',
          'cId': courseId,
          if (showDeleted) 'showDeleted': 1,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get course lessons: ${e.toString()}');
    }
  }

  static Future<dynamic> createLesson({
    required String courseId,
    required String lessonName,
    required int duration,
    double price = 0.0,
    int orderNum = 1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'create_lesson',
          'cId': courseId,
          'lName': lessonName,
          'duration': duration,
          'price': price,
          'orderNum': orderNum,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to create lesson: ${e.toString()}');
    }
  }

  static Future<dynamic> updateLesson({
    required String lessonId,
    required String lessonName,
    required int duration,
    double? price,
    int? orderNum,
    String? video,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'update_lesson',
          'lId': lessonId,
          'lName': lessonName,
          'duration': duration,
          if (price != null) 'price': price,
          if (orderNum != null) 'orderNum': orderNum,
          if (video != null) 'video': video,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to update lesson: ${e.toString()}');
    }
  }

  static Future<dynamic> deleteLesson(String lessonId, {bool cleanup = true}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'delete_lesson',
          'lId': lessonId,
          'cleanup': cleanup ? 1 : 0,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to delete lesson: ${e.toString()}');
    }
  }

  static Future<dynamic> restoreLesson(String lessonId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'restore_lesson', 'lId': lessonId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to restore lesson: ${e.toString()}');
    }
  }

  static Future<dynamic> updateLessonVideo(String lessonId, String videoPath, {int? duration}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'update_lesson_video',
          'lId': lessonId,
          'videoPath': videoPath,
          if (duration != null) 'duration': duration,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to update lesson video: ${e.toString()}');
    }
  }

  static Future<dynamic> deleteLessonVideo(String lessonId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'delete_lesson_video', 'lId': lessonId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to delete lesson video: ${e.toString()}');
    }
  }

  static Future<dynamic> deleteLessonFiles(String lessonId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'delete_lesson_files', 'lId': lessonId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to delete lesson files: ${e.toString()}');
    }
  }

  // ── 教材資源 ──────────────────────────────────────────────

  static Future<dynamic> getLessonResources(String lessonId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_lesson_resources', 'lId': lessonId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get lesson resources: ${e.toString()}');
    }
  }

  static Future<dynamic> uploadLessonResource({
    required String lessonId,
    required String resourceName,
    required String resourcePath,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'upload_lesson_resource',
          'lId': lessonId,
          'lrName': resourceName,
          'path': resourcePath,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to upload lesson resource: ${e.toString()}');
    }
  }

  static Future<dynamic> uploadLessonResourceUrl({
    required String lessonId,
    required String resourceName,
    required String resourceUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'upload_lesson_resource_url',
          'lId': lessonId,
          'lrName': resourceName,
          'path': resourceUrl,
        }),
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        throw ApiException('Request timed out.');
      });
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to upload lesson resource URL: ${e.toString()}');
    }
  }

  static Future<dynamic> deleteLessonResource(String resourceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'delete_lesson_resource', 'lrId': resourceId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to delete lesson resource: ${e.toString()}');
    }
  }

  // ── 學生 ──────────────────────────────────────────────────

  static Future<dynamic> getCourseStudents(String courseId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_course_students', 'cId': courseId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get course students: ${e.toString()}');
    }
  }

  static Future<dynamic> getStudentDetail({
    required String courseId,
    required String memberId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'get_student_detail',
          'cId': courseId,
          'mId': memberId,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get student detail: ${e.toString()}');
    }
  }

  static Future<dynamic> getStudentDetails(String studentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_student_details', 'mId': studentId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get student details: ${e.toString()}');
    }
  }

  static Future<dynamic> getStudentCourseProgress({
    required String studentId,
    required String courseId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({
          'action': 'get_student_course_progress',
          'mId': studentId,
          'cId': courseId,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get student course progress: ${e.toString()}');
    }
  }

  // ── 統計 ──────────────────────────────────────────────────

  static Future<dynamic> getTeacherOverallStats(String memberId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_course_app.php'),
        headers: defaultHeaders,
        body: json.encode({'action': 'get_teacher_overall_stats', 'mId': memberId}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to get teacher overall stats: ${e.toString()}');
    }
  }

  // ── 其他 ──────────────────────────────────────────────────

  static Future<void> markFirstLesson({
    required String memberId,
    required String lessonId,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/mark_first_lesson.php'),
        headers: defaultHeaders,
        body: json.encode({'mId': memberId, 'lId': lessonId}),
      );
    } catch (_) {}
  }

  static Future<void> reportLessonProgress(String lessonId, int seconds) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/progress.php'),
        headers: defaultHeaders,
        body: json.encode({'lId': lessonId, 'seconds': seconds}),
      );
    } catch (_) {}
  }

  static Future<void> trackEvent(String event, Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/analytics.php'),
        headers: defaultHeaders,
        body: json.encode({'event': event, ...data}),
      );
    } catch (_) {}
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}
