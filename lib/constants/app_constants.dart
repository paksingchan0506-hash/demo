class AppConstants {
  static const String appName = 'EDU Learning Platform';
  static const String appVersion = '1.0.0';
  static const String appDescription = '在線教育學習平台';
  
  // API Endpoints
  static const String baseUrl = 'http://3.25.85.107/mysqlconnect';
  static const String loginEndpoint = '/Member.php';
  static const String registerEndpoint = '/Member.php';
  static const String coursesEndpoint = '/courses.php';
  static const String usersEndpoint = '/users.php';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'current_user';
  static const String themeKey = 'app_theme';
  static const String languageKey = 'app_language';
  
  // Default Values
  static const int defaultTimeout = 30; // seconds
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100MB
  
  // Course Constants
  static const List<String> courseSubjects = [
    '數學',
    '程式設計',
    '語言學習',
    '藝術設計',
    '科學',
    '商業',
    '音樂',
    '體育',
  ];
  
  static const List<String> courseLevels = [
    '初級',
    '中級',
    '高級',
    '專家級',
  ];
  
  static const List<String> weekDays = [
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];
}

class UserRoles {
  static const String student = 'student';
  static const String teacher = 'teacher';
  static const String admin = 'admin';
}

class CourseStatus {
  static const String draft = 'draft';
  static const String published = 'published';
  static const String archived = 'archived';
}

class OrderStatus {
  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String cancelled = 'cancelled';
  static const String refunded = 'refunded';
}