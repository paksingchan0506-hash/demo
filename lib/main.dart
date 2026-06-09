import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'config/admob_config.dart';
import 'services/rank_api_service.dart';
import 'services/rank_provider.dart';
import 'package:flutter/gestures.dart';
import 'pages/course/course_page.dart';
import 'pages/course/mentor_detail_page.dart';

// 1. 確保這些 Provider 和 Page 的路徑與你專案一致
import 'providers/user_provider.dart';
import 'providers/course_provider.dart';
import 'pages/auth/login_page.dart';
import 'pages/course/course_suggestion_page.dart';
import 'pages/teacher/teacher_course_page.dart';
import 'pages/member/member_page.dart';
import 'pages/auth/auth_guard.dart';
import 'pages/member/bookmark_page.dart'; // 新增收藏頁匯入
import 'services/course_api_service.dart';
import 'services/user_api_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 1. 引入這個

// 新增購買紀錄匯入
import 'pages/notification/notifications_page.dart';

// ★ 新增 Firebase 匯入 (第一行)
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ★ 新增 Firebase 初始化 (第二行)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase 初始化失敗: $e');
  }
  
  // 1. 設定螢幕方向（非同步不等待）
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );

  // 2. 核心修正：加入 kIsWeb 判斷，避免在 Chrome 執行廣告代碼
  if (!kIsWeb) {
    try {
      // 設定測試裝置
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: AdMobConfig.testDeviceIds),
      );
      
      // 初始化 AdMob
      final initStatus = await MobileAds.instance.initialize();
      
      // 列印初始化狀態 (Debug 用)
      for (final entry in initStatus.adapterStatuses.entries) {
        debugPrint(
          'Ads adapter ${entry.key}: ${entry.value.state} ${entry.value.description}',
        );
      }
    } catch (e) {
      debugPrint('AdMob 初始化失敗: $e');
    }
  } else {
    debugPrint('目前為 Web 平台，跳過廣告初始化');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => RankProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.purple, // 原有設計
        colorScheme: const ColorScheme.dark(primary: Colors.purple),
        scaffoldBackgroundColor: Colors.black, // 原有設計
      ),
      // 核心修正：根據登入狀態判斷首頁
      home: !userProvider.isInitialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : userProvider.isLoggedIn
          ? const HomeScreen()
          : const LoginPage(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    if ((index == 2 || index == 3) && !AuthGuard.check(context)) return;

    if (index == 2) {
      Provider.of<UserProvider>(context, listen: false).clearUnread();
    }

    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    // --- 核心邏輯：動態決定「課程」分頁顯示什麼 ---
    Widget courseTab;
    String courseLabel;

    if (user?.mType == 'T') {
      // 如果目前是老師身份
      courseTab = const TeacherCoursePage(); // 顯示老師的課程管理頁
      courseLabel = '教學管理';
    } else {
      // 如果目前是學生身份
      courseTab = const CourseSuggestionPage(); // 顯示學生的選課頁
      courseLabel = '課程';
    }

    final List<Widget> pages = [
      const HomeContent(),
      courseTab, // 動態分頁
      const NotificationsPage(),
      const MemberPage(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D0D),
            border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.home_filled, '首頁', 0, 0),
              _buildBottomNavItem(
                user?.mType == 'T' ? Icons.assignment_ind : Icons.auto_stories,
                courseLabel,
                1,
                0,
              ),
              _buildBottomNavItem(
                Icons.notifications,
                '通知',
                2,
                userProvider.unreadCount,
              ),
              _buildBottomNavItem(Icons.person, '帳戶', 3, 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    IconData icon,
    String label,
    int index,
    int unreadCount,
  ) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 增加點擊範圍
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.purpleAccent : Colors.grey,
                  size: 26,
                ),
                // 紅點顯示邏輯
                if (unreadCount > 0)
                  Positioned(
                    right: -5,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.black,
                          width: 1.5,
                        ), // 加個邊框更好看
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.purpleAccent : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 以下完全保留您提供的 HomeContent 代碼，包含自動廣告和排行榜 ---

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});
  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _adController;
  int _currentAdPage = 0;
  Timer? _adTimer;

  final List<String> _adImages = [
    'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800',
    'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800',
    'https://images.unsplash.com/photo-1501504905252-473c47e087f8?w=800',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _adController = PageController();

    // 初始化 API 數據抓取
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RankProvider>(context, listen: false).fetchRankings();
    });

    _adTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_adController.hasClients) {
        _currentAdPage = (_currentAdPage + 1) % _adImages.length;
        _adController.animateToPage(
          _currentAdPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adTimer?.cancel();
    _adController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rankProvider = Provider.of<RankProvider>(context);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: true,
          backgroundColor: Colors.black,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('assets/eduicon.png', fit: BoxFit.contain),
          ),
          title: const Text(
            'EDU ONLINE',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, size: 28),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsPage(),
                          ),
                        );
                      },
                    ),
                    if (userProvider.unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${userProvider.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAutoAds(),
              // 調用排行榜
              _buildNetflixSection("熱門課程", "course", rankProvider),
              _buildNetflixSection("熱門導師", "teacher", rankProvider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoAds() {
    return Container(
      height: 180,
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            PageView.builder(
              controller: _adController,
              itemCount: _adImages.length,
              onPageChanged: (index) => setState(() => _currentAdPage = index),
              itemBuilder: (context, index) =>
                  Image.network(_adImages[index], fit: BoxFit.cover),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _adImages.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentAdPage == i
                          ? Colors.purpleAccent
                          : Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetflixSection(
    String title,
    String type,
    RankProvider provider,
  ) {
    List<dynamic> list = (type == "course")
        ? provider.topCourses
        : provider.topTeachers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 20, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        // 💡 必須有高度限制
        SizedBox(
          height: 240,
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal, // 💡 關鍵：改為橫向滑動
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return _buildNetflixCard(
                      index + 1,
                      item['name'] ?? '',
                      item['imageUrl'] ?? '',
                      // --- 新增以下參數 ---
                      item['id'].toString(),
                      type,
                      // ------------------
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNetflixCard(
    int rank,
    String name,
    String imageUrl,
    String id,
    String type,
  ) {
    // 為了防止非法字元導致 Image.network 崩潰，先取得完整 URL，並進行清理與編碼
    final rawUrl = type == 'course'
        ? CourseApiService.getFullImageUrl(imageUrl)
        : UserApiService.getFullImageUrl(imageUrl);
    
    final cleanUrl = rawUrl.trim().replaceAll('\n', '').replaceAll('\r', '');
    final uri = Uri.tryParse(cleanUrl) ?? Uri.parse(Uri.encodeFull(cleanUrl));
    final safeUrlString = uri.toString();

    return GestureDetector(
      onTap: () {
        if (type == "course") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoursePage(courseId: id, courseTitle: name),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MentorDetailPage(mId: id)),
          );
        }
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 數字背景
                  Positioned(
                    left: -5,
                    bottom: -10,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.15),
                        letterSpacing: -5,
                      ),
                    ),
                  ),
                  // 圖片容器
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey[900],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        safeUrlString,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('圖片載入失敗: $safeUrlString, 錯誤: $error');
                          return Container(
                            color: Colors.grey[900],
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.white24,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 35),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}