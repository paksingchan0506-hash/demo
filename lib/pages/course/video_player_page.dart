import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/aws_service.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String lessonTitle;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    required this.lessonTitle,
  });

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _isBuffering = true;
  bool _hasError = false; // 新增錯誤狀態
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    if (widget.videoUrl.isEmpty) {
      setState(() {
        _isBuffering = false;
        _hasError = true;
      });
      return;
    }

    final effectiveUrl = AWSService.getPresignedUrl(widget.videoUrl);

    // --- 修改處：根據路徑開頭判斷初始化方式 ---
    if (effectiveUrl.startsWith('assets/')) {
      _controller = VideoPlayerController.asset(effectiveUrl);
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(effectiveUrl));
    }

    _controller
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {
              _duration = _controller.value.duration;
              _isBuffering = false;
            });
            _controller.play(); // 初始化成功後自動播放
          }
        })
        .catchError((error) {
          debugPrint('播放器初始化失敗: $error');
          if (mounted) {
            setState(() {
              _isBuffering = false;
              _hasError = true;
            });
          }
        });

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _position = _controller.value.position;
          _isPlaying = _controller.value.isPlaying;
          _isBuffering = _controller.value.isBuffering;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.lessonTitle),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: _hasError
            ? const Text(
                "影片加載失敗，請檢查路徑或格式",
                style: TextStyle(color: Colors.white),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  if (_controller.value.isInitialized)
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  if (_isBuffering)
                    const CircularProgressIndicator(color: Colors.purpleAccent),
                  _buildControls(),
                ],
              ),
      ),
    );
  }

  Widget _buildControls() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
        });
      },
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            if (!_isPlaying)
              const Center(
                child: Icon(Icons.play_arrow, color: Colors.white, size: 80),
              ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  VideoProgressIndicator(_controller, allowScrubbing: true),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
