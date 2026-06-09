import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';

class OnboardingVideoPage extends StatefulWidget {
  final String userId;
  final bool isReplay;

  const OnboardingVideoPage({
    super.key,
    required this.userId,
    this.isReplay = false,
  });

  @override
  State<OnboardingVideoPage> createState() => _OnboardingVideoPageState();
}

class _OnboardingVideoPageState extends State<OnboardingVideoPage> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isFinishing = false;

  // 判斷目前平台是否支援 video_player
  // video_player 只支援 Android / iOS / Web / macOS，不支援 Windows / Linux
  bool get _isPlatformSupported {
    if (kIsWeb) return true;
    try {
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  // ★ 更新後的 URL（已移除空格）
  static const String _videoUrl =
      'https://fypedu.s3.ap-southeast-2.amazonaws.com/app_begin_video/'
      'AnonymousEDU%E6%96%B0%E6%89%8B%E5%BC%95%E5%B0%8E%E5%BD%B1%E7%89%87_720p_caption.mp4';

  @override
  void initState() {
    super.initState();
    if (_isPlatformSupported) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(_videoUrl));
    try {
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      _controller = ctrl;
      _controller!.addListener(_onVideoProgress);
      setState(() => _isInitialized = true);
      _controller!.play();
    } catch (e) {
      debugPrint('OnboardingVideo init error: $e');
      ctrl.dispose();
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onVideoProgress() {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (!ctrl.value.isPlaying &&
        ctrl.value.position >= ctrl.value.duration &&
        ctrl.value.duration > Duration.zero &&
        !_isFinishing) {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    if (_isFinishing) return;
    _isFinishing = true;

    if (!widget.isReplay) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('intro_watched_${widget.userId}', true);
    }

    if (!mounted) return;

    if (widget.isReplay) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: !_isPlatformSupported
                  ? _buildPlatformNotSupportedView()
                  : _hasError
                      ? _buildErrorView()
                      : !_isInitialized
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.purpleAccent,
                              ),
                            )
                          : _buildVideoPlayer(),
            ),
            if (_isPlatformSupported && _isInitialized && !_hasError)
              _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline,
                  color: Colors.purpleAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                widget.isReplay ? '重看新手引導' : '歡迎！新手引導',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _finishOnboarding,
            child: Text(
              widget.isReplay ? '關閉' : '跳過',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          VideoProgressIndicator(
            _controller!,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.purpleAccent,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white10,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller!,
            builder: (context, value, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.purpleAccent,
                      size: 48,
                    ),
                    onPressed: () {
                      value.isPlaying
                          ? _controller!.pause()
                          : _controller!.play();
                    },
                  ),
                ],
              );
            },
          ),
          if (widget.isReplay) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _finishOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  '完成觀看',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Windows / Linux 不支援 video_player 時顯示此提示頁面
  Widget _buildPlatformNotSupportedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android,
                color: Colors.purpleAccent, size: 64),
            const SizedBox(height: 24),
            const Text(
              '新手引導影片',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '影片播放目前僅支援手機端（Android / iOS）。\n請在手機上觀看新手引導影片。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white54, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _finishOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  widget.isReplay ? '返回' : '繼續使用',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 影片加載失敗的 UI
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 52),
          const SizedBox(height: 16),
          const Text(
            '影片加載失敗',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            '請檢查網絡連線後重試',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _finishOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              '跳過，繼續使用',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}