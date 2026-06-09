import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../auth/login_page.dart';
import 'bookmark_page.dart';
import 'order_history_page.dart';
import 'change_info_page.dart';
import 'change_password_page.dart';
import 'points_page.dart';
import '../notification/notifications_page.dart';
import 'withdrawal_page.dart';
import '../../services/user_api_service.dart';
import 'TeacherRegisterPage.dart';
import '../onboarding/onboarding_video_page.dart'; // ★ 新增 import

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  @override
  void initState() {
    super.initState();
    // 進入會員中心時，自動刷新積分與檢查身份關聯狀態
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.isLoggedIn) {
        await userProvider.syncPointsWithDb();
        await userProvider.refreshUserInfo();
        await userProvider.checkIdentityRelation();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;

    // 關鍵判斷：是否已經有老師帳號（用於顯示切換按鈕）
    bool isAlreadyTeacher = userProvider.hasTeacherAccount;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('會員中心'),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsPage(),
                ),
              );
            },
          ),
       ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 用戶基本資訊區 ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    color: Colors.purple[700],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      UserApiService.getFullImageUrl(currentUser?.avatar),
                      width: 75,
                      height: 75,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[900],
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.person,
                          size: 45,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser?.name ?? '載入中...',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.purpleAccent.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          '會員號碼: ${currentUser?.memberId ?? '---'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.purpleAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // --- 導師數據區塊 (只有身分是 T 時顯示) ---
                      if (currentUser?.mType == 'T') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildTeacherStat(
                                Icons.star,
                                (currentUser?.avgRating ?? 0.0).toStringAsFixed(
                                  1,
                                ),
                                '導師評分',
                                Colors.orangeAccent,
                              ),
                              _buildTeacherStat(
                                Icons.favorite,
                                '${currentUser?.tBookCount ?? 0}',
                                '收藏',
                                Colors.pinkAccent,
                              ),
                              _buildTeacherStat(
                                Icons.workspace_premium,
                                'Lv.${currentUser?.teacherLevel ?? 1}',
                                '等級',
                                Colors.amber,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 積分卡片
            _buildPointsCard(context),
            if (currentUser?.mType == 'S') ...[
              const SizedBox(height: 24),
              const Text(
                '我的課程',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              _buildMenuButton(
                icon: Icons.history,
                title: '查看所有課程',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrderHistoryPage(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text(
              '個人設定',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            // 選項列表
            Expanded(
              child: ListView(
                children: [
                  if (currentUser?.mType == 'S') ...[
                  _buildOption(
                    context: context,
                    title: "我的收藏",
                    icon: Icons.bookmark_border,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BookmarkPage(),
                        ),
                      ),
                    ),
                  ],
                  if (currentUser?.mType == 'T')
                  _buildOption(
                    context: context,
                    title: "收益提款",
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WithdrawalPage()),
                    ),
                  ),

                  // --- 關鍵：根據是否有老師帳號，顯示「切換」或「申請」 ---
                  if (isAlreadyTeacher)
                    _buildOption(
                      context: context,
                      title: currentUser?.mType == 'S' ? "切換至教師身分" : "切換至學生身分",
                      icon: Icons.published_with_changes,
                      onTap: () async {
                        await userProvider.toggleUserType();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已成功切換身分'),
                              backgroundColor: Colors.purpleAccent,
                            ),
                          );
                        }
                      },
                      
                    )
                  else
                    _buildOption(
                      context: context,
                      title: "申請成為導師",
                      icon: Icons.school_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TeacherRegisterPage(),
                        ),
                      ),
                    ),
                  _buildOption(
                    context: context,
                    title: "更改個人資訊",
                    icon: Icons.edit_note,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangeInformationPage(),
                      ),
                    ),
                  ),
                  _buildOption(
                    context: context,
                    title: "修改密碼",
                    icon: Icons.lock_outline,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage(),
                      ),
                    ),
                  ),
                  _buildOption(
                    context: context,
                    title: "積分與獎勵",
                    icon: Icons.card_giftcard,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PointsPage(),
                      ),
                    ),
                  ),
                  // ★ 新增：重看新手引導影片（訪客不顯示）
                  if (currentUser != null && currentUser.userType != 'guest')
                    _buildOption(
                      context: context,
                      title: "重看新手引導影片",
                      icon: Icons.ondemand_video_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OnboardingVideoPage(
                            userId: currentUser.id,
                            isReplay: true, // 重播模式：看完後 pop 返回，不重新標記
                          ),
                        ),
                      ),
                    ),
                  _buildOption(
                    context: context,
                    title: "登出帳號",
                    icon: Icons.logout,
                    onTap: () => _showLogoutDialog(context, userProvider),
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 輔助組件：查看所有課程按鈕
  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white70)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PointsPage()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[900]!, Colors.purple[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const Icon(Icons.stars, color: Colors.orangeAccent, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '我的積分',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  Text(
                    '${userProvider.currentUser?.points ?? 0} PTS',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : Colors.purpleAccent,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : Colors.white,
          fontSize: 16,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white24,
        size: 20,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildTeacherStat(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('確定登出？', style: TextStyle(color: Colors.white)),
        content: const Text(
          '登出後需要重新登入才能使用會員功能。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              await userProvider.logout();
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text(
              '確定登出',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
