class Course {
  final String id;
  final String title;
  final String type;
  final String instructor;
  final double rating;
  final int purchased;
  final String nextClass;
  final String description;
  final String subject;
  final double nsfwScore;
  final String auditStatus;
  bool isBookmarked;
  final bool isDeleted;

  Course({
    required this.id,
    required this.title,
    required this.type,
    required this.instructor,
    required this.rating,
    required this.purchased,
    required this.nextClass,
    required this.description,
    required this.subject,
    this.nsfwScore = 0.0,
    this.auditStatus = 'approved',
    this.isBookmarked = false,
    this.isDeleted = false,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? json['cId'] ?? '',
      title: json['title'] ?? json['cName'] ?? '',
      type: json['type'] ?? json['cateNameTC'] ?? '',
      instructor: json['instructor'] ?? '我自己',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      purchased: (json['purchased'] as num?)?.toInt() ?? 0,
      nextClass: json['nextClass'] ?? '',
      description: json['description'] ?? json['summary'] ?? '',
      subject: json['subject'] ?? json['cateNameTC'] ?? '',
      nsfwScore: (json['nsfwScore'] as num?)?.toDouble() ?? 0.0,
      auditStatus: (json['auditStatus'] ?? 'approved').toString(),
      isDeleted: json['is_deleted'] == 1 || json['is_deleted'] == true,
    );
  }
}

// 示例课程列表
final List<Course> sampleCourses = [
  Course(
    id: '1',
    title: 'Course 1',
    type: 'Type A',
    instructor: 'Teacher A',
    rating: 4.5,
    purchased: 50,
    nextClass: '2023/10/20',
    description: 'This is course 1 description',
    subject: '數學',
  ),
  Course(
    id: '2',
    title: 'Course 2',
    type: 'Type B',
    instructor: 'Teacher B',
    rating: 4.3,
    purchased: 30,
    nextClass: '2023/10/22',
    description: 'This is course 2 description',
    subject: '程式設計',
  ),
  Course(
    id: '3',
    title: 'Course 3',
    type: 'Type C',
    instructor: 'Teacher C',
    rating: 4.7,
    purchased: 20,
    nextClass: '2023/10/25',
    description: 'This is course 3 description',
    subject: '語言學習',
  ),
];
