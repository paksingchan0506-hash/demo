import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/user_api_service.dart';
import '../../services/course_api_service.dart';
import '../../services/aws_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../course/video_player_page.dart';
import '../teacher/video_upload_page.dart';

class ChangeInformationPage extends StatefulWidget {
  const ChangeInformationPage({super.key});

  @override
  State<ChangeInformationPage> createState() => _ChangeInformationPageState();
}

class _ChangeInformationPageState extends State<ChangeInformationPage> {
  static const MethodChannel _nsfwChannel = MethodChannel(
    'com.example.realvideo/processor',
  );
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  final _introController = TextEditingController();

  String? _selectedGender;
  bool _isLoading = false;
  File? _tempImageFile;
  String? _networkAvatar;
  final ImagePicker _picker = ImagePicker();
  bool _isAvatarDeleted = false;
  bool _isLoadingCategories = false;
  List<dynamic> _categories = [];
  final Set<String> _selectedCateIds = {};
  bool _isUpdatingIntroVideo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser?.mType == 'T') {
      await userProvider.refreshUserInfo();
    }
    if (!mounted) return;
    _loadInitialData();
    await _hydrateTeacherCateIdsFallback();
  }

  Future<void> _hydrateTeacherCateIdsFallback() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    if (user == null || user.mType != 'T') return;
    if (_selectedCateIds.isNotEmpty) return;

    try {
      final mentor = await CourseApiService.getMentorDetail(user.memberId);
      final rawIds = mentor['cateIds'];
      if (rawIds is! List) return;
      final ids = rawIds
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (ids.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _selectedCateIds
          ..clear()
          ..addAll(ids);
      });
      await userProvider.updateProfileLocal(teacherCateIds: ids);
    } catch (_) {}
  }

  void _loadInitialData() {
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user != null) {
      setState(() {
        _nameController.text = user.name ?? '';
        _telController.text = user.tel ?? '';
        _emailController.text = user.email ?? '';
        _introController.text = user.selfIntro ?? '';
        _networkAvatar = user.avatar; // 這裡存的是資料庫相對路徑
        _selectedGender =
            (user.gender == 'M' || user.gender == 'F' || user.gender == 'O')
            ? user.gender
            : null;
        _selectedCateIds
          ..clear()
          ..addAll(user.teacherCateIds);
      });
    }
    if (user?.mType == 'T') {
      _loadCategories();
    }
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

  String _dirOf(String path) {
    final idx = path.lastIndexOf('/');
    if (idx <= 0) return '';
    return path.substring(0, idx);
  }

  Future<void> _changeTeacherIntroVideo() async {
    if (_isUpdatingIntroVideo) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    if (user == null) return;

    if (_selectedCateIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先選擇至少一個擅長科目')));
      return;
    }

    final oldPath = (user.selfIntroVideo ?? '').toString();

    final newPath = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => VideoUploadPage(
          memberId: user.memberId,
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

    if (!mounted) return;
    if (newPath == null || newPath.trim().isEmpty) return;

    setState(() => _isUpdatingIntroVideo = true);
    try {
      final res = await UserApiService.updateTeacherMeta(
        teacherId: user.memberId,
        introVideoPath: newPath,
        cateIds: _selectedCateIds.toList(),
      );
      if (res['status'] != 'success') {
        throw res['message'] ?? '更新失敗';
      }

      if (oldPath.trim().isNotEmpty && oldPath.trim() != newPath.trim()) {
        final prefix = _dirOf(oldPath.trim());
        if (prefix.isNotEmpty) {
          try {
            await AWSService.deleteDirectory(prefix);
          } catch (_) {}
        }
      }

      await userProvider.refreshUserInfo();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('介紹影片已更新')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('錯誤: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingIntroVideo = false);
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('從相簿選擇', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  setState(() {
                    _tempImageFile = File(image.path);
                    _isAvatarDeleted = false;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text(
                '刪除目前頭像',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _tempImageFile = null;
                  _networkAvatar = null;
                  _isAvatarDeleted = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      if (_tempImageFile != null) {
        try {
          final double? score = await _nsfwChannel.invokeMethod<double>(
            'checkNsfw',
            {'inputPath': _tempImageFile!.path},
          );
          if (score != null && score >= 0.7) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('頭像檢測到18+內容，請更換圖片')));
            }
            return;
          }
        } catch (_) {}
      }

      final result = await UserApiService.updateProfileMultipart(
        mId: userProvider.currentUser!.memberId,
        username: _nameController.text,
        tel: _telController.text,
        email: _emailController.text, // 傳送 email
        gender: _selectedGender ?? '',
        selfIntro: _introController.text, // 傳送自我介紹
        imageFile: _tempImageFile,
        deleteAvatar: _isAvatarDeleted,
      );

      if (result['status'] == 'success') {
        if (userProvider.currentUser?.mType == 'T') {
          if (_selectedCateIds.isEmpty) {
            throw '請選擇至少一個擅長科目';
          }
          final metaRes = await UserApiService.updateTeacherMeta(
            teacherId: userProvider.currentUser!.memberId,
            cateIds: _selectedCateIds.toList(),
          );
          if (metaRes['status'] != 'success') {
            throw metaRes['message'] ?? '更新擅長科目失敗';
          }
        }
        await userProvider.updateProfileLocal(
          username: _nameController.text,
          email: _emailController.text,
          tel: _telController.text,
          gender: _selectedGender,
          selfIntro: _introController.text,
          avatar: _isAvatarDeleted ? null : userProvider.currentUser?.avatar,
          teacherCateIds: _selectedCateIds.toList(),
        );
        await userProvider.refreshUserInfo();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('更新成功')));
          Navigator.pop(context);
        }
      } else {
        throw result['message'] ?? '更新失敗';
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('錯誤: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;

    final Widget avatarContent;
    if (_tempImageFile != null) {
      avatarContent = ClipOval(
        child: Image.file(
          _tempImageFile!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } else {
      avatarContent = ClipOval(
        child: Image.network(
          UserApiService.getFullImageUrl(_networkAvatar),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 100,
            height: 100,
            color: Colors.grey[850],
            alignment: Alignment.center,
            child: const Icon(Icons.person, size: 50, color: Colors.white24),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('修改個人資訊'),
        backgroundColor: Colors.grey[900],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Center(
              child: GestureDetector(
                onTap: _showAvatarOptions,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[800], // 預設背景色
                  child: avatarContent,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildLabel("基本資訊"),
            AppTextField(controller: _nameController, labelText: '用戶網名'),
            const SizedBox(height: 16),

            // 1. 補回 Email 輸入框 (不論學生或老師都應該有)
            AppTextField(
              controller: _emailController,
              labelText: '電子郵件 (Email)',
            ),
            const SizedBox(height: 16),

            AppTextField(controller: _telController, labelText: '聯絡電話'),
            const SizedBox(height: 16),

            // 2. 補回 導師自我介紹 (判斷當前用戶是否為老師)
            if (Provider.of<UserProvider>(context).currentUser?.mType ==
                'T') ...[
              _buildLabel("導師自我介紹"),
              AppTextField(
                controller: _introController,
                labelText: '介紹一下你自己...',
                maxLines: 5, // 讓自我介紹的框大一點，方便輸入
              ),
              const SizedBox(height: 16),

              _buildLabel("擅長科目（可多選）"),
              if (_isLoadingCategories)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: CircularProgressIndicator(
                      color: Colors.purpleAccent,
                    ),
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
                        style: TextStyle(color: Colors.purpleAccent),
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
                      selectedColor: Colors.purpleAccent,
                      backgroundColor: Colors.grey[900],
                      side: const BorderSide(color: Colors.white10),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),

              _buildLabel("導師介紹影片"),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.purpleAccent,
                      ),
                      title: const Text(
                        '觀看介紹影片',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        (user?.selfIntroVideo ?? '').toString().trim().isEmpty
                            ? '尚未設定'
                            : '點擊播放',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white30,
                      ),
                      onTap:
                          (user?.selfIntroVideo ?? '').toString().trim().isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VideoPlayerPage(
                                    videoUrl: user!.selfIntroVideo!,
                                    lessonTitle: '導師自我介紹影片',
                                  ),
                                ),
                              );
                            },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isUpdatingIntroVideo
                              ? null
                              : _changeTeacherIntroVideo,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            _isUpdatingIntroVideo ? '更新中...' : '更換影片',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            _buildLabel("性別"),
            _buildGenderPicker(),
            const SizedBox(height: 40),
            AppButton(
              text: '儲存所有修改',
              onPressed: _handleSave,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.purpleAccent,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  );

  Widget _buildGenderPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white),
          items: const [
            DropdownMenuItem(value: "M", child: Text("男")),
            DropdownMenuItem(value: "F", child: Text("女")),
            DropdownMenuItem(value: "O", child: Text("其他")),
          ],
          onChanged: (val) => setState(() => _selectedGender = val),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _introController.dispose();
    super.dispose();
  }
}
