import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import '../../services/aws_config.dart';
import '../../services/aws_service.dart';
import '../../services/api_service.dart';
import '../../utils/subtitle_layout.dart';

class StudentLessonPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String lessonId;
  final String lessonTitle;
  final String? memberId;

  const StudentLessonPlayerPage({
    super.key,
    required this.videoUrl,
    required this.lessonId,
    required this.lessonTitle,
    this.memberId,
  });

  @override
  State<StudentLessonPlayerPage> createState() =>
      _StudentLessonPlayerPageState();
}

class _StudentLessonPlayerPageState extends State<StudentLessonPlayerPage> {
  static const MethodChannel _processorChannel = MethodChannel(
    'com.example.realvideo/processor',
  );
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isBuffering = true;
  bool _isError = false;
  double _stableAspectRatio = 16 / 9;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _controlsVisible = true;
  bool _isLandscape = false;
  Timer? _controlsHideTimer;

  final Map<String, List<_Cue>> _subtitles = {};
  String _activeSub = 'off'; // 'off' | 'en-US' | 'zh-CN' | 'zh-HK'
  Timer? _subtitleTimer;
  String _currentSubtitle = '';
  String _formattedSubtitle = '';
  final Map<String, String> _subtitleLoadStatus = {};
  int? _subtitleFolderKeyCount;
  String? _subtitleFolderListError;
  List<String> _subtitleSrtSamples = [];

  bool _resourcesOpen = false;
  List<dynamic> _resources = [];
  bool _resourcesLoading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_enableVideoOrientations());
    final mId = widget.memberId;
    if (mId != null && mId.isNotEmpty) {
      unawaited(
        ApiService.markFirstLesson(memberId: mId, lessonId: widget.lessonId),
      );
    }
    _initPlayer();
    _loadSubtitles();
  }

  @override
  void dispose() {
    _subtitleTimer?.cancel();
    _controlsHideTimer?.cancel();
    _restorePreferredOrientations();
    _restoreSystemUi();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enableVideoOrientations() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}
  }

  Future<void> _restorePreferredOrientations() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } catch (_) {}
  }

  Future<void> _applySystemUiForOrientation(bool isLandscape) async {
    try {
      if (isLandscape) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (_) {}
  }

  Future<void> _restoreSystemUi() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleAutoHideControls();
    } else {
      _controlsHideTimer?.cancel();
    }
  }

  void _scheduleAutoHideControls() {
    _controlsHideTimer?.cancel();
    if (!_isLandscape) return;
    if (!_controller.value.isPlaying) return;
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  Future<void> _initPlayer() async {
    try {
      final url = AWSService.getPresignedUrl(widget.videoUrl);
      if (url.startsWith('assets/')) {
        _controller = VideoPlayerController.asset(url);
      } else {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      await _controller.initialize();
      final ar = _controller.value.aspectRatio;
      if (ar > 0 && ar.isFinite) _stableAspectRatio = ar;
      _duration = _controller.value.duration;
      _controller.addListener(_onTick);
      await _controller.setPlaybackSpeed(_playbackSpeed);
      await _controller.play();
      setState(() {
        _initialized = true;
        _isBuffering = false;
      });
      _scheduleAutoHideControls();
    } catch (e) {
      setState(() {
        _isError = true;
        _isBuffering = false;
      });
    }
  }

  void _onTick() {
    if (!mounted) return;
    final v = _controller.value;
    final ar = v.aspectRatio;
    if (ar > 0 && ar.isFinite) _stableAspectRatio = ar;
    setState(() {
      _position = v.position;
      _isBuffering = v.isBuffering;
    });
    _updateSubtitle();
    if (_controlsVisible) {
      _scheduleAutoHideControls();
    }
  }

  Future<void> _loadSubtitles() async {
    final key = _toS3ObjectKey(widget.videoUrl);
    if (key.isEmpty) return;
    final lastSlash = key.lastIndexOf('/');
    if (lastSlash <= 0) return;
    final folderPath = key.substring(0, lastSlash);
    final folderName = folderPath.substring(folderPath.lastIndexOf('/') + 1);
    if (folderName.isEmpty) return;
    final fileName = key.substring(lastSlash + 1);
    final fileStem = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final bases = <String>{
      '$folderPath/$folderName',
      '$folderPath/$fileStem',
    }.toList();

    List<String> keys = [];
    try {
      keys = await AWSService.listS3Keys(folderPath);
      _subtitleFolderKeyCount = keys.length;
      _subtitleFolderListError = null;
      _subtitleSrtSamples = keys
          .where((k) => k.toLowerCase().endsWith('.srt'))
          .where((k) => k.contains(folderPath))
          .take(8)
          .toList();
    } catch (e) {
      _subtitleFolderKeyCount = null;
      _subtitleFolderListError = e.toString();
      _subtitleSrtSamples = [];
    }

    final langs = ['en-US', 'zh-CN', 'zh-HK'];
    for (final lang in langs) {
      String? lastTriedKey;
      String? lastErr;
      bool loaded = false;

      String? findByList(String candidate) {
        if (keys.isEmpty) return null;
        for (final k in keys) {
          if (k == candidate) return k;
        }
        final lower = candidate.toLowerCase();
        for (final k in keys) {
          if (k.toLowerCase() == lower) return k;
        }
        return null;
      }

      for (final base in bases) {
        final candidates = <String>[
          '$base.$lang.srt',
          '$base.${lang.replaceAll('-', '_')}.srt',
          '$base.${lang.toLowerCase()}.srt',
          '$base.${lang.toLowerCase().replaceAll('-', '_')}.srt',
          '$base.$lang.SRT',
          '$base.${lang.replaceAll('-', '_')}.SRT',
        ];

        for (final c in candidates) {
          lastTriedKey = findByList(c) ?? c;
          try {
            final srt = await _downloadTextFromS3Key(lastTriedKey);
            final cues = _parseSrtToCues(srt);
            if (cues.isNotEmpty) {
              _subtitles[lang] = cues;
              _subtitleLoadStatus[lang] = 'ok (${cues.length}) $lastTriedKey';
              loaded = true;
              break;
            } else {
              lastErr = 'empty';
            }
          } catch (e) {
            lastErr = e.toString();
          }
        }
        if (loaded) break;
      }

      if (!loaded) {
        _subtitleLoadStatus[lang] =
            '${lastErr ?? 'failed'} ${lastTriedKey ?? ''}'.trim();
      }
    }
    if (mounted) setState(() {});
  }

  Future<String> _downloadTextFromS3Key(String objectKey) async {
    final url = AWSService.getPresignedUrl(objectKey);
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final bytes = res.bodyBytes;
      if (bytes.length >= 2) {
        if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
          final units = <int>[];
          for (int i = 2; i + 1 < bytes.length; i += 2) {
            units.add(bytes[i] | (bytes[i + 1] << 8));
          }
          return String.fromCharCodes(units);
        }
        if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
          final units = <int>[];
          for (int i = 2; i + 1 < bytes.length; i += 2) {
            units.add((bytes[i] << 8) | bytes[i + 1]);
          }
          return String.fromCharCodes(units);
        }
      }
      return utf8.decode(bytes, allowMalformed: true);
    }
    throw Exception('HTTP ${res.statusCode}');
  }

  void _updateSubtitle() {
    if (_activeSub == 'off' || !_subtitles.containsKey(_activeSub)) {
      if (_currentSubtitle.isNotEmpty || _formattedSubtitle.isNotEmpty) {
        setState(() {
          _currentSubtitle = '';
          _formattedSubtitle = '';
        });
      }
      return;
    }
    final secs = _position.inMilliseconds / 1000.0;
    final cues = _subtitles[_activeSub]!;
    final cue = cues.firstWhere(
      (c) => secs >= c.start && secs <= c.end,
      orElse: () => _Cue.empty,
    );
    final text = cue.text;
    if (_currentSubtitle != text) {
      setState(() {
        _currentSubtitle = text;
        _formattedSubtitle = '';
      });
    }
  }

  String _subtitleLabel(String key) {
    switch (key) {
      case 'off':
        return '關閉字幕';
      case 'en-US':
        return '英文';
      case 'zh-HK':
        return '繁體中文';
      case 'zh-CN':
        return '簡體中文';
      default:
        return key;
    }
  }

  List<String> _availableSubtitleKeys() {
    final keys = <String>['off'];
    if (_subtitles.containsKey('en-US')) keys.add('en-US');
    if (_subtitles.containsKey('zh-HK')) keys.add('zh-HK');
    if (_subtitles.containsKey('zh-CN')) keys.add('zh-CN');
    return keys;
  }

  Future<void> _pickSubtitle() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) {
        final keys = _availableSubtitleKeys();
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const Text(
                  '字幕',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                if (keys.length == 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '未找到字幕檔',
                          style: TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _subtitleFolderKeyCount != null
                              ? 'Folder 內檔案數: $_subtitleFolderKeyCount'
                              : 'Folder 列表失敗: ${_subtitleFolderListError ?? 'unknown'}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        if (_subtitleSrtSamples.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Text(
                            '偵測到的字幕檔(最多8個):',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          ..._subtitleSrtSamples.map(
                            (k) => Text(
                              k,
                              style: const TextStyle(
                                color: Colors.white30,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        Text(
                          'en-US: ${_subtitleLoadStatus['en-US'] ?? 'not tried'}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'zh-HK: ${_subtitleLoadStatus['zh-HK'] ?? 'not tried'}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'zh-CN: ${_subtitleLoadStatus['zh-CN'] ?? 'not tried'}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ...keys.map(
                  (k) => ListTile(
                    title: Text(
                      _subtitleLabel(k),
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: k == _activeSub
                        ? const Icon(Icons.check, color: Colors.purpleAccent)
                        : null,
                    onTap: () => Navigator.pop(ctx, k),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() => _activeSub = picked);
    _updateSubtitle();
    try {
      await ApiService.trackEvent('subtitle_change', {
        'lessonId': widget.lessonId,
        'lang': _activeSub,
      });
    } catch (_) {}
  }

  List<_Cue> _parseSrtToCues(String srt) {
    final cues = <_Cue>[];
    final lines = srt.replaceAll('\r', '').split('\n');
    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        i++;
        continue;
      }
      if (int.tryParse(line) != null) {
        i++;
        if (i >= lines.length) break;
      }
      final timeLine = lines[i].trim();
      if (!timeLine.contains('-->')) {
        i++;
        continue;
      }
      final parts = timeLine.split('-->');
      final start = _parseSrtTime(parts[0].trim());
      final end = _parseSrtTime(parts[1].trim());
      i++;
      final buffer = StringBuffer();
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(lines[i].trim());
        i++;
      }
      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        cues.add(_Cue(start: start, end: end, text: text));
      }
    }
    return cues;
  }

  double _parseSrtTime(String timeStr) {
    var t = timeStr.trim();
    if (t.contains(' ')) {
      t = t.split(' ').first;
    }
    try {
      final parts = t.split(':');
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secPart = parts[2];
      final sepIndex = secPart.indexOf(',');
      final dotIndex = secPart.indexOf('.');
      final splitIndex = sepIndex >= 0 ? sepIndex : dotIndex;
      final seconds = int.parse(
        splitIndex >= 0 ? secPart.substring(0, splitIndex) : secPart,
      );
      final millis = splitIndex >= 0
          ? int.parse(
              secPart
                  .substring(splitIndex + 1)
                  .padRight(3, '0')
                  .substring(0, 3),
            )
          : 0;
      return hours * 3600 + minutes * 60 + seconds + millis / 1000.0;
    } catch (_) {
      return 0.0;
    }
  }

  String _toS3ObjectKey(String path) {
    var key = path.toString();
    final bucketPrefix = 's3://${AWSConfig.s3BucketName}/';
    if (key.startsWith(bucketPrefix)) {
      key = key.replaceFirst(bucketPrefix, '');
    } else if (key.startsWith('http')) {
      try {
        final uri = Uri.parse(key);
        key = uri.path.replaceFirst(RegExp(r'^/'), '');
      } catch (_) {}
    }
    return key.replaceFirst(RegExp(r'^/'), '');
  }

  Future<void> _toggleSubtitles() async {
    const order = ['off', 'en-US', 'zh-HK', 'zh-CN'];
    final idx = order.indexOf(_activeSub);
    final next = order[(idx + 1) % order.length];
    setState(() => _activeSub = next);
    _updateSubtitle();
    try {
      await ApiService.trackEvent('subtitle_change', {
        'lessonId': widget.lessonId,
        'lang': _activeSub,
      });
    } catch (_) {}
  }

  Future<void> _changeSpeed(double v) async {
    _playbackSpeed = v;
    try {
      await _controller.setPlaybackSpeed(v);
    } catch (_) {}
    setState(() {});
    try {
      await ApiService.trackEvent('speed_change', {
        'lessonId': widget.lessonId,
        'speed': v,
      });
    } catch (_) {}
  }

  Future<void> _seekRelative(int deltaSeconds) async {
    final pos = _controller.value.position + Duration(seconds: deltaSeconds);
    await _controller.seekTo(_clampDuration(pos, Duration.zero, _duration));
    setState(() {});
    try {
      await ApiService.trackEvent(
        deltaSeconds > 0 ? 'seek_forward' : 'seek_back',
        {'lessonId': widget.lessonId, 'delta': deltaSeconds},
      );
    } catch (_) {}
  }

  Duration _clampDuration(Duration v, Duration minV, Duration maxV) {
    if (v < minV) return minV;
    if (v > maxV) return maxV;
    return v;
  }

  Future<bool> _handleExit() async {
    final pct = _duration.inSeconds == 0
        ? 1.0
        : _position.inSeconds / _duration.inSeconds;
    if (pct < 0.9) {
      final res = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('退出課程', style: TextStyle(color: Colors.white)),
          content: const Text(
            '您尚未完成本課程，確定要離開？',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                '繼續觀看',
                style: TextStyle(color: Colors.purpleAccent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                '確認退出',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
      if (res != true) return false;
    }
    try {
      await ApiService.reportLessonProgress(
        widget.lessonId,
        _position.inSeconds,
      );
    } catch (_) {}
    return true;
  }

  Future<void> _toggleResourcesPanel() async {
    if (_resourcesOpen) {
      setState(() => _resourcesOpen = false);
      return;
    }
    setState(() {
      _resourcesLoading = true;
      _resourcesOpen = true;
    });
    try {
      final res = await ApiService.getLessonResources(widget.lessonId);
      setState(() {
        _resources = (res is Map && res['resources'] is List)
            ? res['resources']
            : [];
      });
    } catch (_) {
      setState(() => _resources = []);
    } finally {
      setState(() => _resourcesLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        if (_isLandscape != isLandscape) {
          _isLandscape = isLandscape;
          _controlsVisible = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _applySystemUiForOrientation(_isLandscape);
            if (_isLandscape) {
              _scheduleAutoHideControls();
            } else {
              setState(() => _controlsVisible = true);
            }
          });
        }

        return RawKeyboardListener(
          autofocus: true,
          focusNode: FocusNode(),
          onKey: (event) {
            if (event is RawKeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _seekRelative(-10);
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _seekRelative(10);
              }
            }
          },
          child: WillPopScope(
            onWillPop: () async => await _handleExit(),
            child: Scaffold(
              backgroundColor: Colors.black,
              appBar: isLandscape
                  ? null
                  : AppBar(
                      backgroundColor: Colors.black,
                      leading: IconButton(
                        tooltip: '退出',
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () async {
                          final ok = await _handleExit();
                          if (ok && mounted) Navigator.pop(context);
                        },
                      ),
                      title: Text(widget.lessonTitle),
                      actions: [
                        IconButton(
                          tooltip: '資源',
                          icon: const Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.white,
                          ),
                          onPressed: _toggleResourcesPanel,
                        ),
                      ],
                    ),
              body: Stack(
                children: [
                  if (isLandscape) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTapDown: (d) {
                        final w = MediaQuery.of(context).size.width;
                        if (d.localPosition.dx < w / 2) {
                          _seekRelative(-10);
                        } else {
                          _seekRelative(10);
                        }
                      },
                      child: _buildVideoSurface(isLandscape: true),
                    ),
                    _buildLandscapeOverlays(),
                    if (_resourcesOpen) _buildResourcesDrawer(),
                  ] else ...[
                    _buildPortraitBody(),
                    if (_resourcesOpen) _buildResourcesDrawer(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortraitBody() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (d) {
              final w = MediaQuery.of(context).size.width;
              if (d.localPosition.dx < w / 2) {
                _seekRelative(-10);
              } else {
                _seekRelative(10);
              }
            },
            child: _buildVideoSurface(isLandscape: false),
          ),
        ),
        _buildPortraitSubtitleBar(),
        _buildControls(),
      ],
    );
  }

  Widget _buildPortraitSubtitleBar() {
    final show = _currentSubtitle.trim().isNotEmpty;
    if (!show) return const SizedBox(height: 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = max(0.0, constraints.maxWidth - 32) * 0.9;
        const subtitleStyle = TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.35,
        );

        final next = SubtitleLayout.reflow(
          input: _currentSubtitle,
          style: subtitleStyle,
          maxWidth: maxW,
          textDirection: Directionality.of(context),
          textScaleFactor: MediaQuery.textScaleFactorOf(context),
        );
        if (_formattedSubtitle != next) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_currentSubtitle.trim().isEmpty) return;
            setState(() => _formattedSubtitle = next);
          });
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          color: Colors.black,
          child: Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Text(
                  _formattedSubtitle.isNotEmpty ? _formattedSubtitle : next,
                  textAlign: TextAlign.center,
                  style: subtitleStyle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoSurface({required bool isLandscape}) {
    if (_isError) {
      return const Center(
        child: Text('影片加載失敗', style: TextStyle(color: Colors.white)),
      );
    }
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      );
    }

    final currentAr = _controller.value.aspectRatio;
    final effectiveAr = (currentAr > 0 && currentAr.isFinite)
        ? currentAr
        : _stableAspectRatio;

    final subtitle = Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bottomPad = isLandscape
              ? max(16.0, constraints.maxHeight * 0.12)
              : max(8.0, constraints.maxHeight * 0.05);
          final show = _currentSubtitle.trim().isNotEmpty;
          final availableW = max(0.0, constraints.maxWidth - 32);
          final factor = isLandscape ? 0.6 : 0.4;
          final maxSubtitleW = availableW * factor;
          final subtitleStyle = const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.35,
          );

          if (show && _formattedSubtitle.isEmpty) {
            final next = SubtitleLayout.reflow(
              input: _currentSubtitle,
              style: subtitleStyle,
              maxWidth: maxSubtitleW,
              textDirection: Directionality.of(context),
              textScaleFactor: MediaQuery.textScaleFactorOf(context),
            );
            if (next != _formattedSubtitle) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_formattedSubtitle.isNotEmpty) return;
                if (_currentSubtitle.trim().isEmpty) return;
                setState(() => _formattedSubtitle = next);
              });
            }
          }
          return IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: bottomPad,
                ),
                child: AnimatedOpacity(
                  opacity: show ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxSubtitleW),
                      child: Text(
                        _formattedSubtitle.isNotEmpty
                            ? _formattedSubtitle
                            : _currentSubtitle,
                        textAlign: TextAlign.center,
                        style: subtitleStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (isLandscape) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(
              child: AspectRatio(
                aspectRatio: effectiveAr,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          if (_isBuffering)
            const CircularProgressIndicator(color: Colors.purpleAccent),
          subtitle,
        ],
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: effectiveAr,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            if (_isBuffering)
              const CircularProgressIndicator(color: Colors.purpleAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeOverlays() {
    final visible = _controlsVisible;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '退出',
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () async {
                          final ok = await _handleExit();
                          if (ok && mounted) Navigator.pop(context);
                        },
                      ),
                      Expanded(
                        child: Text(
                          widget.lessonTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        tooltip: '資源',
                        icon: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.white,
                        ),
                        onPressed: _toggleResourcesPanel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(top: false, child: _buildControls()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final posText = _fmt(_position);
    final durText = _fmt(_duration);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(color: Colors.black),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: _controller.value.isPlaying ? '暫停' : '播放',
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$posText / $durText',
                style: const TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickSubtitle,
                icon: const Icon(Icons.subtitles, color: Colors.white),
                label: Text(
                  _activeSub == 'off' ? '字幕' : _subtitleLabel(_activeSub),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<double>(
                tooltip: '播放速度',
                color: Colors.grey[900],
                onSelected: (v) => _changeSpeed(v),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 0.25, child: Text('0.25x')),
                  PopupMenuItem(value: 0.5, child: Text('0.5x')),
                  PopupMenuItem(value: 1.0, child: Text('1x（正常）')),
                  PopupMenuItem(value: 1.5, child: Text('1.5x')),
                  PopupMenuItem(value: 2.0, child: Text('2x')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '${_playbackSpeed.toStringAsFixed(_playbackSpeed == 1.0 ? 0 : 2)}x',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _clamp(
                _position.inMilliseconds.toDouble(),
                0,
                _duration.inMilliseconds.toDouble(),
              ),
              min: 0,
              max: _duration.inMilliseconds.toDouble().clamp(
                1,
                double.infinity,
              ),
              onChanged: (v) async {
                final to = Duration(milliseconds: v.toInt());
                await _controller.seekTo(to);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildResourcesDrawer() {
    return Align(
      alignment: Alignment.centerRight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: MediaQuery.of(context).size.width * 0.8,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border(left: BorderSide(color: Colors.grey[800]!)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '課堂資源',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  tooltip: '關閉',
                  onPressed: () => setState(() => _resourcesOpen = false),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _resourcesLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.purpleAccent,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _resources.length,
                      itemBuilder: (ctx, i) {
                        final r = _resources[i] as Map;
                        final name = (r['lrName'] ?? '').toString();
                        final type = (r['resourceType'] ?? '')
                            .toString()
                            .toUpperCase();
                        final path = (r['path'] ?? '').toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[800]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                type == 'FILE'
                                    ? Icons.insert_drive_file
                                    : Icons.link,
                                color: Colors.purpleAccent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name.isNotEmpty ? name : path,
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (type == 'FILE')
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await ApiService.trackEvent(
                                        'resource_download',
                                        {
                                          'lessonId': widget.lessonId,
                                          'path': path,
                                        },
                                      );
                                    } catch (_) {}
                                    final url = AWSService.getPresignedUrl(
                                      path,
                                    );
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('開始下載')),
                                    );
                                    await _openExternalUrl(url);
                                  },
                                  child: const Text('下載'),
                                )
                              else
                                TextButton(
                                  onPressed: () async {
                                    final go = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: Colors.grey[900],
                                        title: const Text(
                                          '外部連結',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: const Text(
                                          '您將前往外部網站，請注意陌生連結的風險',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text(
                                              '取消',
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text(
                                              '前往',
                                              style: TextStyle(
                                                color: Colors.purpleAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (go == true) {
                                      try {
                                        await ApiService.trackEvent(
                                          'external_link',
                                          {
                                            'lessonId': widget.lessonId,
                                            'url': path,
                                          },
                                        );
                                      } catch (_) {}
                                      await _openExternalUrl(path);
                                    }
                                  },
                                  child: const Text('前往'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  double _clamp(double v, double minV, double maxV) =>
      v < minV ? minV : (v > maxV ? maxV : v);
}

class _Cue {
  final double start;
  final double end;
  final String text;
  const _Cue({required this.start, required this.end, required this.text});
  static const empty = _Cue(start: -1, end: -1, text: '');
}

extension _ExternalOpen on _StudentLessonPlayerPageState {
  Future<void> _openExternalUrl(String url) async {
    try {
      final ok = await _StudentLessonPlayerPageState._processorChannel
          .invokeMethod<bool>('openUrl', {'url': url});
      if (ok == true) return;
    } catch (_) {}

    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已複製連結')));
      }
    } catch (_) {}
  }
}
