import 'package:flutter/material.dart';
import '../../models/course.dart';
import 'course_card.dart';

class CourseGrid extends StatelessWidget {
  final List<Course> courses;
  final Function(Course) onCourseTap;
  final Function(Course)? onBookmark;
  final bool showBookmark;

  const CourseGrid({
    super.key,
    required this.courses,
    required this.onCourseTap,
    this.onBookmark,
    this.showBookmark = true,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        return CourseCard(
          course: course,
          onTap: () => onCourseTap(course),
          onBookmark: onBookmark != null ? () => onBookmark!(course) : null,
          showBookmark: showBookmark,
        );
      },
    );
  }
}