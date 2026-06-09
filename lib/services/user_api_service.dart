import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path/path.dart';
import '../../services/aws_service.dart';

class UserApiService {
  static const String baseUrl = 'http://3.25.85.107/mysqlconnect';

  // 【關鍵】如果你的 File/ 資料夾是在這個網址下，請確保這行正確
  // 如果 File/ 是在 Amazon S3，這裡就要改成 Amazon 的網址
  static const String imageBaseUrl = 'http://3.25.85.107/mysqlconnect';

  // 1. 獲取用戶資料
  static Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user_profile_api.php?action=getUser&mId=$userId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('網路錯誤: $e');
    }
  }

  // 2. 修改用戶網名 (對應 change_info_page.dart)
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> updateData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user_profile_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'update_info', ...updateData}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': '伺服器錯誤: ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'error', 'message': '網路連線失敗: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateTeacherMeta({
    required String teacherId,
    String? introVideoPath,
    List<String>? cateIds,
  }) async {
    try {
      final payload = <String, dynamic>{
        'action': 'update_teacher_meta',
        'mId': teacherId,
      };
      if (introVideoPath != null) payload['introVideoPath'] = introVideoPath;
      if (cateIds != null) payload['cateIds'] = cateIds;

      final response = await http.post(
        Uri.parse('$baseUrl/user_profile_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': '伺服器錯誤: ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'error', 'message': '網路連線失敗: $e'};
    }
  }

  // 3. 修改密碼 (對應 change_password_page.dart)
  static Future<Map<String, dynamic>> changePassword(
    String userId,
    String oldPwd,
    String newPwd,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user_profile_api.php?action=getUser&mId=$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'change_password',
          'mId': userId,
          'oldPassword': oldPwd,
          'newPassword': newPwd,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': '網路連線失敗'};
    }
  }

  static const String acoinUrl = "$baseUrl/acoin_api.php";

  static Future<Map<String, dynamic>> getACoinHistory(String mId) async {
    try {
      final response = await http.post(
        Uri.parse(acoinUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'get_history', 'mId': mId}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': '讀取紀錄失敗: $e'};
    }
  }

  // 5. 執行交易 (簽到)
  static Future<Map<String, dynamic>> postACoinTransaction(
    String mId,
    String typeId, {
    String? desc,
    int? points, // <-- 新增這個參數
  }) async {
    try {
      final response = await http.post(
        Uri.parse(acoinUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'add_transaction',
          'mId': mId,
          'actTypeId': typeId,
          'description': desc ?? '',
          'points': points, // <-- 傳給 PHP
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': '網路連線失敗: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfileWithImage({
    required String mId,
    required Map<String, String> fields,
    File? imageFile,
    bool deleteAvatar = false,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/user_profile_api.php'),
      );

      // 加入基本參數
      request.fields['action'] = 'update_info';
      request.fields['mId'] = mId;
      fields.forEach((key, value) => request.fields[key] = value);

      if (deleteAvatar) {
        request.fields['delete_avatar'] = '1';
      }

      // 加入檔案
      if (imageFile != null) {
        var stream = http.ByteStream(imageFile.openRead());
        var length = await imageFile.length();
        var multipartFile = http.MultipartFile(
          'avatar',
          stream,
          length,
          filename: basename(imageFile.path),
        );
        request.files.add(multipartFile);
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': '上傳失敗: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfileMultipart({
    required String mId,
    required String username,
    required String tel,
    required String email,
    required String gender,
    required String selfIntro,
    File? imageFile,
    bool deleteAvatar = false,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/user_profile_api.php'),
      );

      request.fields['action'] = 'update_info';
      request.fields['mId'] = mId;
      request.fields['username'] = username;
      request.fields['tel'] = tel;
      request.fields['email'] = email;
      request.fields['gender'] = gender;
      request.fields['selfIntro'] = selfIntro;
      if (deleteAvatar) request.fields['delete_avatar'] = '1';

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            imageFile.path,
            filename: basename(imageFile.path),
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // 這裡加一個 print 方便你除錯，看看 PHP 到底回傳什麼
      print('PHP Response: ${response.body}');

      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': '網絡連線失敗: $e'};
    }
  }

  static String getFullImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) {
      return AWSService.getPresignedUrl(
        'default/defaultUserPicture/EDULogo.jpg',
      );
    }
    
    // 清理可能的換行和隱藏字元
    String cleanPath = path.trim().replaceAll('\n', '').replaceAll('\r', '');

    // 1. 如果已經是完整網址，直接回傳
    if (cleanPath.startsWith('http')) return cleanPath;

    // 2. 如果是 File/ 開頭的路徑，使用跟影片一樣的 AWS 簽名邏輯
    if (cleanPath.startsWith('File/')) {
      // 調用你現有的 AWSService 來獲取合法的 Amazon 網址
      return AWSService.getPresignedUrl(cleanPath);
    }

    // 3. 其他路徑 (如本地 uploads/) 則走原本的伺服器
    return '$baseUrl/$cleanPath';
  }

  static Future<Map<String, dynamic>> getPublicMemberProfile(String mId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/member_public_profile.php?mId=$mId'),
    );
    try {
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid response: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> checkIdentity(String mId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/identity_api.php?action=check_identity&mId=$mId'),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'hasTeacher': false};
    }
  }

  // 2. 註冊老師 (Multipart 提交影片)
  static Future<Map<String, dynamic>> registerAsTeacher({
    required String studentMid,
    required String username,
    required String selfIntro,
    required String introVideoPath,
    required List<String> cateIds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher_registration_api.php'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "studentMid": studentMid,
          "username": username,
          "selfIntro": selfIntro,
          "introVideoPath": introVideoPath,
          "cateIds": cateIds,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': '網路連線失敗: $e'};
    }
  }

  static Future<Map<String, dynamic>> switchIdentity(String currentMid) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/switch_identity.php'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"currentMid": currentMid}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? '切換失敗');
      }
    } catch (e) {
      throw Exception('網路連線失敗: $e');
    }
  }
}
