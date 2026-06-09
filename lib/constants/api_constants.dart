class ApiConstants {
  // Base URL
  static const String baseUrl = 'http://3.25.85.107/mysqlconnect';
  
  // Endpoints
  static const String login = '/Member.php';
  static const String register = '/Member.php';
  static const String users = '/Member.php';
  static const String courses = '/courses.php';
  static const String bookmarks = '/bookmarks.php';
  static const String orders = '/orders.php';
  
  // Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Response Codes
  static const int success = 200;
  static const int created = 201;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int serverError = 500;
  
  // Error Messages
  static const String networkError = '網絡連接錯誤，請檢查您的網絡連接';
  static const String serverErrorMessage = '服務器錯誤，請稍後再試';
  static const String timeoutError = '請求超時，請檢查您的網絡連接';
  static const String unknownError = '未知錯誤，請稍後再試';
  
  // Timeouts
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
}

class ApiEndpoints {
  static String getUsers() => '${ApiConstants.baseUrl}${ApiConstants.users}';
  static String login() => '${ApiConstants.baseUrl}${ApiConstants.login}';
  static String register() => '${ApiConstants.baseUrl}${ApiConstants.register}';
  static String getCourses() => '${ApiConstants.baseUrl}${ApiConstants.courses}';
  static String getCourse(String id) => '${ApiConstants.baseUrl}${ApiConstants.courses}?id=$id';
  static String createCourse() => '${ApiConstants.baseUrl}${ApiConstants.courses}';
  static String updateCourse(String id) => '${ApiConstants.baseUrl}${ApiConstants.courses}?id=$id';
  static String deleteCourse(String id) => '${ApiConstants.baseUrl}${ApiConstants.courses}?id=$id';
}