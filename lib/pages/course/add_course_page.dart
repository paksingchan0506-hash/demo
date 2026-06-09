import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';

class AddCoursePage extends StatefulWidget {
  const AddCoursePage({super.key});

  @override
  _AddCoursePageState createState() => _AddCoursePageState();
}

class _AddCoursePageState extends State<AddCoursePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _courseTitleController = TextEditingController();
  final TextEditingController _courseDescriptionController =
      TextEditingController();
  final TextEditingController _totalLessonsController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String? _selectedSubject;
  String _selectedLanguage = '粵語';

  final List<String> _fallbackSubjects = [
    '數學',
    '程式設計',
    '語言學習',
    '藝術設計',
    '科學',
    '商業',
    '音樂',
    '體育',
  ];
  List<String> _subjects = [];
  Map<String, String> _subjectToCategoryId = {};
  bool _isLoadingCategories = true;

  final Map<String, String> _languages = {
    '粵語': 'Lg000002',
    '普通話': 'Lg000003',
    '英文': 'Lg000001',
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await ApiService.getCategories();
      final categories = (res['categories'] as List?) ?? [];

      final Map<String, String> map = {};
      final List<String> names = [];
      for (final c in categories) {
        final name = (c['cateNameTC'] ?? '').toString();
        final id = (c['cateId'] ?? '').toString();
        if (name.isNotEmpty && id.isNotEmpty) {
          map[name] = id;
          names.add(name);
        }
      }

      setState(() {
        _subjectToCategoryId = map;
        _subjects = names.isNotEmpty ? names : _fallbackSubjects;
        _selectedSubject ??= _subjects.isNotEmpty ? _subjects.first : null;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _subjects = _fallbackSubjects;
        _selectedSubject ??= _subjects.first;
        _subjectToCategoryId = {
          '數學': 'Cy000002',
          '程式設計': 'Cy000004',
          '語言學習': 'Cy000001',
          '藝術設計': 'Cy000003',
          '科學': 'Cy000002',
          '商業': 'Cy000004',
          '音樂': 'Cy000003',
          '體育': 'Cy000003',
        };
        _isLoadingCategories = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('新增課程', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(
                controller: _courseTitleController,
                label: '課程標題',
                hintText: '輸入課程名稱',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入課程標題';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _isLoadingCategories
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '科目',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.purpleAccent,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _buildDropdown(
                      label: '科目',
                      value: _selectedSubject ?? _subjects.first,
                      items: _subjects,
                      onChanged: (value) {
                        setState(() {
                          _selectedSubject = value;
                        });
                      },
                    ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: '課程語言',
                value: _selectedLanguage,
                items: _languages.keys.toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildTextArea(
                controller: _courseDescriptionController,
                label: '課程描述',
                hintText: '詳細描述課程內容、教學目標等',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入課程描述';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _totalLessonsController,
                label: '總堂數',
                hintText: '輸入課程總共堂數',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入總堂數';
                  }
                  if (int.tryParse(value) == null) {
                    return '請輸入有效的數字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _priceController,
                label: '課程價格',
                hintText: '輸入課程價格',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入課程價格';
                  }
                  if (double.tryParse(value) == null) {
                    return '請輸入有效的價格';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.purpleAccent,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _saveCourse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '建立課程',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  void _saveCourse() async {
    if (_formKey.currentState!.validate() && !_isLoading) {
      if (_isLoadingCategories) return;
      if (_selectedSubject == null || _selectedSubject!.isEmpty) return;

      setState(() {
        _isLoading = true;
      });

      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final currentUser = userProvider.currentUser;

        if (currentUser == null) {
          throw Exception('用戶未登錄');
        }

        final categoryId = _subjectToCategoryId[_selectedSubject] ?? 'Cy000004';
        final languageId = _languages[_selectedLanguage] ?? 'Lg000002';

        final response = await ApiService.createCourse(
          courseName: _courseTitleController.text,
          unitPrice: double.parse(_priceController.text),
          summary: _courseDescriptionController.text,
          totalLesson: int.parse(_totalLessonsController.text),
          categoryId: categoryId,
          teacherId: currentUser.id,
          languageId: languageId,
        );

        if (response['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                '課程 "${_courseTitleController.text}" 已成功建立！',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
          Navigator.pop(context);
        } else {
          throw Exception(response['message'] ?? '創建課程失敗');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              '創建課程失敗: ${e.toString()}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _courseTitleController.dispose();
    _courseDescriptionController.dispose();
    _totalLessonsController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}
