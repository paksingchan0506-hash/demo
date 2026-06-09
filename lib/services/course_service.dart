import '../models/course.dart';

class CourseService {
  static final CourseService _instance = CourseService._internal();
  factory CourseService() => _instance;
  CourseService._internal();

  Future<List<Course>> getBookmarkedCourses() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return sampleCourses.where((course) => course.isBookmarked).toList();
  }

  Future<void> toggleBookmark(Course course) async {
    await Future.delayed(const Duration(milliseconds: 300));
    course.isBookmarked = !course.isBookmarked;
  }

  Future<List<Course>> searchCourses(String query) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return sampleCourses
        .where(
          (course) => course.title.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }
}
