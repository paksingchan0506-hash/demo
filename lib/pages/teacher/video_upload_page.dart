import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/aws_config.dart';
import '../../services/upload_task_manager.dart';
import 'power_save_mode_page.dart';

class VideoUploadPage extends StatefulWidget {
  final String memberId;
  final String? courseId;
  final String? lessonId;
  final String? lessonName;
  final bool isCourseIntro;
  final int? minDurationSeconds;
  final int? maxDurationSeconds;
  final bool skipDbUpdate;
  final bool autoPopOnCompleted;

  const VideoUploadPage({
    super.key,
    required this.memberId,
    this.courseId,
    this.lessonId,
    this.lessonName,
    this.isCourseIntro = false,
    this.minDurationSeconds,
    this.maxDurationSeconds,
    this.skipDbUpdate = false,
    this.autoPopOnCompleted = false,
  });

  @override
  State<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  static const MethodChannel _processorChannel = MethodChannel(
    'com.example.realvideo/processor',
  );
  StreamSubscription<UploadTaskStatus>? _statusSubscription;
  UploadTaskStatus _currentStatus = UploadTaskManager().currentStatus;
  String? _selectedFileName;
  String? _selectedFilePath;
  bool _use2DMask = false;
  String _selectedDecoration = 'mask';
  bool _autoPopped = false;

  @override
  void initState() {
    super.initState();
    _statusSubscription = UploadTaskManager().statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
      if (!_autoPopped &&
          widget.autoPopOnCompleted &&
          status.stage == UploadTaskStage.completed &&
          (status.finalVideoPath ?? '').isNotEmpty) {
        _autoPopped = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!Navigator.of(context).canPop()) return;
          Navigator.pop(context, status.finalVideoPath);
        });
        return;
      }
    });
  }

  @override
  void dispose() {
    _setBrightness(-1);
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _setBrightness(double brightness) async {
    try {
      await _processorChannel.invokeMethod<bool>('setScreenBrightness', {
        'brightness': brightness,
      });
    } catch (_) {}
  }

  bool get _isProcessing {
    return _currentStatus.stage != UploadTaskStage.idle &&
        _currentStatus.stage != UploadTaskStage.completed &&
        _currentStatus.stage != UploadTaskStage.error &&
        _currentStatus.stage != UploadTaskStage.cancelled;
  }

  Future<void> _handleExit() async {
    if (!_isProcessing) {
      if (_currentStatus.stage == UploadTaskStage.completed &&
          (_currentStatus.finalVideoPath ?? '').isNotEmpty) {
        Navigator.pop(context, _currentStatus.finalVideoPath);
      } else {
        Navigator.pop(context);
      }
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          '退出上傳？',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '退出後會取消上傳，並刪除已上傳到雲端的暫存檔案。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '退出並取消',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      await UploadTaskManager().cancelCurrentUpload();
      await _setBrightness(-1);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickFile() async {
    // 檢查 AWS 設定
    if (!AWSConfig.isConfigured()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AWS 設定不完整，請先設定')));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'mov'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final filePath = file.path;
    final extension = file.extension?.toLowerCase();

    if (filePath == null) return;

    // 再次驗證副檔名（保險起見）
    if (extension != 'mp4' && extension != 'mkv' && extension != 'mov') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('不支援的影片格式。請選擇 mp4, mkv 或 mov 檔案。')),
        );
      }
      return;
    }

    setState(() {
      _selectedFileName = file.name;
      _selectedFilePath = filePath;
    });
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) return '${seconds}s';
    if (seconds >= 3600) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      if (m == 0) return '${h}小時';
      return '${h}小時${m}分鐘';
    }
    if (seconds >= 60) {
      final m = seconds ~/ 60;
      return '${m}分鐘';
    }
    return '${seconds}s';
  }

  Future<void> _startUpload() async {
    if (!AWSConfig.isConfigured()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AWS 設定不完整，請先設定')));
      return;
    }
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先選擇影片')));
      return;
    }

    final hasLessonId = (widget.lessonId ?? '').trim().isNotEmpty;
    final effectiveMinSeconds =
        widget.minDurationSeconds ??
        (!widget.isCourseIntro && hasLessonId ? 900 : null);
    final effectiveMaxSeconds =
        widget.maxDurationSeconds ?? (widget.isCourseIntro ? null : 7200);

    if (effectiveMinSeconds != null || effectiveMaxSeconds != null) {
      try {
        final info = await UploadTaskManager.platform.invokeMethod<Map>(
          'getVideoInfo',
          {'inputPath': _selectedFilePath},
        );
        final dur = info?['duration'];
        if (dur is num) {
          final seconds = (dur.toDouble() / 1000).round();
          if (effectiveMinSeconds != null && seconds < effectiveMinSeconds) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '影片需至少 ${_formatDuration(effectiveMinSeconds)}，目前 ${_formatDuration(seconds)}',
                  ),
                ),
              );
            }
            return;
          }
          if (effectiveMaxSeconds != null && seconds > effectiveMaxSeconds) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '影片不可超過 ${_formatDuration(effectiveMaxSeconds)}，目前 ${_formatDuration(seconds)}',
                  ),
                ),
              );
            }
            return;
          }
        }
      } catch (_) {}
    }

    // 如果開啟了 2D 面具，彈出提示確認
    if (_use2DMask) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('確認使用 2D 虛擬面具'),
          content: const Text('開啟 2D 虛擬面具功能後，影片處理與上傳時間會明顯增加（依影片長度而定）。是否確定要繼續？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('確定'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (_currentStatus.stage != UploadTaskStage.idle &&
        _currentStatus.stage != UploadTaskStage.completed &&
        _currentStatus.stage != UploadTaskStage.error &&
        _currentStatus.stage != UploadTaskStage.cancelled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('當前有任務正在進行中')));
      return;
    }
    if (_currentStatus.stage == UploadTaskStage.completed ||
        _currentStatus.stage == UploadTaskStage.error ||
        _currentStatus.stage == UploadTaskStage.cancelled) {
      UploadTaskManager().reset();
    }

    final path = _selectedFilePath!;
    UploadTaskManager().startUpload(
      file: File(path),
      memberId: widget.memberId,
      courseId: widget.courseId,
      lessonId: widget.lessonId,
      use2DMask: _use2DMask,
      decorationType: _selectedDecoration,
      isCourseIntro: widget.isCourseIntro,
      skipDbUpdate: widget.skipDbUpdate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleExit();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleExit,
          ),
          title: const Text(
            '影片上傳與處理',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (_isProcessing)
              TextButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const PowerSaveModePage(initialBrightness: 0.5),
                    ),
                  );
                  await _setBrightness(-1);
                },
                icon: const Icon(Icons.battery_saver, color: Colors.amber),
                label: const Text(
                  '慳電模式',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.grey[900]!],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 狀態顯示卡片
                _buildStatusCard(_isProcessing),

                const SizedBox(height: 24.0),

                // 2. 影片選擇與配置卡片
                _buildUploadConfigCard(_isProcessing),

                const SizedBox(height: 24.0),

                // 3. 操作按鈕
                _buildActionButtons(_isProcessing),

                const SizedBox(height: 32.0),

                // 4. 上傳說明
                _buildInstructionsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isProcessing) {
    final stageIndex = _currentStatus.stage.index;
    final isError =
        _currentStatus.stage == UploadTaskStage.error ||
        _currentStatus.stage == UploadTaskStage.cancelled;
    final isCompleted = _currentStatus.stage == UploadTaskStage.completed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isError
              ? Colors.redAccent.withOpacity(0.5)
              : isCompleted
              ? Colors.greenAccent.withOpacity(0.5)
              : isProcessing
              ? Colors.purpleAccent.withOpacity(0.5)
              : Colors.grey[700]!,
          width: 1.5,
        ),
        boxShadow: [
          if (isProcessing)
            BoxShadow(
              color: Colors.purpleAccent.withOpacity(0.1),
              blurRadius: 15,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline
                    : isCompleted
                    ? Icons.check_circle_outline
                    : isProcessing
                    ? Icons.sync
                    : Icons.info_outline,
                color: isError
                    ? Colors.redAccent
                    : isCompleted
                    ? Colors.greenAccent
                    : isProcessing
                    ? Colors.purpleAccent
                    : Colors.grey[400],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentStatus.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (isProcessing) ...[
            const SizedBox(height: 20),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 8,
                  width:
                      MediaQuery.of(context).size.width *
                      0.8 *
                      _currentStatus.progress,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.purpleAccent, Colors.blueAccent],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purpleAccent.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(_currentStatus.progress * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          // NSFW 結果顯示
          if (stageIndex >= UploadTaskStage.uploadingToS3.index ||
              (isError && _currentStatus.isNsfw))
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _currentStatus.isNsfw
                    ? Colors.redAccent.withOpacity(0.1)
                    : Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentStatus.isNsfw
                        ? Icons.warning_amber
                        : Icons.security,
                    color: _currentStatus.isNsfw
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '內容檢測: ${_currentStatus.isNsfw ? '包含限制級內容' : '安全'}',
                    style: TextStyle(
                      color: _currentStatus.isNsfw
                          ? Colors.redAccent
                          : Colors.greenAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadConfigCard(bool isProcessing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.lessonName != null) ...[
            Text(
              '目標章節',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.lessonName!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(color: Colors.grey, height: 32),
          ],

          Text(
            '影片檔案',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedFilePath != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.movie_filter,
                    color: Colors.purpleAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFileName ?? '未命名影片',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              '尚未選擇任何影片',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),

          if (_selectedFilePath != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2D 虛擬面具',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '自動遮蓋臉部以保護隱私',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                Switch(
                  activeColor: Colors.purpleAccent,
                  value: _use2DMask,
                  onChanged: isProcessing
                      ? null
                      : (v) => setState(() => _use2DMask = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_use2DMask) ...[
              const SizedBox(height: 16),
              _MaskOptionsRow(
                selected: _selectedDecoration,
                onSelect: (val) => setState(() => _selectedDecoration = val),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isProcessing) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: isProcessing ? null : _pickFile,
            icon: const Icon(Icons.video_collection_rounded, size: 20),
            label: Text(_selectedFilePath == null ? '選擇影片' : '更改影片'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!isProcessing && _selectedFilePath != null)
                  BoxShadow(
                    color: Colors.purpleAccent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: isProcessing || _selectedFilePath == null
                  ? null
                  : _startUpload,
              icon: const Icon(Icons.rocket_launch_rounded, size: 20),
              label: const Text(
                '開始上傳並處理',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: Colors.grey[800],
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.amberAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '上傳小貼士',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionItem('1', '支援 MP4, MKV, MOV 格式影片'),
          if (widget.isCourseIntro)
            _buildInstructionItem(
              '!',
              widget.minDurationSeconds != null ||
                      widget.maxDurationSeconds != null
                  ? '影片限制：${widget.minDurationSeconds ?? 0}s ～ ${widget.maxDurationSeconds ?? 0}s'
                  : '課程介紹影片限制在 5 分鐘內',
              isWarning: true,
            ),
          if (!widget.isCourseIntro)
            _buildInstructionItem(
              '!',
              '一般課時影片限制在 15 分鐘～2 小時內',
              isWarning: true,
            ),
          _buildInstructionItem('2', '開啟 2D 面具會增加處理時間，請耐心等候'),
          _buildInstructionItem('3', '18+ 內容偵測失敗將無法上傳'),
          _buildInstructionItem('4', '上傳過程中請勿強制關閉 App'),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(
    String num,
    String text, {
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$num.',
            style: TextStyle(
              color: isWarning ? Colors.redAccent : Colors.purpleAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isWarning ? Colors.redAccent : Colors.white70,
                fontSize: 13,
                fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaskOptionsRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _MaskOptionsRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MaskOptionCard(
            label: '口罩',
            value: 'mask',
            selected: selected == 'mask',
            assetName: 'assets/masks/mask_logo.png',
            fallbackPreview: _MaskPreview.mask(),
            onTap: () => onSelect('mask'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MaskOptionCard(
            label: '全臉面具',
            value: 'full_face',
            selected: selected == 'full_face',
            assetName: 'assets/masks/full_face_logo.png',
            fallbackPreview: _MaskPreview.fullFace(),
            onTap: () => onSelect('full_face'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MaskOptionCard(
            label: '半臉面具',
            value: 'upper_face',
            selected: selected == 'upper_face',
            assetName: 'assets/masks/upper_face_logo.png',
            fallbackPreview: _MaskPreview.upperFace(),
            onTap: () => onSelect('upper_face'),
          ),
        ),
      ],
    );
  }
}

class _MaskOptionCard extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final String assetName;
  final Widget fallbackPreview;
  final VoidCallback onTap;

  const _MaskOptionCard({
    required this.label,
    required this.value,
    required this.selected,
    required this.assetName,
    required this.fallbackPreview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Colors.purpleAccent : Colors.grey.shade300;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _AssetWithFallback(
                assetName: assetName,
                fallback: fallbackPreview,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.purpleAccent : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetWithFallback extends StatelessWidget {
  final String assetName;
  final Widget fallback;

  const _AssetWithFallback({required this.assetName, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetName,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _MaskPreview extends StatelessWidget {
  final List<_Shape> shapes;

  const _MaskPreview._(this.shapes);

  factory _MaskPreview.mask() {
    return _MaskPreview._([
      _Shape(
        color: Colors.blue.withOpacity(0.6),
        rect: const Rect.fromLTWH(10, 55, 60, 25),
        radius: 8,
      ),
      _Shape(
        color: Colors.blue.withOpacity(0.6),
        rect: const Rect.fromLTWH(30, 50, 20, 5),
        radius: 2,
      ),
    ]);
  }

  factory _MaskPreview.fullFace() {
    return _MaskPreview._([
      _Shape.circle(
        center: const Offset(40, 40),
        radius: 32,
        color: Colors.deepPurple.withOpacity(0.4),
      ),
      _Shape(
        color: Colors.deepPurple.withOpacity(0.5),
        rect: const Rect.fromLTWH(22, 30, 36, 12),
        radius: 6,
      ),
    ]);
  }

  factory _MaskPreview.upperFace() {
    return _MaskPreview._([
      _Shape(
        color: Colors.teal.withOpacity(0.6),
        rect: const Rect.fromLTWH(18, 28, 44, 14),
        radius: 10,
      ),
      _Shape.circle(
        center: const Offset(32, 35),
        radius: 5,
        color: Colors.white.withOpacity(0.9),
      ),
      _Shape.circle(
        center: const Offset(48, 35),
        radius: 5,
        color: Colors.white.withOpacity(0.9),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PreviewPainter(shapes),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey.shade100,
        ),
      ),
    );
  }
}

class _Shape {
  final Rect? rect;
  final double radius;
  final Offset? center;
  final double? circleRadius;
  final Color color;

  _Shape({
    required this.rect,
    this.radius = 0,
    this.center,
    this.circleRadius,
    required this.color,
  });

  _Shape.circle({
    required Offset center,
    required double radius,
    required this.color,
  }) : rect = null,
       center = center,
       circleRadius = radius,
       radius = 0;
}

class _PreviewPainter extends CustomPainter {
  final List<_Shape> shapes;

  _PreviewPainter(this.shapes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in shapes) {
      final paint = Paint()..color = s.color;
      if (s.rect != null) {
        final r = RRect.fromRectAndRadius(s.rect!, Radius.circular(s.radius));
        canvas.drawRRect(r, paint);
      } else if (s.center != null && s.circleRadius != null) {
        canvas.drawCircle(s.center!, s.circleRadius!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
