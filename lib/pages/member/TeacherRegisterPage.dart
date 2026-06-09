import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/user_api_service.dart';
import '../../services/course_api_service.dart';
import '../../main.dart'; // 確保導向 HomeScreen 使用
import '../teacher/video_upload_page.dart';

class TeacherRegisterPage extends StatefulWidget {
  const TeacherRegisterPage({super.key});

  @override
  State<TeacherRegisterPage> createState() => _TeacherRegisterPageState();
}

class _TeacherRegisterPageState extends State<TeacherRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _introController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  List<dynamic> _categories = [];
  final Set<String> _selectedCateIds = {};

  @override
  void initState() {
    super.initState();
    // 預填當前學生的用戶名
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    _nameController.text = user?.name ?? "";
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final items = await CourseApiService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = items;
        _isLoadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = [];
        _isLoadingCategories = false;
      });
    }
  }

  String _categoryLabel(Map item) {
    final locale = Localizations.localeOf(context).toString();
    if (locale.startsWith('zh_CN')) return (item['nameSC'] ?? '').toString();
    if (locale.startsWith('zh_HK') || locale.startsWith('zh_TW')) {
      return (item['nameTC'] ?? '').toString();
    }
    if (locale.startsWith('zh')) return (item['nameTC'] ?? '').toString();
    return (item['nameE'] ?? '').toString();
  }

  // --- 關鍵修正：提交申請並立即切換身份 ---
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoadingCategories) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('科目資料載入中，請稍候')));
      return;
    }
    if (_selectedCateIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先選擇至少一個擅長科目')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final studentMid = userProvider.currentUser!.memberId;

      final introVideoPath = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => VideoUploadPage(
            memberId: studentMid,
            courseId: '',
            lessonId: '',
            lessonName: '導師自我介紹影片',
            isCourseIntro: true,
            minDurationSeconds: 30,
            maxDurationSeconds: 300,
            skipDbUpdate: true,
            autoPopOnCompleted: true,
          ),
        ),
      );

      if (introVideoPath == null || introVideoPath.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('尚未完成介紹影片上傳')));
        return;
      }

      // 1. 調用 API (確保你的 PHP 會回傳 data 欄位，內含完整老師資料)
      final result = await UserApiService.registerAsTeacher(
        studentMid: studentMid,
        username: _nameController.text.trim(),
        selfIntro: _introController.text.trim(),
        introVideoPath: introVideoPath,
        cateIds: _selectedCateIds.toList(),
      );

      if (result['status'] == 'success') {
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        // 1. 取得 PHP 回傳的 data (裡面有完整的老師資料)
        final teacherData = result['data'];

        // 2. 💡 使用我們剛剛寫的強制更新方法
        userProvider.updateAfterTeacherRegistration(teacherData);

        if (!mounted) return;

        // 3. 提示並跳轉
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("開通成功！已自動切換至老師身分")));

        // 跳轉回首頁，這時 Provider 已經有值，MemberPage 再次進入時就會顯示「切換」
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        throw Exception(result['message'] ?? "提交失敗");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("錯誤: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("成為導師"),
        backgroundColor: Colors.grey[900],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "導師名稱",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("請輸入您的教學名稱"),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? "請輸入名稱" : null,
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "自我介紹",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _introController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: _inputDecoration("請簡短介紹您的教學背景或專長"),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? "請輸入自我介紹" : null,
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "擅長科目（可多選）",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingCategories)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: CircularProgressIndicator(color: Colors.amber),
                        ),
                      )
                    else if (_categories.isEmpty)
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '無法載入科目列表',
                              style: TextStyle(color: Colors.white38),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadCategories,
                            child: const Text(
                              '重試',
                              style: TextStyle(color: Colors.amber),
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.whereType<Map>().map((c) {
                          final id = (c['cateId'] ?? '').toString();
                          final label = _categoryLabel(c).trim();
                          final selected = _selectedCateIds.contains(id);
                          return FilterChip(
                            selected: selected,
                            label: Text(
                              label.isEmpty ? id : label,
                              style: TextStyle(
                                color: selected ? Colors.black : Colors.white70,
                              ),
                            ),
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  if (id.isNotEmpty) _selectedCateIds.add(id);
                                } else {
                                  _selectedCateIds.remove(id);
                                }
                              });
                            },
                            selectedColor: Colors.amber,
                            backgroundColor: Colors.grey[900],
                            side: const BorderSide(color: Colors.white10),
                            showCheckmark: false,
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),

                    const Text(
                      "自我介紹影片 (必填)",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '按「立即開通導師身份」後才會開始選擇並上傳影片（30 秒～5 分鐘）',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: const Text(
                          "立即開通導師身份",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        "註冊即代表同意導師服務條款",
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
      filled: true,
      fillColor: Colors.grey[900],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amber, width: 1.5),
      ),
    );
  }
}
