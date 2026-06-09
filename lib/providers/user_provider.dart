import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/user_api_service.dart';
import '../services/api_service.dart';
import '../services/course_api_service.dart';
import '../services/notification_read_storage.dart';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  bool _isInitialized = false;
  final AuthService _authService = AuthService();

  // 通知相關
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;
  Set<String> _readMessageIds = {};

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  bool get isTeacher => _currentUser?.mType == 'T';

  final Set<String> _purchasedCourseIds = {};
  final Set<String> _purchasedLessonIds = {};

  Set<String> get purchasedCourseIds => _purchasedCourseIds;
  Set<String> get purchasedLessonIds => _purchasedLessonIds;

  String? _linkedTeacherId;
  bool get hasTeacherAccount =>
      (_currentUser?.hasRelation == true) || _linkedTeacherId != null;
  String? get linkedTeacherId => _linkedTeacherId;

  UserProvider() {
    _loadCurrentUser();
  }

  Future<void> checkIdentityRelation() async {
    if (_currentUser == null) return;
    final res = await UserApiService.checkIdentity(_currentUser!.memberId);
    if (res['status'] == 'success' && res['hasTeacher'] == true) {
      _linkedTeacherId = res['teacherId'];
    } else {
      _linkedTeacherId = null;
    }
    notifyListeners();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await _authService.getCurrentUser();
    _isInitialized = true;
    if (_currentUser != null) {
      await refreshUserInfo();
      syncPointsWithDb();
      checkIdentityRelation();
      await _loadReadMessageIds();
      await fetchUnreadCount();
    }
    notifyListeners();
  }

  Future<void> _loadReadMessageIds() async {
    if (_currentUser == null) return;
    _readMessageIds = await NotificationReadStorage.load(
      _currentUser!.memberId,
    );
  }

  bool isMessageRead(String messageId) {
    if (messageId.isEmpty) return false;
    return _readMessageIds.contains(messageId);
  }

  Future<void> markMessageRead(String messageId) async {
    if (_currentUser == null) return;
    if (messageId.isEmpty) return;
    if (_readMessageIds.contains(messageId)) return;
    _readMessageIds = await NotificationReadStorage.markRead(
      _currentUser!.memberId,
      messageId,
    );
    notifyListeners();
  }

  void updateUnreadCountFromMessages(List<dynamic> messages) {
    final unread = messages.where((m) {
      if (m is! Map) return false;
      final id = (m['messageId'] ?? m['id'] ?? '').toString();
      if (id.isEmpty) return false;
      return !_readMessageIds.contains(id);
    }).length;
    _unreadCount = unread;
    notifyListeners();
  }

  Future<void> updateName(String newName) async {
    if (_currentUser != null) {
      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: newName, // 使用傳入的新名字
        userType: _currentUser!.userType,
        mType: _currentUser!.mType,
        hasRelation: _currentUser!.hasRelation,
        memberId: _currentUser!.memberId,
        tel: _currentUser!.tel,
        address: _currentUser!.address,
        points: _currentUser!.points,
        pointsHistory: _currentUser!.pointsHistory, // 記得帶回歷史紀錄
        avgRating: _currentUser!.avgRating,
        tBookCount: _currentUser!.tBookCount,
        teacherLevel: _currentUser!.teacherLevel,
        gender: _currentUser!.gender,
        selfIntro: _currentUser!.selfIntro,
        selfIntroVideo: _currentUser!.selfIntroVideo,
        avatar: _currentUser!.avatar,
        teacherCateIds: _currentUser!.teacherCateIds,
      );

      await _authService.saveUser(_currentUser!);
      notifyListeners();
    }
  }

  Future<void> updateProfileLocal({
    String? username,
    String? email,
    String? tel,
    String? gender,
    String? selfIntro,
    String? selfIntroVideo,
    String? avatar,
    List<String>? teacherCateIds,
  }) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      name: username,
      email: email,
      tel: tel,
      gender: gender,
      selfIntro: selfIntro,
      selfIntroVideo: selfIntroVideo,
      avatar: avatar,
      teacherCateIds: teacherCateIds,
    );
    await _authService.saveUser(_currentUser!);
    notifyListeners();
  }

  Future<void> refreshUserInfo() async {
    if (_currentUser == null) return;
    try {
      final response = await UserApiService.getUserInfo(_currentUser!.memberId);
      if (response['status'] == 'success') {
        final serverUser = User.fromMap(response['data']);
        _currentUser = _currentUser!.copyWith(
          email: serverUser.email,
          name: serverUser.name,
          mType: serverUser.mType,
          hasRelation: serverUser.hasRelation,
          tel: serverUser.tel,
          address: serverUser.address,
          gender: serverUser.gender,
          selfIntro: serverUser.selfIntro,
          selfIntroVideo: serverUser.selfIntroVideo,
          avatar: serverUser.avatar,
          points: serverUser.points,
          avgRating: serverUser.avgRating,
          tBookCount: serverUser.tBookCount,
          teacherLevel: serverUser.teacherLevel,
          teacherCateIds: serverUser.teacherCateIds,
        );
        await _authService.saveUser(_currentUser!);
        notifyListeners();
      }
    } catch (e) {}
  }

  // --- 積分功能實行 ---

  /// 增加積分 (用於遊戲獲獎)
  Future<void> addPoints(int amount, [String reason = "獲得積分"]) async {
    if (_currentUser != null) {
      // 1. 同步到後端 API (使用 att009: 遊戲獎勵)
      try {
        final res = await UserApiService.postACoinTransaction(
          _currentUser!.memberId,
          'att009',
          desc: reason,
          points: amount,
        );

        if (res['status'] == 'success') {
          // 2. 只有伺服器成功後才刷新餘額與歷史紀錄
          await syncPointsWithDb();
        } else {
          throw Exception(res['message'] ?? "伺服器更新積分失敗");
        }
      } catch (e) {
        debugPrint("遊戲積分同步失敗: $e");
        // 不再手動加分本地，讓 UI 捕捉錯誤或保持原狀
        rethrow; // 讓調用方知道失敗了
      }
    }
  }

  Future<bool> subtractPoints(int amount, [String reason = "扣除積分"]) async {
    if (_currentUser != null && _currentUser!.points >= amount) {
      try {
        // 使用 'att010' 遊戲消費 (通用扣分)，將正數轉為負數傳給 API
        final res = await UserApiService.postACoinTransaction(
          _currentUser!.memberId,
          'att010',
          desc: reason,
          points: -amount,
        );

        if (res['status'] == 'success') {
          // 刷新餘額與歷史紀錄
          await syncPointsWithDb();
          return true;
        } else {
          debugPrint("扣除積分伺服器錯誤: ${res['message']}");
          return false;
        }
      } catch (e) {
        debugPrint("扣除積分同步失敗: $e");
        // 不再執行本地扣分，直接回傳失敗
        return false;
      }
    }
    return false;
  }

  Future<bool> purchaseWithCoins(int amount, String reason) async {
    if (_currentUser == null) return false;
    if (_currentUser!.points < amount) return false;
    try {
      final res = await UserApiService.postACoinTransaction(
        _currentUser!.memberId,
        'att008',
        desc: reason,
        points: -amount,
      );
      if (res['status'] == 'success') {
        await syncPointsWithDb();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> refundCoins(int amount, String reason) async {
    if (_currentUser == null) return false;
    if (amount <= 0) return false;
    try {
      final res = await UserApiService.postACoinTransaction(
        _currentUser!.memberId,
        'att009',
        desc: reason,
        points: amount,
      );
      if (res['status'] == 'success') {
        await syncPointsWithDb();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setUser(User user) async {
    print("正在設定用戶資料: 姓名=${user.name}, ID=${user.memberId}");
    _currentUser = user;
    await _authService.saveUser(user);
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    await _authService.logout();
    notifyListeners();
  }

  Future<void> toggleUserType() async {
    if (_currentUser == null) return;

    try {
      // 1. 先記住切換前的狀態：既然現在能點「切換」，代表他一定有老師身分
      // 我們假設只要進入這個 function，hasRelation 就應該是 true
      bool permanentHasRelation = true;

      final res = await ApiService.switchIdentity(_currentUser!.memberId);
      debugPrint("API Response: $res");

      if (res != null && (res['mType'] != null || res['status'] == 'success')) {
        final userData = res['data'] ?? res;

        // 2. 更新用戶物件
        User newUser = User.fromMap(userData);

        // 3. 📢 關鍵點：強制把 hasRelation 設回 true
        // 這樣就算 API 回傳的學生資料沒寫 hasRelation，Flutter 也會記住他有老師身分
        _currentUser = newUser.copyWith(hasRelation: permanentHasRelation);

        // 4. 同步到本地與 UI
        await _authService.saveUser(_currentUser!);

        _purchasedCourseIds.clear();
        _purchasedLessonIds.clear();

        notifyListeners();
        debugPrint(
          "切換成功！新身份為: ${_currentUser!.mType}, 關聯狀態: ${_currentUser!.hasRelation}",
        );
      } else {
        throw Exception("後端回傳資料格式錯誤或查無關聯帳號");
      }
    } catch (e) {
      debugPrint("切換身分發生錯誤: $e");
      rethrow;
    }
  }

  void clearUnread() {
    _unreadCount = 0;
    notifyListeners();
  }

  void purchaseLesson(String lessonId) {
    _purchasedLessonIds.add(lessonId);
    notifyListeners();
  }

  // 新增：購買全課 (這會解鎖該課程下所有內容)
  void purchaseFullCourse(String courseId, List<dynamic> allLessonIds) {
    _purchasedCourseIds.add(courseId);
    // 同時將該課程的所有章節也標記為已購買
    for (var id in allLessonIds) {
      _purchasedLessonIds.add(id.toString());
    }
    notifyListeners();
  }

  // 新增：判斷是否已購買某章節
  bool isLessonPurchased(String courseId, String lessonId) {
    // 如果買了全課，或者買了該單獨章節，都算已購買
    return _purchasedCourseIds.contains(courseId) ||
        _purchasedLessonIds.contains(lessonId);
  }

  bool canCheckIn() {
    if (_currentUser == null) return false;

    // 獲取今天日期 (格式: 2025-05-20)
    String today = DateTime.now().toString().substring(0, 10);

    // 檢查積分歷史紀錄中，是否有標題為 "每日簽到獎勵" 且日期是今天的紀錄
    // 注意：這裡的 title 必須與你資料庫 ACoinTransType 表中的 description 一致
    bool hasRecordToday = _currentUser!.pointsHistory.any(
      (record) => record.title == "每日簽到獎勵" && record.date.startsWith(today),
    );

    return !hasRecordToday; // 如果沒紀錄，就可以簽到
  }

  void addCheckInPoints() {
    if (canCheckIn()) {
      addPoints(10, "每日簽到獎勵");
    }
  }

  // 在 UserProvider 類中加入

  int get continuousCheckInDays {
    if (_currentUser == null || _currentUser!.pointsHistory.isEmpty) return 0;

    // 1. 過濾出所有簽到紀錄，並只保留日期部分（去重複，防止一天多個紀錄影響計算）
    List<String> checkInDates = _currentUser!.pointsHistory
        .where((r) => r.title == "每日簽到獎勵")
        .map((r) => r.date.substring(0, 10))
        .toSet()
        .toList();

    if (checkInDates.isEmpty) return 0;

    // 2. 排序日期（由新到舊）
    checkInDates.sort((a, b) => b.compareTo(a));

    String today = DateTime.now().toString().substring(0, 10);
    String yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toString()
        .substring(0, 10);

    // 3. 如果今天和昨天都沒簽到，連續中斷
    if (checkInDates[0] != today && checkInDates[0] != yesterday) {
      return 0;
    }

    int count = 0;
    DateTime currentCheckDate = DateTime.parse(checkInDates[0]);

    // 4. 開始往回數
    for (int i = 0; i < checkInDates.length; i++) {
      DateTime recordDate = DateTime.parse(checkInDates[i]);

      // 檢查這條紀錄是否是我們預期中的「前一天」
      // 第一條紀錄或是與上一條剛好差一天
      if (i == 0 ||
          DateTime.parse(checkInDates[i - 1]).difference(recordDate).inDays ==
              1) {
        count++;
      } else {
        break; // 中斷了
      }
    }
    return count;
  }

  Future<void> syncPointsWithDb() async {
    if (_currentUser == null) return;

    try {
      final res = await UserApiService.getACoinHistory(_currentUser!.memberId);
      if (res['status'] == 'success') {
        List<dynamic> data = res['data'];

        // 更新歷史紀錄
        _currentUser!.pointsHistory = data
            .map(
              (item) => PointRecord(
                title: item['title'] ?? '未分類交易',
                amount: (item['amount'] as num).toInt(),
                date: item['date'].toString().substring(0, 16),
                type: (item['amount'] as num).toInt() >= 0 ? 'add' : 'subtract',
              ),
            )
            .toList();

        // 更新總積分 (取最新的 total)
        if (data.isNotEmpty) {
          _currentUser!.points = (data[0]['total'] as num).toInt();
        }

        notifyListeners();
        await _authService.saveUser(_currentUser!); // 同時備份到本地
      }
    } catch (e) {
      debugPrint("同步積分失敗: $e");
    }
  }

  /// 執行簽到流程 (連動 API)
  Future<Map<String, dynamic>> performCheckIn() async {
    if (_currentUser == null) return {'status': 'error', 'message': '請先登入'};

    try {
      // 這裡一定要改成 'att014'
      final res = await UserApiService.postACoinTransaction(
        _currentUser!.memberId,
        'att014',
      );

      if (res['status'] == 'success') {
        // 簽到成功後，自動呼叫同步方法更新畫面上的分數與紀錄
        await syncPointsWithDb();
        return res;
      } else {
        return res; // 這會回傳 PHP 輸出的 "今日已領取過"
      }
    } catch (e) {
      return {'status': 'error', 'message': '系統連線失敗: $e'};
    }
  }

  Future<Map<String, dynamic>> performACoinTransaction(
    String typeId, {
    String? customDesc,
    int? points,
  }) async {
    if (_currentUser == null) return {'status': 'error', 'message': '請先登入'};

    final res = await UserApiService.postACoinTransaction(
      _currentUser!.memberId,
      typeId,
      desc: customDesc,
      points: points,
    );

    if (res['status'] == 'success') {
      await syncPointsWithDb(); // 儲值成功後立刻刷新 UI 分數
    }
    return res;
  }

  Future<void> fetchUnreadCount() async {
    if (_currentUser == null) return;

    try {
      // 假設你在 CourseApiService 增加了 getMessages
      final res = await CourseApiService.getMessages(_currentUser!.memberId);
      final messages = (res['messages'] is List)
          ? (res['messages'] as List)
          : const <dynamic>[];
      updateUnreadCountFromMessages(messages);
    } catch (e) {
      debugPrint("抓取通知失敗: $e");
    }
  }

  Future<void> refreshIdentityStatus() async {
    if (_currentUser == null) return;
    try {
      // 呼叫上面的 PHP
      final res = await UserApiService.checkIdentity(_currentUser!.memberId);
      if (res['hasTeacher'] == true) {
        _linkedTeacherId = res['teacherId'];
      } else {
        _linkedTeacherId = null;
      }
      notifyListeners();
    } catch (e) {
      print("檢查身份失敗: $e");
    }
  }

  /// 執行身份切換後的清理與同步工作
  Future<void> updateUserAfterSwitch(User newUser) async {
    // 1. 更新當前用戶
    _currentUser = newUser;

    // 2. 儲存到本地，確保重啟 App 後維持此身份
    await _authService.saveUser(newUser);

    // 3. 清空購買快取 (因為老師不需要購買紀錄，而新學生身份需要重新抓取)
    _purchasedCourseIds.clear();
    _purchasedLessonIds.clear();

    // 4. 如果切換回學生身分，自動重新抓取積分與購買歷史
    if (newUser.mType == 'S') {
      await syncPointsWithDb();
      // 如果你有 fetchPurchasedCourses 方法，也該在這裡執行
      // await fetchPurchasedCourses(newUser.memberId);
    }

    // 5. 重新檢查關聯狀態 (更新 _linkedTeacherId)
    await checkIdentityRelation();

    // 6. 📢 關鍵：通知所有監聽者 (MainPage 的課程分頁、MemberPage 的按鈕都會重繪)
    notifyListeners();
  }

  void updateUserDataAfterRegistration(Map<String, dynamic> userData) async {
    // 1. 將 API 回傳的資料轉為 User 物件 (此時 mType 應為 'T')
    _currentUser = User.fromMap(userData);

    // 2. 💡 最重要：同步更新關聯 ID，讓 hasTeacherAccount 變為 true
    _linkedTeacherId = _currentUser!.memberId;

    // 3. 儲存到本地 SharedPreference
    await _authService.saveUser(_currentUser!);

    // 4. 通知所有監聽者（MemberPage 會重新 build）
    notifyListeners();
  }

  void updateAfterTeacherRegistration(Map<String, dynamic> userData) async {
    // 1. 將回傳的 T 身份資料轉成 User 物件
    _currentUser = User.fromMap(userData);

    // 2. 💡 關鍵：因為剛註冊完，我們必須手動給 _linkedTeacherId 賦值
    // 這樣 hasTeacherAccount 才會立刻變成 true
    _linkedTeacherId = _currentUser!.memberId;

    // 3. 儲存到本地 SharedPreference，確保下次開 App 還是老師
    await _authService.saveUser(_currentUser!);

    // 4. 💡 核心：發送通知，讓 MemberPage 重新 build
    notifyListeners();

    print(
      "Provider 已同步：目前身分為 ${_currentUser!.mType}, 關聯 ID: $_linkedTeacherId",
    );
  }
}
