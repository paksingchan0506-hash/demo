import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'api_service.dart';
import 'aws_config.dart';
import 'aws_service.dart';
import 'subtitle_service.dart';
import 'watermark_service.dart';
import 'background_uploader.dart';
import 'dart:io' show Platform;

enum UploadTaskStage {
  idle,
  checkingNSFW,
  applying2DMask,
  uploadingToS3,
  processingWatermark,
  processingEnding,
  generatingSubtitles,
  storingFinalVideo,
  storingSubtitles,
  completed,
  error,
  cancelled,
}

class UploadTaskStatus {
  final UploadTaskStage stage;
  final double progress;
  final String message;
  final bool isNsfw;
  final double nsfwScore;
  final String? error;
  final String? finalVideoPath;
  final int? uploadBytesSent;
  final int? uploadBytesTotal;
  final double? uploadSpeedBps;
  final int? uploadEtaSeconds;

  const UploadTaskStatus({
    this.stage = UploadTaskStage.idle,
    this.progress = 0.0,
    this.message = '準備就緒',
    this.isNsfw = false,
    this.nsfwScore = 0.0,
    this.error,
    this.finalVideoPath,
    this.uploadBytesSent,
    this.uploadBytesTotal,
    this.uploadSpeedBps,
    this.uploadEtaSeconds,
  });

  UploadTaskStatus copyWith({
    UploadTaskStage? stage,
    double? progress,
    String? message,
    bool? isNsfw,
    double? nsfwScore,
    String? error,
    String? finalVideoPath,
    int? uploadBytesSent,
    int? uploadBytesTotal,
    double? uploadSpeedBps,
    int? uploadEtaSeconds,
  }) {
    return UploadTaskStatus(
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      isNsfw: isNsfw ?? this.isNsfw,
      nsfwScore: nsfwScore ?? this.nsfwScore,
      error: error ?? this.error,
      finalVideoPath: finalVideoPath ?? this.finalVideoPath,
      uploadBytesSent: uploadBytesSent ?? this.uploadBytesSent,
      uploadBytesTotal: uploadBytesTotal ?? this.uploadBytesTotal,
      uploadSpeedBps: uploadSpeedBps ?? this.uploadSpeedBps,
      uploadEtaSeconds: uploadEtaSeconds ?? this.uploadEtaSeconds,
    );
  }
}

class UploadTaskManager {
  static final UploadTaskManager _instance = UploadTaskManager._internal();
  factory UploadTaskManager() => _instance;
  UploadTaskManager._internal();

  final _statusController = StreamController<UploadTaskStatus>.broadcast();
  Stream<UploadTaskStatus> get statusStream => _statusController.stream;
  static const bool enableBackgroundUpload = true;

  UploadTaskStatus _currentStatus = const UploadTaskStatus();
  UploadTaskStatus get currentStatus => _currentStatus;

  bool _cancelRequested = false;
  String? _activeTempPrefix;
  String? _activeFinalPrefix;
  String? _activeMultipartObjectKey;
  String? _activeMultipartUploadId;
  String? _activeCourseId;
  String? _activeLessonId;
  bool _activeIsCourseIntro = false;
  bool _dbUpdated = false;
  bool _skipDbUpdate = false;
  int? _lastUploadBytes;
  DateTime? _lastUploadTick;

  // MethodChannel for calling Native Code
  static const platform = MethodChannel('com.example.realvideo/processor');

  void _updateStatus(UploadTaskStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void reset() {
    _cancelRequested = false;
    _activeTempPrefix = null;
    _activeFinalPrefix = null;
    _activeMultipartObjectKey = null;
    _activeMultipartUploadId = null;
    _activeCourseId = null;
    _activeLessonId = null;
    _activeIsCourseIntro = false;
    _dbUpdated = false;
    _skipDbUpdate = false;
    _lastUploadBytes = null;
    _lastUploadTick = null;
    _updateStatus(const UploadTaskStatus());
  }

  Future<void> cancelCurrentUpload() async {
    _cancelRequested = true;

    final uploadId = _activeMultipartUploadId;
    final objectKey = _activeMultipartObjectKey;
    if (uploadId != null && objectKey != null) {
      try {
        await AWSService.abortMultipartUpload(objectKey, uploadId);
      } catch (_) {}
    }

    final tempPrefix = _activeTempPrefix;
    if (tempPrefix != null && tempPrefix.isNotEmpty) {
      try {
        await AWSService.deleteDirectory(tempPrefix);
      } catch (_) {}
    }

    final finalPrefix = _activeFinalPrefix;
    if (finalPrefix != null && finalPrefix.isNotEmpty) {
      try {
        await AWSService.deleteDirectory(finalPrefix);
      } catch (_) {}
    }

    if (_dbUpdated) {
      try {
        if (_activeIsCourseIntro && _activeCourseId != null) {
          await ApiService.updateCourseMedia(
            courseId: _activeCourseId!,
            introVideo: '',
          );
        } else if (_activeLessonId != null) {
          await ApiService.deleteLessonVideo(_activeLessonId!);
        }
      } catch (_) {}
      _dbUpdated = false;
    }

    _updateStatus(
      _currentStatus.copyWith(
        stage: UploadTaskStage.cancelled,
        progress: 0.0,
        message: '已取消上傳',
        error: 'Cancelled',
      ),
    );
  }

  void _throwIfCancelled() {
    if (_cancelRequested) {
      throw StateError('Upload cancelled');
    }
  }

  String _generateUniqueId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return '${now}_$random';
  }

  Future<void> startUpload({
    required File file,
    required String memberId,
    String? courseId,
    String? lessonId,
    bool use2DMask = false,
    String decorationType = 'mask',
    bool isCourseIntro = false,
    bool skipDbUpdate = false,
  }) async {
    if (_currentStatus.stage != UploadTaskStage.idle &&
        _currentStatus.stage != UploadTaskStage.completed &&
        _currentStatus.stage != UploadTaskStage.error &&
        _currentStatus.stage != UploadTaskStage.cancelled) {
      // Already running
      return;
    }

    if (memberId.isEmpty) {
      _updateStatus(
        _currentStatus.copyWith(
          stage: UploadTaskStage.error,
          message: '無法取得會員ID，請重新登入',
          error: 'MemberID Missing',
        ),
      );
      return;
    }

    if (!AWSConfig.isConfigured()) {
      _updateStatus(
        _currentStatus.copyWith(
          stage: UploadTaskStage.error,
          message: 'AWS 設定不完整，請先在 lib/services/aws_config.dart 中設定。',
          error: 'AWS Configuration Missing',
        ),
      );
      return;
    }

    _updateStatus(
      const UploadTaskStatus(
        stage: UploadTaskStage.checkingNSFW,
        progress: 0.0,
        message: '正在進行18+內容檢測...',
      ),
    );

    // Move uniqueId definition outside try block to be accessible in finally
    String? tempMemberPrefixForCleanup;
    _cancelRequested = false;
    _activeTempPrefix = null;
    _activeFinalPrefix = null;
    _activeMultipartObjectKey = null;
    _activeMultipartUploadId = null;
    _activeCourseId = courseId;
    _activeLessonId = lessonId;
    _activeIsCourseIntro = isCourseIntro;
    _dbUpdated = false;
    _skipDbUpdate = skipDbUpdate;

    try {
      // 1. 本地18+檢測 (0% - 5%)
      await _checkNsfwLocally(file.path);
      _throwIfCancelled();

      if (_currentStatus.isNsfw) {
        _updateStatus(
          _currentStatus.copyWith(
            stage: UploadTaskStage.error,
            progress: 0.0,
            message: '檢測到18+內容，上傳失敗',
            error: 'Content Violation',
          ),
        );
        return;
      }

      var currentFile = file;

      // 1.5 若需要 2D 面具，先在本地處理影片
      if (use2DMask) {
        _updateStatus(
          _currentStatus.copyWith(
            stage: UploadTaskStage.applying2DMask,
            progress: 0.03,
            message: '18+檢測通過，正在套用 2D 面具...',
          ),
        );
        try {
          final String? outputPath = await platform.invokeMethod<String>(
            'processVideo2D',
            {'inputPath': currentFile.path, 'decorationType': decorationType},
          );
          if (outputPath != null && outputPath.isNotEmpty) {
            currentFile = File(outputPath);
          }
        } catch (e) {
          print('2D 面具處理失敗，將使用原始影片: $e');
        }
      }
      _throwIfCancelled();

      _updateStatus(
        _currentStatus.copyWith(
          stage: UploadTaskStage.uploadingToS3,
          progress: 0.05,
          message:
              '18+內容檢測通過，正在上傳影片（iOS：上傳可在背景進行；Android：狀態列會顯示進度；強制關閉 App 會中止任務）',
          uploadBytesSent: 0,
          uploadBytesTotal: await currentFile.length(),
          uploadSpeedBps: null,
          uploadEtaSeconds: null,
        ),
      );
      _lastUploadBytes = 0;
      _lastUploadTick = DateTime.now();

      final storagePath = isCourseIntro
          ? _generateIntroStoragePath(memberId, file.path)
          : _generateStoragePath(memberId, file.path);
      final uniqueId = _generateUniqueId();
      final baseVideoName = path.basenameWithoutExtension(file.path);
      final safeVideoName = _sanitizeS3KeySegment(baseVideoName);
      tempMemberPrefixForCleanup = 'temp/$memberId';
      final tempObjectPrefix =
          '$tempMemberPrefixForCleanup/$safeVideoName/$uniqueId';
      final tempPath = '$tempObjectPrefix/${path.basename(currentFile.path)}';
      _activeTempPrefix = '$tempMemberPrefixForCleanup/';
      _activeFinalPrefix = '$storagePath/';

      String tempVideoUrl;
      if (enableBackgroundUpload && (Platform.isIOS || Platform.isAndroid)) {
        final uploader = BackgroundUploader();
        final fileSize = await currentFile.length();
        if (fileSize > 20 * 1024 * 1024) {
          // 背景多段上傳（更韌性）
          final bgFuture = uploader.startBackgroundMultipartUpload(
            file: currentFile,
            objectKey: tempPath,
            onInitiated: (uploadId) {
              _activeMultipartObjectKey = tempPath;
              _activeMultipartUploadId = uploadId;
            },
          );
          final sub = uploader.onProgress.listen((m) {
            if (m.containsKey('uploadedParts') && m.containsKey('totalParts')) {
              final uploadedParts = (m['uploadedParts'] ?? 0).toDouble();
              final totalParts = (m['totalParts'] ?? 1).toDouble();
              final frac = totalParts > 0 ? (uploadedParts / totalParts) : 0.0;
              final sent = (frac * fileSize).round().clamp(0, fileSize);
              final now = DateTime.now();
              double? speed;
              int? eta;
              if (_lastUploadBytes != null && _lastUploadTick != null) {
                final dt = now.difference(_lastUploadTick!).inMilliseconds;
                if (dt > 0) {
                  final delta = sent - _lastUploadBytes!;
                  speed = (delta * 1000) / dt;
                  if (speed > 1) {
                    eta = ((fileSize - sent) / speed).round();
                  }
                }
              }
              _lastUploadBytes = sent;
              _lastUploadTick = now;
              final totalProgress = 0.05 + frac * 0.50;
              _updateStatus(
                _currentStatus.copyWith(
                  progress: totalProgress.clamp(0.05, 0.55),
                  message: '背景多段上傳中... ${(frac * 100).toStringAsFixed(0)}%',
                  uploadBytesSent: sent,
                  uploadBytesTotal: fileSize,
                  uploadSpeedBps: speed,
                  uploadEtaSeconds: eta,
                ),
              );
            }
          });
          tempVideoUrl = await bgFuture;
          sub.cancel();
        } else {
          // 背景簡單上傳
          final sub = uploader.onProgress.listen((m) {
            int? sent;
            int? total;
            if (m.containsKey('sent') && m.containsKey('total')) {
              sent = (m['sent'] ?? 0).toInt();
              total = (m['total'] ?? 0).toInt();
            } else if (m.containsKey('uploadedBytes') && m.containsKey('totalBytes')) {
              sent = (m['uploadedBytes'] ?? 0).toInt();
              total = (m['totalBytes'] ?? 0).toInt();
            }
            if (sent == null || total == null || total <= 0) return;

            final frac = sent / total;
            final now = DateTime.now();
            double? speed;
            int? eta;
            if (_lastUploadBytes != null && _lastUploadTick != null) {
              final dt = now.difference(_lastUploadTick!).inMilliseconds;
              if (dt > 0) {
                final delta = sent - _lastUploadBytes!;
                speed = (delta * 1000) / dt;
                if (speed > 1) {
                  eta = ((total - sent) / speed).round();
                }
              }
            }
            _lastUploadBytes = sent;
            _lastUploadTick = now;

            final totalProgress = 0.05 + frac * 0.50;
            _updateStatus(
              _currentStatus.copyWith(
                progress: totalProgress.clamp(0.05, 0.55),
                message: '背景上傳中... ${(frac * 100).toStringAsFixed(0)}%',
                uploadBytesSent: sent,
                uploadBytesTotal: total,
                uploadSpeedBps: speed,
                uploadEtaSeconds: eta,
              ),
            );
          });
          tempVideoUrl = await uploader.startBackgroundUpload(
            file: currentFile,
            objectKey: tempPath,
          );
          await sub.cancel();
        }
      } else {
        tempVideoUrl = await AWSService.uploadFileToS3(
          currentFile,
          tempPath,
          onProgress: (sent, total) {
            final uploadProgress = sent / total;
            final now = DateTime.now();
            double? speed;
            int? eta;
            if (_lastUploadBytes != null && _lastUploadTick != null) {
              final dt = now.difference(_lastUploadTick!).inMilliseconds;
              if (dt > 0) {
                final delta = sent - _lastUploadBytes!;
                speed = (delta * 1000) / dt;
                if (speed > 1) {
                  eta = ((total - sent) / speed).round();
                }
              }
            }
            _lastUploadBytes = sent;
            _lastUploadTick = now;
            final totalProgress = 0.05 + (uploadProgress * 0.50);
            _updateStatus(
              _currentStatus.copyWith(
                progress: totalProgress,
                message:
                    '正在上傳影片... ${(uploadProgress * 100).toStringAsFixed(1)}%',
                uploadBytesSent: sent,
                uploadBytesTotal: total,
                uploadSpeedBps: speed,
                uploadEtaSeconds: eta,
              ),
            );
          },
        );
      }
      _throwIfCancelled();

      _updateStatus(
        _currentStatus.copyWith(
          stage: UploadTaskStage.processingEnding,
          progress: 0.55,
          message: '影片上傳完成，正在添加片尾...',
        ),
      );

      // 4. 先加結尾影片 (55% - 70%)
      String videoWithEnding;
      try {
        bool isPortrait = false;
        try {
          final info = await platform.invokeMethod<Map>('getVideoInfo', {
            'inputPath': currentFile.path,
          });
          if (info != null && info['isPortrait'] == true) {
            isPortrait = true;
          }
        } catch (_) {}
        videoWithEnding = await AWSService.addEnding(
          tempVideoUrl,
          isPortrait: isPortrait,
        );
      } catch (e) {
        print('添加片尾失敗，直接使用原始影片: $e');
        videoWithEnding = tempVideoUrl;
      }
      _throwIfCancelled();

      _updateStatus(
        _currentStatus.copyWith(
          stage: UploadTaskStage.processingWatermark,
          progress: 0.70,
          message: '片尾添加完成，正在添加浮水印...',
        ),
      );

      // 5. 再加浮水印 (70% - 85%)
      String videoWithWatermark;
      try {
        bool isPortrait = false;
        try {
          final info = await platform.invokeMethod<Map>('getVideoInfo', {
            'inputPath': currentFile.path,
          });
          if (info != null && info['isPortrait'] == true) {
            isPortrait = true;
          }
        } catch (_) {}
        videoWithWatermark = await WatermarkService.addWatermark(
          videoWithEnding,
          isPortrait: isPortrait,
        );
      } catch (e) {
        print('添加浮水印失敗，直接使用帶片尾的影片: $e');
        videoWithWatermark = videoWithEnding;
      }
      _throwIfCancelled();

      _updateStatus(
        _currentStatus.copyWith(
          stage: UploadTaskStage.generatingSubtitles,
          progress: 0.85,
          message: '浮水印添加完成，正在生成字幕...',
        ),
      );

      // 6. 生成字幕 (85% - 95%)
      final subtitles = await SubtitleService.getAllSubtitles(
        videoWithWatermark,
      );
      _throwIfCancelled();

      _updateStatus(
        _currentStatus.copyWith(
          stage: UploadTaskStage.storingFinalVideo,
          progress: 0.95,
          message: '字幕生成完成，正在存儲最終文件...',
        ),
      );

      // 7. 存儲最終影片
      final videoName = path.basenameWithoutExtension(currentFile.path);
      final finalVideoPath = '$storagePath/$videoName.mp4';
      await AWSService.copyObject(videoWithWatermark, finalVideoPath);
      _throwIfCancelled();

      // 獲取最終影片時長 (秒)
      int? durationInSeconds;
      try {
        final info = await platform.invokeMethod<Map>('getVideoInfo', {
          'inputPath': videoWithWatermark, // 使用處理後的最終影片獲取時長
        });
        if (info != null && info['duration'] != null) {
          final double durationMs = (info['duration'] as num).toDouble();
          durationInSeconds = (durationMs / 1000).round();
          print('成功獲取最終影片時長: $durationInSeconds 秒');
        }
      } catch (e) {
        print('獲取影片時長失敗: $e');
      }

      _updateStatus(
        _currentStatus.copyWith(
          stage: UploadTaskStage.storingSubtitles,
          progress: 0.98,
          message: '正在存儲字幕文件...',
        ),
      );

      // 8. 存儲字幕文件
      for (var entry in subtitles.entries) {
        final langCode = entry.key;
        final subtitleContent = entry.value;
        final subtitlePath = '$storagePath/$videoName.$langCode.srt';
        await AWSService.uploadStringToS3(subtitleContent, subtitlePath);
      }
      _throwIfCancelled();

      final storedPath = finalVideoPath;

      String? dbUpdateError;
      if (!_skipDbUpdate) {
        if (isCourseIntro) {
          if (courseId != null && courseId.trim().isNotEmpty) {
            try {
              await ApiService.updateCourseMedia(
                courseId: courseId,
                introVideo: storedPath,
              );
              _dbUpdated = true;
            } catch (e) {
              dbUpdateError = e.toString();
            }
          } else {
            dbUpdateError = 'courseId is empty';
          }
        } else {
          if (lessonId != null && lessonId.trim().isNotEmpty) {
            try {
              int? durationInMinutes = durationInSeconds != null
                  ? (durationInSeconds / 60).ceil()
                  : null;
              await ApiService.updateLessonVideo(
                lessonId,
                storedPath,
                duration: durationInMinutes,
              );
              _dbUpdated = true;
            } catch (e) {
              dbUpdateError = e.toString();
            }
          } else {
            dbUpdateError = 'lessonId is empty';
          }
        }
      }
      _throwIfCancelled();

      _updateStatus(
        _currentStatus.copyWith(
          stage: UploadTaskStage.completed,
          progress: 1.0,
          message: dbUpdateError == null
              ? '影片已成功上傳完成！'
              : '影片已成功上傳，但資料同步失敗，請稍後再試',
          finalVideoPath: storedPath,
        ),
      );
    } catch (e) {
      if (_cancelRequested) {
        _updateStatus(
          _currentStatus.copyWith(
            stage: UploadTaskStage.cancelled,
            progress: 0.0,
            message: '已取消上傳',
            error: 'Cancelled',
          ),
        );
        return;
      }
      _updateStatus(
        _currentStatus.copyWith(
          stage: UploadTaskStage.error,
          progress: 0.0,
          message: '處理失敗，請稍後再試',
          error: e.toString(),
        ),
      );
    } finally {
      // Clean up all temp files in the directory
      if (tempMemberPrefixForCleanup != null &&
          tempMemberPrefixForCleanup.isNotEmpty) {
        try {
          await AWSService.deleteDirectory(tempMemberPrefixForCleanup);
        } catch (e) {
          print('清理臨時目錄失敗: $e');
        }
      }
    }
  }

  String _sanitizeS3KeySegment(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'untitled';
    var v = trimmed.replaceAll(RegExp(r'[\\/]+'), '_');
    v = v.replaceAll(RegExp(r'[:*?"<>|]+'), '_');
    return v;
  }

  Future<void> _checkNsfwLocally(String filePath) async {
    try {
      final double? score = await platform.invokeMethod<double>('checkNsfw', {
        'inputPath': filePath,
      });

      if (score == null) throw Exception('18+內容檢測失敗，未取得結果');

      final isNsfw = score >= 0.7;

      _updateStatus(_currentStatus.copyWith(isNsfw: isNsfw, nsfwScore: score));
    } catch (e) {
      print('18+內容檢測失敗: $e');
      // 預設安全
      _updateStatus(
        _currentStatus.copyWith(
          isNsfw: false,
          nsfwScore: 0.2,
          message: '18+內容檢測可能不準確，已預設標記為安全內容',
        ),
      );
    }
  }

  String _generateStoragePath(String memberId, String fileName) {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final videoName = path.basenameWithoutExtension(fileName);
    return 'File/$memberId/$year/$month/$videoName';
  }

  String _generateIntroStoragePath(String memberId, String fileName) {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final videoName = path.basenameWithoutExtension(fileName);
    return 'File/$memberId/$year/$month/intro/$videoName';
  }
}
