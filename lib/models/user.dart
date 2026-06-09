class User {
  final String id;
  final String email;
  final String name;
  final String userType;
  final String mType; // 資料庫原始身份 (S/T)
  final bool hasRelation; // 是否有另一種身份的關聯
  final String memberId;
  final String? tel;
  final String? address;
  final String? gender; // 新增：性別
  final String? selfIntro; // 新增：自我介紹
  final String? selfIntroVideo; // 新增：自我介紹影片
  final String? avatar; // 新增：頭像路徑
  final List<String> teacherCateIds; // 新增：導師擅長科目
  int points;
  List<PointRecord> pointsHistory; // 1. 確保定義在這裡
  final double avgRating; // 導師平均分
  final int tBookCount; // 老師被收藏次數
  final int teacherLevel; // 導師等級 (1-5)

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.userType,
    required this.mType,
    required this.hasRelation, // 新增
    required this.memberId,
    this.tel,
    this.address,
    this.gender,
    this.selfIntro,
    this.selfIntroVideo,
    this.avatar,
    List<String>? teacherCateIds,
    this.points = 0,
    List<PointRecord>? pointsHistory, // 2. 這裡使用可空類型
    this.avgRating = 0.0,
    this.tBookCount = 0,
    this.teacherLevel = 1,
  })  : teacherCateIds = teacherCateIds ?? const [],
        pointsHistory = pointsHistory ?? []; // 3. 初始化

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'userType': userType,
      'mType': mType,
      'hasRelation': hasRelation, // 新增
      'memberId': memberId,
      'tel': tel,
      'address': address,
      'gender': gender,
      'selfIntro': selfIntro,
      'selfIntroVideo': selfIntroVideo,
      'avatar': avatar,
      'teacherCateIds': teacherCateIds,
      'points': points,
      'pointsHistory': pointsHistory.map((x) => x.toMap()).toList(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    final String resolvedMType = (map['mType'] ?? 'S').toString();
    final String rawUserType = (map['userType'] ?? '').toString();
    final String resolvedUserType =
        rawUserType.isNotEmpty ? rawUserType : (resolvedMType == 'T' ? 'teacher' : 'student');
    return User(
      id: (map['id'] ?? map['mId'] ?? '').toString(),
      email: map['email'] ?? '',
      name: map['username'] ?? map['name'] ?? '',
      userType: resolvedUserType,
      mType: resolvedMType,
      hasRelation: map['hasRelation'] ?? false, // 讀取
      memberId: map['memberId'] ?? map['mId'] ?? '',
      tel: map['tel'] ?? map['phone'],
      address: map['address'],
      gender: map['gender'],
      selfIntro: map['selfIntro'] ?? map['self_intro'],
      selfIntroVideo: map['selfIntroVideo'] ?? map['self_intro_video'],
      avatar: map['avatar'],
      teacherCateIds: (map['cateIds'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      points: map['points'] ?? 0,
      avgRating: map['avgRating'] != null
          ? (double.tryParse(map['avgRating'].toString()) ?? 0.0)
          : 0.0,

      // 確保 int 類型也有預設值
      tBookCount: map['tBookCount'] != null
          ? int.tryParse(map['tBookCount'].toString()) ?? 0
          : 0,

      teacherLevel: map['teacherLevel'] != null
          ? int.tryParse(map['teacherLevel'].toString()) ?? 1
          : 1,
      // 4. 使用 cast<Map<String, dynamic>>() 確保類型轉換正確
      pointsHistory:
          (map['pointsHistory'] as List?)
              ?.map((x) => PointRecord.fromMap(x as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? userType,
    String? mType,
    bool? hasRelation,
    String? memberId,
    String? tel,
    String? address,
    String? gender,
    String? selfIntro,
    String? selfIntroVideo,
    String? avatar,
    List<String>? teacherCateIds,
    int? points,
    List<PointRecord>? pointsHistory,
    double? avgRating,
    int? tBookCount,
    int? teacherLevel,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      userType: userType ?? this.userType,
      mType: mType ?? this.mType,
      hasRelation: hasRelation ?? this.hasRelation,
      memberId: memberId ?? this.memberId,
      tel: tel ?? this.tel,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      selfIntro: selfIntro ?? this.selfIntro,
      selfIntroVideo: selfIntroVideo ?? this.selfIntroVideo,
      avatar: avatar ?? this.avatar,
      teacherCateIds: teacherCateIds ?? this.teacherCateIds,
      points: points ?? this.points,
      pointsHistory: pointsHistory ?? this.pointsHistory,
      avgRating: avgRating ?? this.avgRating,
      tBookCount: tBookCount ?? this.tBookCount,
      teacherLevel: teacherLevel ?? this.teacherLevel,
    );
  }
}

// PointRecord 類別確保有 toMap 和 fromMap
class PointRecord {
  final String title;
  final int amount;
  final String date;
  final String type;

  PointRecord({
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'amount': amount,
    'date': date,
    'type': type,
  };

  factory PointRecord.fromMap(Map<String, dynamic> map) => PointRecord(
    title: map['title'] ?? '',
    amount: map['amount'] ?? 0,
    date: map['date'] ?? '',
    type: map['type'] ?? 'add',
  );
}
