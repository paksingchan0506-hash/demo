import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'aws_config.dart';
import 'aws_service.dart';

class SubtitleService {
  static final Map<String, String> _translationCache = {};

  // 獲取所有語言的字幕
  static Future<Map<String, String>> getAllSubtitles(
    String videoUrl, {
    List<String> targetLanguages = const ['zh-CN', 'zh-HK', 'en-US'],
    List<String>? spokenLanguageOptions,
  }) async {
    try {
      // 1. 從 S3 URL 中提取影片檔案資訊
      final videoKey = videoUrl.replaceAll(
        's3://${AWSConfig.s3BucketName}/',
        '',
      );

      final options =
          (spokenLanguageOptions ?? targetLanguages).toSet().toList()..sort();
      if (!options.contains('en-US')) {
        options.add('en-US');
      }

      final jobInfo = await _startTranscriptionJobAutoDetect(
        videoKey,
        languageOptions: options,
      );
      final outputKey = jobInfo['key']!;

      Map<String, dynamic> transcriptionJson;
      try {
        transcriptionJson = await _downloadTranscriptionJson(outputKey);
      } finally {
        try {
          await AWSService.deleteObject(outputKey);
        } catch (e) {
          print('清理轉錄臨時文件失敗: $e');
        }
      }

      final baseTracks = await _splitIdentifyMultipleLanguagesTracksToSrt(
        transcriptionJson,
      );

      final result = <String, String>{};
      for (final lang in targetLanguages) {
        final content = baseTracks[lang];
        if (content != null && content.trim().isNotEmpty) {
          result[lang] = content;
        }
      }

      final availableSources = <String, String>{...result};
      for (final entry in baseTracks.entries) {
        if (entry.value.trim().isNotEmpty) {
          availableSources.putIfAbsent(entry.key, () => entry.value);
        }
      }

      for (final target in targetLanguages) {
        final existing = result[target];
        if (existing != null && existing.trim().isNotEmpty) continue;

        final sourcePick = _pickBestSourceForTarget(
          target: target,
          tracks: availableSources,
        );
        if (sourcePick == null) continue;

        final sourceLang = sourcePick.key;
        final sourceSrt = sourcePick.value;

        final sourceTranslate = _toTranslateLanguageCode(sourceLang);
        final targetTranslate = _toTranslateLanguageCode(target);

        if (sourceTranslate == targetTranslate) {
          result[target] = sourceSrt;
          continue;
        }

        try {
          final translated = await translateSubtitle(
            srtContent: sourceSrt,
            sourceLanguageCode: sourceTranslate,
            targetLanguageCode: targetTranslate,
          );
          result[target] = translated;
        } catch (e) {
          print('翻譯字幕失敗 ($sourceLang -> $target): $e');
        }
      }

      for (final key in result.keys.toList()) {
        result[key] = await filterSubtitleContent(result[key]!, key);
      }

      return result;
    } catch (e) {
      throw Exception('生成字幕失敗: $e');
    }
  }

  // 生成單個語言的字幕
  static Future<String> generateSubtitle(
    String videoUrl,
    String languageCode,
  ) async {
    try {
      final all = await getAllSubtitles(
        videoUrl,
        targetLanguages: [languageCode],
      );
      final out = all[languageCode];
      if (out == null || out.trim().isEmpty) {
        throw Exception('無法生成指定語言的字幕');
      }
      return out;
    } catch (e) {
      throw Exception('生成字幕失敗: $e');
    }
  }

  static String _normalizeTranscribeLanguageCode(String? raw) {
    final code = (raw ?? '').trim();
    if (code.isEmpty) return '';
    final lower = code.toLowerCase();
    if (lower == 'en' || lower.startsWith('en-')) return 'en-US';
    if (lower == 'zh' || lower == 'zh-cn' || lower.startsWith('cmn')) {
      return 'zh-CN';
    }
    if (lower == 'zh-hk' || lower.startsWith('yue')) return 'zh-HK';
    if (lower == 'zh-tw') return 'zh-TW';
    if (code == 'en-US' || code == 'zh-CN' || code == 'zh-HK') return code;
    return code;
  }

  static String _toTranslateLanguageCode(String lang) {
    final normalized = _normalizeTranscribeLanguageCode(lang);
    if (normalized == 'en-US') return 'en';
    if (normalized == 'zh-HK' || normalized == 'zh-TW') return 'zh-TW';
    if (normalized == 'zh-CN' || normalized == 'zh') return 'zh';

    if (normalized.contains('-')) {
      final keep = {'pt-BR', 'pt-PT', 'fr-CA'};
      if (keep.contains(normalized)) return normalized;
      return normalized.split('-').first;
    }
    return normalized;
  }

  static String _sessionTempPrefixForVideoKey(String videoKey) {
    final matchNew = RegExp(r'^(temp/[^/]+/[^/]+/[^/]+/)').firstMatch(videoKey);
    if (matchNew != null) return matchNew.group(1)!;

    final matchOld = RegExp(r'^(File/[^/]+/temp/[^/]+/)').firstMatch(videoKey);
    if (matchOld != null) return matchOld.group(1)!;
    final lastSlashIndex = videoKey.lastIndexOf('/');
    if (lastSlashIndex >= 0) return videoKey.substring(0, lastSlashIndex + 1);
    return 'temp/';
  }

  static MapEntry<String, String>? _pickBestSourceForTarget({
    required String target,
    required Map<String, String> tracks,
  }) {
    if (tracks.isEmpty) return null;

    String? pick(List<String> candidates) {
      for (final c in candidates) {
        final v = tracks[c];
        if (v != null && v.trim().isNotEmpty) return c;
      }
      return null;
    }

    final normalizedTarget = _normalizeTranscribeLanguageCode(target);
    if (normalizedTarget == 'en-US') {
      final src = pick(['zh-CN', 'zh-HK', 'zh-TW']);
      if (src != null) return MapEntry(src, tracks[src]!);
    } else if (normalizedTarget == 'zh-CN') {
      final src = pick(['zh-HK', 'zh-TW', 'en-US']);
      if (src != null) return MapEntry(src, tracks[src]!);
    } else if (normalizedTarget == 'zh-HK' || normalizedTarget == 'zh-TW') {
      final src = pick(['zh-CN', 'en-US']);
      if (src != null) return MapEntry(src, tracks[src]!);
    }

    final fallback =
        tracks.entries.where((e) => e.value.trim().isNotEmpty).toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (fallback.isEmpty) return null;
    return fallback.first;
  }

  static bool _containsChineseCharacters(String input) {
    final zh = RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF]');
    return zh.hasMatch(input);
  }

  static bool _containsCantoneseParticles(String token) {
    const particles = [
      '嘅',
      '咁',
      '喺',
      '啲',
      '唔',
      '佢',
      '咗',
      '咩',
      '呀',
      '喎',
      '嘢',
      '嚟',
      '哋',
    ];
    for (final p in particles) {
      if (token.contains(p)) return true;
    }
    return false;
  }

  static String? _extractTranscribeItemLanguageCode(
    Map<dynamic, dynamic> item,
  ) {
    final direct = item['language_code'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    final alternatives = item['alternatives'];
    if (alternatives is List && alternatives.isNotEmpty) {
      final first = alternatives.first;
      if (first is Map) {
        final altCode = first['language_code'] ?? first['languageCode'];
        if (altCode is String && altCode.trim().isNotEmpty) {
          return altCode.trim();
        }
      }
    }
    return null;
  }

  static Future<Map<String, String>> _splitIdentifyMultipleLanguagesTracksToSrt(
    Map<String, dynamic> transcriptionResult,
  ) async {
    final results = transcriptionResult['results'];
    if (results is! Map || results['items'] is! List) {
      return const {'en-US': '', 'zh-HK': '', 'zh-CN': ''};
    }
    final items = results['items'] as List;

    final englishItems = <dynamic>[];
    final cantoneseItems = <dynamic>[];
    final mandarinItems = <dynamic>[];

    bool lastEnglishPron = false;
    bool lastCantonesePron = false;
    bool lastMandarinPron = false;

    for (final raw in items) {
      if (raw is! Map) continue;
      final type = raw['type'];
      if (type == 'pronunciation') {
        lastEnglishPron = false;
        lastCantonesePron = false;
        lastMandarinPron = false;

        final alternatives = raw['alternatives'];
        if (alternatives is! List || alternatives.isEmpty) continue;
        final firstAlt = alternatives.first;
        if (firstAlt is! Map) continue;
        final contentRaw = firstAlt['content'];
        if (contentRaw is! String) continue;

        final normalized = _normalizeTranscribeLanguageCode(
          _extractTranscribeItemLanguageCode(raw),
        );
        final isChineseToken = _containsChineseCharacters(contentRaw);

        if (normalized == 'zh-HK') {
          cantoneseItems.add(raw);
          lastCantonesePron = true;
          continue;
        }
        if (normalized == 'zh-CN' || normalized == 'zh-TW') {
          mandarinItems.add(raw);
          lastMandarinPron = true;
          continue;
        }

        if (isChineseToken) {
          if (_containsCantoneseParticles(contentRaw)) {
            cantoneseItems.add(raw);
            lastCantonesePron = true;
          } else {
            mandarinItems.add(raw);
            lastMandarinPron = true;
          }
          continue;
        }

        englishItems.add(raw);
        lastEnglishPron = true;
      } else if (type == 'punctuation') {
        if (lastEnglishPron) englishItems.add(raw);
        if (lastCantonesePron) cantoneseItems.add(raw);
        if (lastMandarinPron) mandarinItems.add(raw);
      }
    }

    String buildSrtFromItems(List<dynamic> nextItems) {
      final segments = _segmentTranscript(nextItems);
      return _generateSrtContent(segments);
    }

    final english = buildSrtFromItems(englishItems);
    final cantonese = buildSrtFromItems(cantoneseItems);
    final mandarin = buildSrtFromItems(mandarinItems);

    return {'en-US': english, 'zh-HK': cantonese, 'zh-CN': mandarin};
  }

  static Future<Map<String, dynamic>> _downloadTranscriptionJson(
    String outputKey,
  ) async {
    final body = await AWSService.downloadString(outputKey);
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('轉錄 JSON 格式無效');
  }

  static Future<Map<String, String>> _startTranscriptionJobAutoDetect(
    String videoKey, {
    required List<String> languageOptions,
  }) async {
    int maxRetries = 3;
    for (int i = 0; i < maxRetries; i++) {
      try {
        final normalizedOptions =
            languageOptions
                .map(_normalizeTranscribeLanguageCode)
                .where((e) => e.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort();

        final identifyMultipleOptions = normalizedOptions;

        final jobName =
            'transcription-job-${DateTime.now().millisecondsSinceEpoch}';
        final mediaUri =
            'https://${AWSConfig.s3BucketName}.s3.${AWSConfig.region}.amazonaws.com/$videoKey';

        final outputPrefix = _sessionTempPrefixForVideoKey(videoKey);
        final outputKey = '${outputPrefix}transcribe/$jobName.json';

        Map<String, dynamic> requestBody;
        if (identifyMultipleOptions.length >= 2) {
          requestBody = {
            'TranscriptionJobName': jobName,
            'IdentifyMultipleLanguages': true,
            'LanguageOptions': identifyMultipleOptions,
            'Media': {'MediaFileUri': mediaUri},
            'OutputBucketName': AWSConfig.s3BucketName,
            'OutputKey': outputKey,
          };
        } else {
          requestBody = {
            'TranscriptionJobName': jobName,
            'IdentifyLanguage': true,
            if (normalizedOptions.isNotEmpty)
              'LanguageOptions': normalizedOptions,
            'Media': {'MediaFileUri': mediaUri},
            'OutputBucketName': AWSConfig.s3BucketName,
            'OutputKey': outputKey,
          };
        }

        final endpoint = 'https://transcribe.${AWSConfig.region}.amazonaws.com';
        final bodyBytes = utf8.encode(jsonEncode(requestBody));
        final response = await AWSService.sendSignedRequest(
          endpoint: endpoint,
          method: 'POST',
          path: '/',
          body: bodyBytes,
          service: 'transcribe',
          contentType: 'application/x-amz-json-1.1',
          contentLength: bodyBytes.length,
          headers: {'X-Amz-Target': 'Transcribe.StartTranscriptionJob'},
        );

        if (response.statusCode != 200) {
          final body = utf8.decode(response.bodyBytes);
          throw Exception('Transcribe API 錯誤: $body');
        }

        await _waitForTranscriptionJob(jobName);
        return {'name': jobName, 'key': outputKey};
      } catch (e) {
        final msg = e.toString();
        final shouldFallbackToSingleIdentify =
            msg.contains(
              'not currently supported for multiple language identification',
            ) ||
            msg.contains('validation error detected') ||
            msg.contains("at 'languageOptions' failed to satisfy constraint") ||
            msg.contains('languageOptions');

        if (shouldFallbackToSingleIdentify && i < maxRetries - 1) {
          try {
            final fallback = await _startTranscriptionJobSingleIdentify(
              videoKey,
              languageOptions: languageOptions,
            );
            return fallback;
          } catch (_) {}
        }

        if (i == maxRetries - 1) rethrow;
        print('啟動自動語言辨識轉錄失敗 (嘗試 ${i + 1}/$maxRetries): $e. 重試中...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw Exception('啟動自動語言辨識轉錄失敗: 超過重試次數');
  }

  static Future<Map<String, String>> _startTranscriptionJobSingleIdentify(
    String videoKey, {
    required List<String> languageOptions,
  }) async {
    final normalizedOptions =
        languageOptions
            .map(_normalizeTranscribeLanguageCode)
            .where((e) => e.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final jobName =
        'transcription-job-${DateTime.now().millisecondsSinceEpoch}';
    final mediaUri =
        'https://${AWSConfig.s3BucketName}.s3.${AWSConfig.region}.amazonaws.com/$videoKey';

    final outputPrefix = _sessionTempPrefixForVideoKey(videoKey);
    final outputKey = '${outputPrefix}transcribe/$jobName.json';

    Map<String, dynamic> requestBody;
    if (normalizedOptions.isNotEmpty) {
      requestBody = {
        'TranscriptionJobName': jobName,
        'IdentifyLanguage': true,
        'LanguageOptions': normalizedOptions,
        'Media': {'MediaFileUri': mediaUri},
        'OutputBucketName': AWSConfig.s3BucketName,
        'OutputKey': outputKey,
      };
    } else {
      requestBody = {
        'TranscriptionJobName': jobName,
        'IdentifyLanguage': true,
        'Media': {'MediaFileUri': mediaUri},
        'OutputBucketName': AWSConfig.s3BucketName,
        'OutputKey': outputKey,
      };
    }

    final endpoint = 'https://transcribe.${AWSConfig.region}.amazonaws.com';
    final bodyBytes = utf8.encode(jsonEncode(requestBody));
    final response = await AWSService.sendSignedRequest(
      endpoint: endpoint,
      method: 'POST',
      path: '/',
      body: bodyBytes,
      service: 'transcribe',
      contentType: 'application/x-amz-json-1.1',
      contentLength: bodyBytes.length,
      headers: {'X-Amz-Target': 'Transcribe.StartTranscriptionJob'},
    );

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Transcribe API 錯誤: $body');
    }

    await _waitForTranscriptionJob(jobName);
    return {'name': jobName, 'key': outputKey};
  }

  static Future<String> translateText(
    String text, {
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final digest = sha1.convert(utf8.encode(trimmed)).toString();
    final cacheKey = '$sourceLanguageCode|$targetLanguageCode|$digest';
    final cached = _translationCache[cacheKey];
    if (cached != null) return cached;

    final endpoint = 'https://translate.${AWSConfig.region}.amazonaws.com';
    final body = jsonEncode({
      'Text': trimmed,
      'SourceLanguageCode': sourceLanguageCode,
      'TargetLanguageCode': targetLanguageCode,
    });
    final bodyBytes = utf8.encode(body);

    final response = await AWSService.sendSignedRequest(
      endpoint: endpoint,
      method: 'POST',
      path: '/',
      body: bodyBytes,
      service: 'translate',
      contentType: 'application/x-amz-json-1.1',
      contentLength: bodyBytes.length,
      headers: {
        'X-Amz-Target': 'AWSShineFrontendService_20170701.TranslateText',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'TranslateText failed: ${response.statusCode} ${utf8.decode(response.bodyBytes)}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['TranslatedText'] is! String) {
      throw Exception('TranslateText response invalid: $decoded');
    }
    final translated = decoded['TranslatedText'] as String;
    _translationCache[cacheKey] = translated;
    return translated;
  }

  static Future<String> translateSubtitle({
    required String srtContent,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final cues = _parseSrtCues(srtContent);
    if (cues.isEmpty) return srtContent;

    final translatedCues = <SubtitleCue>[];
    const batchSize = 8;

    for (int i = 0; i < cues.length; i += batchSize) {
      final end = (i + batchSize < cues.length) ? i + batchSize : cues.length;
      final batch = cues.sublist(i, end);

      final futures = batch.map((cue) async {
        try {
          final translated = await translateText(
            cue.text,
            sourceLanguageCode: sourceLanguageCode,
            targetLanguageCode: targetLanguageCode,
          );
          return SubtitleCue(cue.startTime, cue.endTime, translated);
        } catch (e) {
          return cue;
        }
      }).toList();

      final results = await Future.wait(futures);
      translatedCues.addAll(results);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < translatedCues.length; i++) {
      final cue = translatedCues[i];
      buffer.writeln('${i + 1}');
      buffer.writeln(
        '${_formatTime(cue.startTime)} --> ${_formatTime(cue.endTime)}',
      );
      buffer.writeln(cue.text);
      buffer.writeln();
    }
    return buffer.toString();
  }

  // 合併影片（添加片尾）
  static Future<String> concatVideosWithMediaConvertWithName(
    List<String> videoUrls,
    String outputUrl, {
    String nameModifier = '',
  }) async {
    try {
      // 1. 從 URL 中提取影片檔案資訊
      final videoKeys = videoUrls
          .map((url) => url.replaceAll('s3://${AWSConfig.s3BucketName}/', ''))
          .toList();

      // 2. 呼叫 AWS MediaConvert 合併影片
      final outputKey = await _startMediaConvertJob(
        videoKeys,
        outputUrl,
        nameModifier,
      );

      // 3. 返回輸出影片的 S3 URL
      return 's3://${AWSConfig.s3BucketName}/$outputKey';
    } catch (e) {
      throw Exception('合併影片失敗: $e');
    }
  }

  // 等待轉錄作業完成
  static Future<void> _waitForTranscriptionJob(String jobName) async {
    int consecutiveErrors = 0;
    // 設定最大重試次數，避免無限循環 (240次 * 5秒 = 1200秒 = 20分鐘)
    int maxRetries = 240;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        // 構建請求體
        final requestBody = {'TranscriptionJobName': jobName};

        // 發送請求
        final endpoint = 'https://transcribe.${AWSConfig.region}.amazonaws.com';
        final bodyBytes = utf8.encode(jsonEncode(requestBody));
        final response = await AWSService.sendSignedRequest(
          endpoint: endpoint,
          method: 'POST',
          path: '/',
          body: bodyBytes,
          service: 'transcribe',
          contentType: 'application/x-amz-json-1.1',
          contentLength: bodyBytes.length,
          headers: {'X-Amz-Target': 'Transcribe.GetTranscriptionJob'},
        );

        if (response.statusCode != 200) {
          throw Exception('獲取轉錄狀態失敗: ${response.body}');
        }

        consecutiveErrors = 0; // Reset error count on success

        final responseData = jsonDecode(response.body);
        final status =
            responseData['TranscriptionJob']['TranscriptionJobStatus']
                as String;

        if (status == 'COMPLETED') {
          return;
        } else if (status == 'FAILED') {
          throw Exception(
            '轉錄作業失敗: ${responseData['TranscriptionJob']['FailureReason']}',
          );
        } else {
          // IN_PROGRESS or QUEUED
          if (retryCount % 6 == 0) {
            // 每 30 秒打印一次
            print('轉錄作業正在進行中 ($status)... 已等待 ${retryCount * 5} 秒');
          }
        }
      } catch (e) {
        consecutiveErrors++;
        print('獲取轉錄狀態發生錯誤 ($consecutiveErrors/5): $e');
        if (consecutiveErrors >= 5) {
          rethrow;
        }
      }

      // 等待 5 秒後重試
      await Future.delayed(const Duration(seconds: 5));
      retryCount++;
    }

    throw Exception('轉錄作業超時 (超過 20 分鐘)');
  }

  // 分段轉錄結果
  static List<Map<String, dynamic>> _segmentTranscript(List<dynamic> items) {
    final segments = <Map<String, dynamic>>[];
    if (items.isEmpty) return segments;

    // 找到第一個有 start_time 的 pronunciation 項
    dynamic firstPronunciationItem;
    for (final item in items) {
      if (item['type'] == 'pronunciation' && item.containsKey('start_time')) {
        firstPronunciationItem = item;
        break;
      }
    }

    if (firstPronunciationItem == null) return segments;

    final currentSegment = {
      'start_time': double.parse(firstPronunciationItem['start_time']),
      'end_time': 0.0,
      'text': '',
    };

    for (final item in items) {
      if (item['type'] == 'pronunciation' && item.containsKey('start_time')) {
        final startTime = double.parse(item['start_time']);
        final text = item['alternatives'][0]['content'];

        // 如果當前段落超過 10 秒或包含足夠的內容，創建新段落
        if (startTime - (currentSegment['start_time'] as num) > 10) {
          // 找到前一個 pronunciation 項
          int prevIndex = items.indexOf(item) - 1;
          while (prevIndex >= 0) {
            final prevItem = items[prevIndex];
            if (prevItem['type'] == 'pronunciation' &&
                prevItem.containsKey('end_time')) {
              currentSegment['end_time'] = double.parse(prevItem['end_time']);
              break;
            }
            prevIndex--;
          }
          segments.add(Map.from(currentSegment));

          currentSegment['start_time'] = startTime;
          currentSegment['text'] = text;
        } else {
          currentSegment['text'] = '${currentSegment['text'] as String} $text';
        }
      }
    }

    // 添加最後一個段落
    if ((currentSegment['text'] as String).isNotEmpty) {
      // 找到最後一個有 end_time 的 pronunciation 項
      dynamic lastPronunciationItem;
      for (final item in items.reversed) {
        if (item['type'] == 'pronunciation' && item.containsKey('end_time')) {
          lastPronunciationItem = item;
          break;
        }
      }
      if (lastPronunciationItem != null) {
        currentSegment['end_time'] = double.parse(
          lastPronunciationItem['end_time'],
        );
        segments.add(Map.from(currentSegment));
      }
    }

    return segments;
  }

  // 生成 SRT 格式字幕內容
  static String _generateSrtContent(List<Map<String, dynamic>> transcriptions) {
    final buffer = StringBuffer();

    for (int i = 0; i < transcriptions.length; i++) {
      final segment = transcriptions[i];
      if (!segment.containsKey('start_time') ||
          !segment.containsKey('end_time') ||
          !segment.containsKey('text')) {
        continue;
      }
      final startTime = _formatTime(segment['start_time']);
      final endTime = _formatTime(segment['end_time']);
      final text = segment['text'];

      buffer.writeln('${i + 1}');
      buffer.writeln('$startTime --> $endTime');
      buffer.writeln(text);
      buffer.writeln();
    }

    return buffer.toString();
  }

  // 格式化時間為 SRT 格式
  static String _formatTime(double seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final secs = (seconds % 60).floor();
    final millis = ((seconds % 1) * 1000).floor();

    return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')},${millis.toString().padLeft(3, '0')}';
  }

  // 啟動 MediaConvert 作業
  static Future<String> _startMediaConvertJob(
    List<String> videoKeys,
    String outputUrl,
    String nameModifier,
  ) async {
    try {
      // 構建 MediaConvert API 請求
      final jobId = 'mediaconvert-job-${DateTime.now().millisecondsSinceEpoch}';
      final outputKey = outputUrl.replaceAll(
        's3://${AWSConfig.s3BucketName}/',
        '',
      );

      // 構建請求體
      final requestBody = {
        'JobTemplate': 'AddEndingTemplate', // 假設已創建添加片尾的模板
        'Queue': 'Default',
        'UserMetadata': {'JobName': jobId},
        'Role': AWSConfig.mediaConvertRoleArn,
        'Settings': {
          'OutputGroups': [
            {
              'Name': 'File Group',
              'Outputs': [
                {
                  'ContainerSettings': {'Container': 'MP4'},
                  'VideoDescription': {
                    'CodecSettings': {'Codec': 'H_264'},
                  },
                  'AudioDescriptions': [
                    {
                      'CodecSettings': {'Codec': 'AAC'},
                    },
                  ],
                },
              ],
              'OutputGroupSettings': {
                'Type': 'FILE_GROUP_SETTINGS',
                'FileGroupSettings': {
                  'Destination':
                      's3://${AWSConfig.s3BucketName}/${outputKey.replaceAll(path.basename(outputKey), '')}',
                },
              },
            },
          ],
          'Inputs': [
            {'FileInput': 's3://${AWSConfig.s3BucketName}/${videoKeys[0]}'},
          ],
        },
      };

      // 獲取 MediaConvert 服務端點
      final endpoint = await AWSService.getMediaConvertEndpoint();
      final bodyString = jsonEncode(requestBody);

      // 發送請求
      final response = await AWSService.sendSignedRequest(
        endpoint: endpoint,
        method: 'POST',
        path: '/2017-08-29/jobs',
        body: bodyString,
        service: 'mediaconvert',
        contentType: 'application/json; charset=utf-8',
        contentLength: utf8.encode(bodyString).length,
      );

      if (response.statusCode != 201) {
        throw Exception('MediaConvert API 錯誤: ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      final jobData = responseData['job'];
      final newJobId = jobData['id'];

      // 等待作業完成
      await _waitForMediaConvertJob(newJobId);

      return '$outputKey$nameModifier.mp4';
    } catch (e) {
      throw Exception('啟動 MediaConvert 作業失敗: $e');
    }
  }

  // 等待 MediaConvert 作業完成
  static Future<void> _waitForMediaConvertJob(String jobId) async {
    for (int i = 0; i < 120; i++) {
      // 最多等待 20 分鐘
      await Future.delayed(const Duration(seconds: 10));

      // 獲取 MediaConvert 服務端點
      final endpoint = await AWSService.getMediaConvertEndpoint();

      // 發送請求
      final response = await AWSService.sendSignedRequest(
        endpoint: endpoint,
        method: 'GET',
        path: '/2017-08-29/jobs/$jobId',
        service: 'mediaconvert',
        contentType: 'application/json',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['Job']['Status'];

        if (status == 'COMPLETE') {
          return;
        } else if (status == 'ERROR') {
          throw Exception('MediaConvert 作業失敗: ${data['Job']['ErrorMessage']}');
        }
      }
    }

    throw Exception('MediaConvert 作業超時');
  }

  // --- 內容審核 (Content Moderation) ---
  static Future<String> filterSubtitleContent(
    String srtContent,
    String langCode,
  ) async {
    if (srtContent.trim().isEmpty) return srtContent;

    final cues = _parseSrtCues(srtContent);
    if (cues.isEmpty) return srtContent;

    if (langCode.startsWith('zh')) {
      final zhFiltered = _applyLocalProfanityFilter(cues);
      final zhCues = _parseSrtCues(zhFiltered);
      return _applyLocalEnglishProfanityFilter(zhCues);
    }

    if (!langCode.startsWith('en')) {
      return srtContent;
    }

    final enFiltered = _applyLocalEnglishProfanityFilter(cues);
    final enCues = _parseSrtCues(enFiltered);
    return _applyLocalProfanityFilter(enCues);
  }

  static String _applyLocalProfanityFilter(List<SubtitleCue> cues) {
    final buffer = StringBuffer();
    final badWords = {
      '屌',
      '𨳒',
      '撚',
      '𨶙',
      '鳩',
      '㞗',
      '𨳊',
      '柒',
      '𨳍',
      '閪',
      '𨋩',
      '幹',
      '賤',
      '狗',
      '黑',
      '仆街',
      '咸家鏟',
      '冚家鏟',
      '含家鏟',
      '含撚',
      '戇鳩',
      '傻撚',
      '柒頭',
      '粉腸',
      '廢鳩',
      '食屎',
      '廢柴',
      '正契弟',
      '死蠢',
      '籮柚',
      '碌鳩',
      '狗屎',
      '婊子',
      '贱人',
      '混蛋',
      '王八',
      '屌你老母',
      '屌你老母閪',
      '屌那星',
      '屌那媽',
      '頂你個肺',
      '死開啦',
      '收皮啦',
      '你死咗去邊',
      '你係咪柒呀',
      '唔好喺度鳩噏',
      '睇路呀，盲鳩',
      '幹你娘',
      '你媽的',
      '去死吧',
      '滾開',
      '你這個混蛋',
      '真是死爛',
      '小喇叭',
      '小你老母',
      'Call你老母',
      '擔梯',
      '廿三',
      '和尚擔遮',
      '老公撥扇',
      '麻布做龍袍',
      '床下底破柴',
      '倒掛臘鴨',
      '狗改不了吃屎',
      '不是省油的燈',
      '笑裡藏刀',
      '火燒眉毛',
      '傻逼',
      '傻B',
      '煞笔',
      '肏',
      '草泥马',
      '他妈的',
      '你妈的',
      '去你妈',
      '牛逼',
      '吉他的',
      '妈的',
    };

    final sortedBadWords = badWords.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    int replacedCount = 0;

    for (int i = 0; i < cues.length; i++) {
      final cue = cues[i];
      String text = cue.text;
      String original = text;

      for (final bad in sortedBadWords) {
        if (text.contains(bad)) {
          // 將敏感詞的每個字符替換為 #
          text = text.replaceAll(bad, '#' * bad.length);
        }
      }

      if (text != original) {
        replacedCount++;
        print('本地過濾器已審查: "$original" -> "$text"');
      }

      buffer.writeln((i + 1).toString());
      buffer.writeln(
        '${_formatTime(cue.startTime)} --> ${_formatTime(cue.endTime)}',
      );
      buffer.writeln(text);
      buffer.writeln();
    }

    if (replacedCount > 0) {
      print('本地粗話過濾器審查了 $replacedCount 行。');
    }

    return buffer.toString();
  }

  static String _applyLocalEnglishProfanityFilter(List<SubtitleCue> cues) {
    final buffer = StringBuffer();
    final badWords = {
      'fuck',
      'shit',
      'bitch',
      'asshole',
      'bastard',
      'dick',
      'pussy',
      'cunt',
      'motherfucker',
      'fucker',
      'bullshit',
      'slut',
      'whore',
      'faggot',
      'retard',
      'damn',
      'dammit',
      'bloody',
      'crap',
      'get lost',
    };

    final sortedBadWords = badWords.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    int replacedCount = 0;

    for (int i = 0; i < cues.length; i++) {
      final cue = cues[i];
      String text = cue.text;
      String original = text;

      for (final bad in sortedBadWords) {
        final pattern = RegExp(
          '\\b${RegExp.escape(bad)}\\b',
          caseSensitive: false,
        );
        if (pattern.hasMatch(text)) {
          text = text.replaceAllMapped(
            pattern,
            (match) => '#' * match.group(0)!.length,
          );
        }
      }

      if (text != original) {
        replacedCount++;
        print('本地英語過濾器已審查: "$original" -> "$text"');
      }

      buffer.writeln((i + 1).toString());
      buffer.writeln(
        '${_formatTime(cue.startTime)} --> ${_formatTime(cue.endTime)}',
      );
      buffer.writeln(text);
      buffer.writeln();
    }

    if (replacedCount > 0) {
      print('本地英語粗話過濾器審查了 $replacedCount 行。');
    }

    return buffer.toString();
  }

  // --- 輔助方法：解析 SRT ---
  static List<SubtitleCue> _parseSrtCues(String srtContent) {
    final cues = <SubtitleCue>[];
    final lines = srtContent.split('\n');
    int i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        i++;
        continue;
      }

      // 1. 索引 (可選，但通常存在)
      if (int.tryParse(line) != null) {
        i++;
        if (i >= lines.length) break;
      }

      // 2. 時間戳
      final timeLine = lines[i].trim();
      if (!timeLine.contains('-->')) {
        // 如果不是時間戳，可能是文本（格式不規範），跳過
        i++;
        continue;
      }

      final parts = timeLine.split('-->');
      final startTime = _parseSrtTime(parts[0].trim());
      final endTime = _parseSrtTime(parts[1].trim());
      i++;

      // 3. 文本 (可能多行)
      final textBuffer = StringBuffer();
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        if (textBuffer.isNotEmpty) textBuffer.write(' ');
        textBuffer.write(lines[i].trim());
        i++;
      }

      cues.add(SubtitleCue(startTime, endTime, textBuffer.toString()));
    }

    return cues;
  }

  static double _parseSrtTime(String timeStr) {
    // 00:00:05,000
    try {
      final parts = timeStr.split(':');
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secParts = parts[2].split(',');
      final seconds = int.parse(secParts[0]);
      final millis = int.parse(secParts[1]);

      return hours * 3600 + minutes * 60 + seconds + millis / 1000.0;
    } catch (e) {
      return 0.0;
    }
  }
}

class SubtitleCue {
  final double startTime;
  final double endTime;
  final String text;

  SubtitleCue(this.startTime, this.endTime, this.text);
}
