import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'EDU';
  static const String appVersion = '1.0.0';
  
  // Colors - 這些必須放在 AppConstants 類別的大括號裡面
  static const Color primaryColor = Color(0xFF6A1B9A);
  static const Color secondaryColor = Color(0xFF9C27B0);
  static const Color backgroundColor = Color(0xFF000000);
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color textColor = Color(0xFFFFFFFF);
  static const Color textSecondaryColor = Color(0xFF9E9E9E);
  
  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  // Border Radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  
  // Animation Durations
  static const Duration animationShort = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationLong = Duration(milliseconds: 500);
} // 這是 AppConstants 的結束點

class UserType {
  static const String student = 'student';
  static const String teacher = 'teacher';
}

class CourseType {
  static const String math = '數學';
  static const String programming = '程式設計';
  static const String language = '語言學習';
  static const String art = '藝術設計';
  static const String science = '科學';
  static const String business = '商業';
  static const String music = '音樂';
  static const String sports = '體育';
}
// 這裡不要再放任何 static const 變數了