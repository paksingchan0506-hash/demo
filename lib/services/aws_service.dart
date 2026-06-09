import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'aws_config.dart';

class AWSService {
  static bool _taDisabledAtRuntime = false;

  // 新增：快取預簽名網址，防止重複產生導致圖片閃爍
  static final Map<String, _CachedUrl> _urlCache = {};

  static String _s3Endpoint() {
    if (AWSConfig.useTransferAcceleration && !_taDisabledAtRuntime) {
      return 'https://${AWSConfig.s3BucketName}.s3-accelerate.amazonaws.com';
    }
    return 'https://${AWSConfig.s3BucketName}.s3.${AWSConfig.region}.amazonaws.com';
  }

  static String _s3Host() {
    if (AWSConfig.useTransferAcceleration && !_taDisabledAtRuntime) {
      return '${AWSConfig.s3BucketName}.s3-accelerate.amazonaws.com';
    }
    return '${AWSConfig.s3BucketName}.s3.${AWSConfig.region}.amazonaws.com';
  }

  /// 獲取 S3 物件的公開 URL
  static String getPublicUrl(String objectKey) {
    if (objectKey.startsWith('http://') || objectKey.startsWith('https://')) {
      return objectKey;
    }

    // 如果是 s3:// 開頭，先移除前綴
    final cleanKey = objectKey
        .replaceFirst('s3://${AWSConfig.s3BucketName}/', '')
        .replaceFirst(RegExp(r'^/'), '');

    return '${_s3Endpoint()}/$cleanKey';
  }

  /// 獲取 S3 物件的預簽名 URL (有效期限預設 1 小時)
  static String getPresignedUrl(String objectKey, {int expiresSeconds = 3600}) {
    if (!AWSConfig.isConfigured()) return getPublicUrl(objectKey);
    if (objectKey.startsWith('http://') || objectKey.startsWith('https://')) {
      return objectKey;
    }

    final cleanKey = objectKey
        .replaceFirst('s3://${AWSConfig.s3BucketName}/', '')
        .replaceFirst(RegExp(r'^/'), '');

    // --- 核心修正：檢查快取 ---
    final now = DateTime.now().toUtc();
    if (_urlCache.containsKey(cleanKey)) {
      final cached = _urlCache[cleanKey]!;
      // 如果快取網址還沒過期（預留 5 分鐘緩衝），直接回傳
      if (now.isBefore(cached.expiry.subtract(const Duration(minutes: 5)))) {
        return cached.url;
      }
    }

    final amzDate = _formatAmzDate(now);
    final dateString = _formatDate(now);
    final region = AWSConfig.region;
    final service = 's3';
    final credentialScope = '$dateString/$region/$service/aws4_request';

    final queryParams = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '${AWSConfig.accessKeyId}/$credentialScope',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expiresSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    final host = _s3Host();
    final canonicalUri = _encodePath(cleanKey);
    final canonicalQueryString = _buildCanonicalQueryString(queryParams);
    final canonicalHeaders = 'host:$host\n';
    final signedHeaders = 'host';
    final payloadHash = 'UNSIGNED-PAYLOAD';

    final canonicalRequest = [
      'GET',
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _hash(canonicalRequest),
    ].join('\n');

    final signingKey = _getSigningKey(
      dateString: dateString,
      region: region,
      service: service,
    );

    final signature = _hmacSha256Hex(signingKey, stringToSign);

    final finalUrl =
        '${_s3Endpoint()}$canonicalUri?$canonicalQueryString&X-Amz-Signature=$signature';

    // 存入快取
    _urlCache[cleanKey] = _CachedUrl(
      url: finalUrl,
      expiry: now.add(Duration(seconds: expiresSeconds)),
    );

    return finalUrl;
  }

  static String _formatDate(DateTime now) {
    final utc = now.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}';
  }

  static String _formatAmzDate(DateTime now) {
    final utc = now.toUtc();
    final date = _formatDate(utc);
    final time =
        '${utc.hour.toString().padLeft(2, '0')}${utc.minute.toString().padLeft(2, '0')}${utc.second.toString().padLeft(2, '0')}';
    return '${date}T${time}Z';
  }

  static Future<String> testS3Connection() async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }
    final endpoint = _s3Endpoint();
    final response = await _sendSignedRequest(
      endpoint: endpoint,
      method: 'GET',
      path: '/',
      service: 's3',
    );
    if (response.statusCode == 200) {
      return 'S3 連線成功';
    }
    throw Exception('S3 連線失敗: ${response.statusCode} ${response.reasonPhrase}');
  }

  static const int _multipartChunkSize = 16 * 1024 * 1024; // 16MB
  static const int _multipartThreshold = 20 * 1024 * 1024; // 20MB

  static Future<String> uploadFileToS3(
    File file,
    String objectKey, {
    void Function(int sent, int total)? onProgress,
  }) async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }

    final fileSize = await file.length();

    // 若檔案大於分段門檻，使用分段上傳（更穩定、可重試）
    if (fileSize > _multipartThreshold) {
      return await _uploadFileToS3Multipart(
        file,
        objectKey,
        fileSize,
        onProgress: onProgress,
      );
    }

    // 使用 asBroadcastStream() 允许流被多次订阅
    final stream = file.openRead().asBroadcastStream();

    // Create a progress stream
    int totalSent = 0;
    final progressStream = stream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          totalSent += data.length;
          onProgress?.call(totalSent, fileSize);
          sink.add(data);
        },
      ),
    );

    await uploadToS3Stream(progressStream, objectKey, fileSize);
    return 's3://${AWSConfig.s3BucketName}/$objectKey';
  }

  static Future<String> _uploadFileToS3Multipart(
    File file,
    String objectKey,
    int fileSize, {
    void Function(int sent, int total)? onProgress,
  }) async {
    String? uploadId;
    try {
      print('開始分段上傳: $objectKey, 大小: $fileSize');
      print('正在初始化分段上傳...');
      uploadId = await _initiateMultipartUpload(objectKey);

      final parts = <Map<String, dynamic>>[];
      int uploadedBytes = 0;
      int partNumber = 1;

      final raf = await file.open();

      try {
        while (uploadedBytes < fileSize) {
          final remaining = fileSize - uploadedBytes;
          final chunkSize = remaining > _multipartChunkSize
              ? _multipartChunkSize
              : remaining;

          final chunk = await raf.read(chunkSize);

          String? eTag;
          int retryCount = 0;
          while (retryCount < 5) {
            try {
              eTag = await _uploadPart(objectKey, uploadId, partNumber, chunk);
              break;
            } catch (e) {
              print('上傳分段 $partNumber 失敗 (重試 ${retryCount + 1}/5): $e');
              retryCount++;
              if (retryCount >= 5) rethrow;
              await Future.delayed(Duration(seconds: (1 << retryCount)));
            }
          }

          parts.add({'PartNumber': partNumber, 'ETag': eTag});
          print('分段 $partNumber 上傳成功 (ETag: $eTag)');

          uploadedBytes += chunk.length;
          onProgress?.call(uploadedBytes, fileSize);

          partNumber++;
        }
      } finally {
        await raf.close();
      }

      print('正在完成分段上傳...');
      await _completeMultipartUpload(objectKey, uploadId, parts);
      print('分段上傳完成: $objectKey');

      return 's3://${AWSConfig.s3BucketName}/$objectKey';
    } catch (e) {
      print('分段上傳失敗: $e');
      if (uploadId != null) {
        try {
          await _abortMultipartUpload(objectKey, uploadId);
          print('已中止分段上傳並清理');
        } catch (cleanupError) {
          print('中止分段上傳失敗: $cleanupError');
        }
      }
      rethrow;
    }
  }

  static Future<String> _initiateMultipartUpload(String objectKey) async {
    var endpoint = _s3Endpoint();

    int retryCount = 0;
    while (true) {
      try {
        final response = await _sendSignedRequest(
          endpoint: endpoint,
          method: 'POST',
          path: '/$objectKey?uploads',
          service: 's3',
          extraHeaders: {'Content-Length': '0'},
          contentType: 'application/octet-stream',
        );

        if (response.statusCode != 200) {
          final body = response.body;
          // Fallback when Transfer Acceleration is not configured
          if (response.statusCode == 400 &&
              body.contains('Transfer Acceleration is not configured')) {
            _taDisabledAtRuntime = true;
            endpoint =
                'https://${AWSConfig.s3BucketName}.s3.${AWSConfig.region}.amazonaws.com';
            // Immediately retry without incrementing retryCount
            continue;
          }
          throw Exception('初始化分段上傳失敗: ${response.statusCode} $body');
        }

        final body = response.body;
        final match = RegExp(r'<UploadId>(.*?)</UploadId>').firstMatch(body);
        if (match != null) {
          return match.group(1)!;
        }
        throw Exception('無法解析 UploadId');
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('Transfer Acceleration is not configured')) {
          _taDisabledAtRuntime = true;
          endpoint =
              'https://${AWSConfig.s3BucketName}.s3.${AWSConfig.region}.amazonaws.com';
          // Do not count this as a retry; try again immediately
          continue;
        }
        print('初始化分段上傳失敗 (重試 ${retryCount + 1}/5): $e');
        retryCount++;
        if (retryCount >= 5) rethrow;
        await Future.delayed(Duration(seconds: 1 << retryCount));
      }
    }
  }

  static Future<String> _uploadPart(
    String objectKey,
    String uploadId,
    int partNumber,
    List<int> bytes,
  ) async {
    final endpoint = _s3Endpoint();
    final response = await _sendSignedRequest(
      endpoint: endpoint,
      method: 'PUT',
      path: '/$objectKey?partNumber=$partNumber&uploadId=$uploadId',
      service: 's3',
      body: bytes,
      contentType: 'application/octet-stream',
    );

    if (response.statusCode != 200) {
      throw Exception(
        '上傳分段 $partNumber 失敗: ${response.statusCode} ${response.body}',
      );
    }

    final eTag = response.headers['etag'];
    if (eTag == null) throw Exception('分段 $partNumber 缺少 ETag');
    return eTag;
  }

  static Future<void> _completeMultipartUpload(
    String objectKey,
    String uploadId,
    List<Map<String, dynamic>> parts,
  ) async {
    parts.sort(
      (a, b) => (a['PartNumber'] as int).compareTo(b['PartNumber'] as int),
    );
    final buffer = StringBuffer();
    buffer.write('<CompleteMultipartUpload>');
    for (final part in parts) {
      buffer.write('<Part>');
      buffer.write('<PartNumber>${part['PartNumber']}</PartNumber>');
      buffer.write('<ETag>${part['ETag']}</ETag>');
      buffer.write('</Part>');
    }
    buffer.write('</CompleteMultipartUpload>');

    final endpoint = _s3Endpoint();

    int retryCount = 0;
    while (true) {
      try {
        final response = await _sendSignedRequest(
          endpoint: endpoint,
          method: 'POST',
          path: '/$objectKey?uploadId=${Uri.encodeQueryComponent(uploadId)}',
          service: 's3',
          body: buffer.toString(),
          contentType: 'application/xml; charset=utf-8',
        );

        if (response.statusCode != 200) {
          throw Exception('完成分段上傳失敗: ${response.statusCode} ${response.body}');
        }
        return;
      } catch (e) {
        print('完成分段上傳失敗 (重試 ${retryCount + 1}/5): $e');
        retryCount++;
        if (retryCount >= 5) rethrow;
        await Future.delayed(Duration(seconds: 1 << retryCount));
      }
    }
  }

  static Future<void> _abortMultipartUpload(
    String objectKey,
    String uploadId,
  ) async {
    final endpoint = _s3Endpoint();
    await _sendSignedRequest(
      endpoint: endpoint,
      method: 'DELETE',
      path: '/$objectKey?uploadId=${Uri.encodeQueryComponent(uploadId)}',
      service: 's3',
    );
  }

  static Future<void> uploadToS3Stream(
    Stream<List<int>> stream,
    String objectKey,
    int length,
  ) async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }
    print('開始上傳數據到 S3 (Stream): $objectKey');
    print('檔案大小: $length 位元組');

    final endpoint = _s3Endpoint();

    final response = await _sendSignedRequest(
      endpoint: endpoint,
      method: 'PUT',
      path: '/$objectKey',
      body: stream,
      service: 's3',
      contentType: 'application/octet-stream',
      contentLength: length,
    );

    if (response.statusCode == 200) {
      print('檔案已成功上傳到: s3://${AWSConfig.s3BucketName}/$objectKey');
    } else {
      throw Exception(
        'S3 上傳失敗: ${response.statusCode} ${response.reasonPhrase}',
      );
    }
  }

  /// 刪除 S3 物件
  static Future<void> deleteS3Object(String objectKey) async {
    if (!AWSConfig.isConfigured()) return;

    final cleanKey = objectKey
        .replaceFirst('s3://${AWSConfig.s3BucketName}/', '')
        .replaceFirst(RegExp(r'^/'), '');

    final endpoint = _s3Endpoint();

    try {
      final response = await _sendSignedRequest(
        endpoint: endpoint,
        method: 'DELETE',
        path: '/$cleanKey',
        service: 's3',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('已刪除 S3 物件: $cleanKey');
      } else {
        print('刪除 S3 物件失敗: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('刪除 S3 物件異常: $e');
    }
  }

  /// 刪除 S3 物件 (別名，相容現有代碼)
  static Future<void> deleteObject(String objectKey) =>
      deleteS3Object(objectKey);

  /// 刪除 S3 資料夾（前綴）
  static Future<void> deleteS3Folder(String folderPath) async {
    if (!AWSConfig.isConfigured()) return;

    var prefix = folderPath.toString();
    // 移除 s3:// 前綴
    final bucketPrefix = 's3://${AWSConfig.s3BucketName}/';
    if (prefix.startsWith(bucketPrefix)) {
      prefix = prefix.replaceFirst(bucketPrefix, '');
    } else if (prefix.startsWith('http')) {
      // 處理 HTTP URL
      try {
        final uri = Uri.parse(prefix);
        prefix = uri.path.replaceFirst(RegExp(r'^/'), '');
      } catch (e) {
        print('解析資料夾 URL 失敗: $e');
      }
    }

    // 確保前綴以 / 結尾
    if (!prefix.endsWith('/')) {
      prefix = '$prefix/';
    }
    // 移除開頭的 /
    final cleanPrefix = prefix.replaceFirst(RegExp(r'^/'), '');

    print('正在執行 deleteS3Folder, prefix: $cleanPrefix');

    final endpoint = _s3Endpoint();

    // S3 List Objects V2 使用 list-type=2
    // 增加 max-keys 確保能一次列出更多檔案
    final listPath =
        '/?list-type=2&prefix=${Uri.encodeComponent(cleanPrefix)}&max-keys=1000';

    try {
      final listResponse = await _sendSignedRequest(
        endpoint: endpoint,
        method: 'GET',
        path: listPath,
        service: 's3',
      );

      if (listResponse.statusCode != 200) {
        print('列出 S3 物件失敗: ${listResponse.statusCode} ${listResponse.body}');
        return;
      }

      final body = listResponse.body;
      final keys = RegExp(
        r'<Key>(.*?)</Key>',
      ).allMatches(body).map((m) => m.group(1)!).toList();

      print('找到 ${keys.length} 個檔案需要刪除');

      for (final key in keys) {
        print('正在刪除 Key: $key');
        await deleteS3Object(key);
      }
      print('S3 資料夾清理完成');
    } catch (e) {
      print('deleteS3Folder 發生異常: $e');
    }
  }

  /// 刪除指定目錄（前綴）下的所有檔案 (別名，相容現有代碼)
  static Future<void> deleteDirectory(String prefix) => deleteS3Folder(prefix);

  static Future<List<String>> listS3Keys(String prefix) async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }

    var p = prefix.toString();
    final bucketPrefix = 's3://${AWSConfig.s3BucketName}/';
    if (p.startsWith(bucketPrefix)) {
      p = p.replaceFirst(bucketPrefix, '');
    } else if (p.startsWith('http')) {
      try {
        final uri = Uri.parse(p);
        p = uri.path.replaceFirst(RegExp(r'^/'), '');
      } catch (_) {}
    }

    if (!p.endsWith('/')) {
      p = '$p/';
    }
    final cleanPrefix = p.replaceFirst(RegExp(r'^/'), '');

    final endpoint = _s3Endpoint();
    final listPath =
        '/?list-type=2&prefix=${Uri.encodeComponent(cleanPrefix)}&max-keys=1000';

    final listResponse = await _sendSignedRequest(
      endpoint: endpoint,
      method: 'GET',
      path: listPath,
      service: 's3',
    );

    if (listResponse.statusCode != 200) {
      return [];
    }

    final body = listResponse.body;
    return RegExp(
      r'<Key>(.*?)</Key>',
    ).allMatches(body).map((m) => m.group(1)!).toList();
  }

  /// 下載 S3 物件內容為字串
  static Future<String> downloadString(String objectKey) async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }

    final cleanKey = objectKey
        .replaceFirst('s3://${AWSConfig.s3BucketName}/', '')
        .replaceFirst(RegExp(r'^/'), '');

    final endpoint = _s3Endpoint();
    final response = await _sendSignedRequest(
      endpoint: endpoint,
      method: 'GET',
      path: '/$cleanKey',
      service: 's3',
    );

    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    } else {
      throw Exception(
        '下載 S3 物件失敗: ${response.statusCode} ${response.reasonPhrase}',
      );
    }
  }

  /// 下載 S3 物件內容為字串 (別名)
  static Future<String> downloadS3Object(String objectKey) =>
      downloadString(objectKey);

  /// 產生 S3 PUT 的預簽名 URL（UNSIGNED-PAYLOAD），可用於背景上傳
  static Future<String> generatePresignedPutUrl(
    String objectKey, {
    int expiresSeconds = 3600,
  }) async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }
    final now = DateTime.now().toUtc();
    final dateString = _formatDate(now);
    final amzDate = _formatAmzDate(now);
    final service = 's3';
    final method = 'PUT';
    final host = _s3Host();
    final region = AWSConfig.region;
    final credentialScope = '$dateString/$region/$service/aws4_request';

    // Query parameters for pre-signing
    final queryParams = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential':
          '${AWSConfig.accessKeyId}/$dateString/${AWSConfig.region}/s3/aws4_request',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expiresSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    // Canonical request
    final canonicalUri = _encodePath('/$objectKey');
    final canonicalQuery = _buildCanonicalQueryString(queryParams);
    final canonicalHeaders = 'host:$host\n';
    const signedHeaders = 'host';
    const payloadHash = 'UNSIGNED-PAYLOAD';
    final canonicalRequest = [
      method,
      canonicalUri,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    // String to sign
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _hash(canonicalRequest),
    ].join('\n');

    final signingKey = _getSigningKey(
      dateString: dateString,
      region: region,
      service: service,
    );
    final signature = _hmacSha256Hex(signingKey, stringToSign);

    final presignedUrl =
        'https://$host$canonicalUri?$canonicalQuery&X-Amz-Signature=$signature';
    return presignedUrl;
  }

  // Public wrappers for multipart flow (for background orchestrators)
  static Future<String> initiateMultipartUpload(String objectKey) async {
    return await _initiateMultipartUpload(objectKey);
  }

  static Future<void> completeMultipartUpload(
    String objectKey,
    String uploadId,
    List<Map<String, dynamic>> parts,
  ) async {
    await _completeMultipartUpload(objectKey, uploadId, parts);
  }

  static Future<void> abortMultipartUpload(
    String objectKey,
    String uploadId,
  ) async {
    await _abortMultipartUpload(objectKey, uploadId);
  }

  // Generate presigned URL for UploadPart
  static Future<String> generatePresignedUploadPartUrl({
    required String objectKey,
    required String uploadId,
    required int partNumber,
    int expiresSeconds = 3600,
  }) async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }
    final now = DateTime.now().toUtc();
    final dateString = _formatDate(now);
    final amzDate = _formatAmzDate(now);
    const service = 's3';
    const method = 'PUT';
    final host = _s3Host();
    final region = AWSConfig.region;
    final credentialScope = '$dateString/$region/$service/aws4_request';

    final canonicalUri = _encodePath('/$objectKey');
    final baseQuery = {
      'partNumber': partNumber.toString(),
      'uploadId': uploadId,
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential':
          '${AWSConfig.accessKeyId}/$dateString/${AWSConfig.region}/s3/aws4_request',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expiresSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };
    final canonicalQuery = _buildCanonicalQueryString(baseQuery);
    final canonicalHeaders = 'host:$host\n';
    const signedHeaders = 'host';
    const payloadHash = 'UNSIGNED-PAYLOAD';
    final canonicalRequest = [
      method,
      canonicalUri,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _hash(canonicalRequest),
    ].join('\n');
    final signingKey = _getSigningKey(
      dateString: dateString,
      region: region,
      service: service,
    );
    final signature = _hmacSha256Hex(signingKey, stringToSign);
    final url =
        'https://$host$canonicalUri?$canonicalQuery&X-Amz-Signature=$signature';
    return url;
  }

  static Future<void> uploadToS3(
    List<int> bytes,
    String objectKey, {
    String contentType = 'application/octet-stream',
  }) async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }
    print('開始上傳數據到 S3: $objectKey');
    print('檔案大小: ${bytes.length} 位元組');

    final endpoint =
        'https://${AWSConfig.s3BucketName}.s3.${AWSConfig.region}.amazonaws.com';
    final response = await _sendSignedRequest(
      endpoint: endpoint,
      method: 'PUT',
      path: '/$objectKey',
      body: Uint8List.fromList(bytes),
      service: 's3',
      contentType: contentType,
    );
    if (response.statusCode == 200) {
      print('檔案已成功上傳到: s3://${AWSConfig.s3BucketName}/$objectKey');
    } else {
      throw Exception(
        'S3 上傳失敗: ${response.statusCode} ${response.reasonPhrase}',
      );
    }
  }

  static Future<String> copyObject(
    String sourceUrl,
    String destinationKey,
  ) async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }

    // 解析源 URL
    if (!sourceUrl.startsWith('s3://')) {
      throw Exception('源 URL 必須以 s3:// 開頭');
    }

    final sourceParts = sourceUrl.replaceAll('s3://', '').split('/');
    if (sourceParts.isEmpty) {
      throw Exception('源 URL 格式無效');
    }

    final sourceBucket = sourceParts[0];
    final sourceKey = sourceParts.sublist(1).join('/');

    if (sourceKey.isEmpty) {
      throw Exception('源鍵不能為空');
    }

    final endpoint =
        'https://${AWSConfig.s3BucketName}.s3.${AWSConfig.region}.amazonaws.com';
    final headers = {'x-amz-copy-source': '/$sourceBucket/$sourceKey'};

    final response = await _sendSignedRequest(
      endpoint: endpoint,
      method: 'PUT',
      path: '/$destinationKey',
      service: 's3',
      extraHeaders: headers,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final resultUrl = 's3://${AWSConfig.s3BucketName}/$destinationKey';
      print('檔案已成功複製到: $resultUrl');
      return resultUrl;
    } else {
      throw Exception('複製失敗，狀態碼: ${response.statusCode}, 回應: ${response.body}');
    }
  }

  // 檢查 S3 URL 是否存在
  static Future<bool> checkS3UrlExists(String s3Url) async {
    try {
      if (!AWSConfig.isConfigured()) {
        throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
      }

      if (!s3Url.startsWith('s3://')) {
        throw Exception('S3 URL 必須以 s3:// 開頭');
      }

      final parts = s3Url.replaceAll('s3://', '').split('/');
      if (parts.isEmpty) {
        throw Exception('S3 URL 格式無效');
      }

      final bucket = parts[0];
      final key = parts.sublist(1).join('/');

      final endpoint = 'https://$bucket.s3.${AWSConfig.region}.amazonaws.com';
      final response = await _sendSignedRequest(
        endpoint: endpoint,
        method: 'HEAD',
        path: '/$key',
        service: 's3',
      );

      return response.statusCode == 200;
    } catch (e) {
      print('檢查 S3 URL 存在性失敗: $e');
      return false;
    }
  }

  // 發送簽名請求（公開方法，供其他服務使用）
  static Future<http.Response> sendSignedRequest({
    required String endpoint,
    required String method,
    required String path,
    dynamic body,
    required String service,
    String contentType = '',
    String? amzTarget,
    int? contentLength,
    String? region,
    Map<String, String>? headers,
  }) {
    return _sendSignedRequest(
      endpoint: endpoint,
      method: method,
      path: path,
      body: body,
      service: service,
      contentType: contentType,
      amzTarget: amzTarget,
      contentLength: contentLength,
      region: region,
      extraHeaders: headers,
    );
  }

  static Future<String> uploadStringToS3(
    String content,
    String objectKey,
  ) async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }
    final bytes = utf8.encode(content);
    await uploadToS3(
      bytes,
      objectKey,
      contentType: 'text/plain; charset=utf-8',
    );
    final resultUrl = 's3://${AWSConfig.s3BucketName}/$objectKey';
    print('字幕文件已成功上傳到: $resultUrl');
    return resultUrl;
  }

  static Future<http.Response> _sendSignedRequest({
    required String endpoint,
    required String method,
    required String path,
    dynamic body,
    required String service,
    String contentType = '',
    String? amzTarget,
    int? contentLength,
    String? region,
    Map<String, String>? extraHeaders,
  }) async {
    if (!AWSConfig.isConfigured()) {
      throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
    }
    final targetRegion = region ?? AWSConfig.region;
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateString = _formatDate(now);
    final split = path.split('?');
    final rawPath = split[0].isEmpty ? '/' : split[0];
    final rawQuery = split.length > 1 ? split.sublist(1).join('?') : '';
    final uri = Uri.parse(
      '$endpoint$rawPath${rawQuery.isNotEmpty ? '?$rawQuery' : ''}',
    );
    final payloadHash = _computePayloadHash(body);
    final host = uri.host;
    final headers = <String, String>{'Host': host, 'X-Amz-Date': amzDate};
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    if (contentType.trim().isNotEmpty) {
      headers['Content-Type'] = contentType;
    }
    if (amzTarget != null && amzTarget.trim().isNotEmpty) {
      headers['X-Amz-Target'] = amzTarget;
    }
    if (service == 's3') {
      headers['x-amz-content-sha256'] = payloadHash;
    }
    final canonicalUri = _encodePath(rawPath);
    final canonicalQueryString = _canonicalizeRawQuery(rawQuery);
    final canonicalHeaders = _buildCanonicalHeaders(headers);
    final signedHeaders = _buildSignedHeaders(headers);
    final canonicalRequest = [
      method,
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');
    final credentialScope = '$dateString/$targetRegion/$service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _hash(canonicalRequest),
    ].join('\n');
    final signingKey = _getSigningKey(
      dateString: dateString,
      region: targetRegion,
      service: service,
    );
    final signature = _hmacSha256Hex(signingKey, stringToSign);
    final authorization =
        'AWS4-HMAC-SHA256 Credential=${AWSConfig.accessKeyId}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';
    headers['Authorization'] = authorization;

    int retryCount = 0;
    while (true) {
      final client = http.Client();
      try {
        if (body is Stream<List<int>>) {
          if (contentLength == null) {
            throw Exception('Stream 上傳需要 contentLength');
          }
          final req = http.StreamedRequest(method, uri);
          req.headers.addAll(headers);
          req.contentLength = contentLength;

          // 正确处理 Stream：等待 addStream 完成后再发送请求
          // 注意：不能使用 await addStream，否则会导致死锁
          body.listen(
            (chunk) {
              req.sink.add(chunk);
            },
            onDone: () {
              req.sink.close();
            },
            onError: (e) {
              req.sink.addError(e);
              req.sink.close();
            },
            cancelOnError: true,
          );

          final streamed = await client
              .send(req)
              .timeout(
                const Duration(minutes: 5), // 增加超时时间到5分钟，适合视频上传
                onTimeout: () {
                  throw TimeoutException('請求超時 (5分鐘)');
                },
              );
          return await http.Response.fromStream(streamed);
        }

        final req = http.Request(method, uri);
        req.headers.addAll(headers);
        if (body is Uint8List) {
          req.bodyBytes = body;
        } else if (body is List<int>) {
          req.bodyBytes = Uint8List.fromList(body);
        } else if (body is String) {
          req.body = body;
        } else if (body != null) {
          req.body = body.toString();
        }
        final streamed = await client
            .send(req)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('請求超時 (30秒)');
              },
            );
        return await http.Response.fromStream(streamed);
      } catch (e) {
        // 如果是 Stream Body，無法重試（Stream 可能已被消耗）
        if (body is Stream<List<int>>) {
          rethrow;
        }

        retryCount++;
        if (retryCount >= 3) {
          print('請求失敗，已達到最大重試次數: $e');
          rethrow;
        }
        print('請求失敗 (嘗試 $retryCount/3): $e. 1秒後重試...');
        await Future.delayed(const Duration(seconds: 1));
      } finally {
        client.close();
      }
    }
  }

  // 獲取 MediaConvert 服務端點
  static Future<String> getMediaConvertEndpoint() async {
    try {
      // 使用 describeEndpoints API 獲取正確的 MediaConvert 端點
      final endpoint = 'https://mediaconvert.${AWSConfig.region}.amazonaws.com';
      final path = '/2017-08-29/endpoints';
      final requestBody = jsonEncode({});

      // 發送請求獲取端點
      final response = await _sendSignedRequest(
        endpoint: endpoint,
        method: 'POST',
        path: path,
        body: requestBody,
        service: 'mediaconvert',
        contentType: 'application/json; charset=utf-8',
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData.containsKey('endpoints') &&
            responseData['endpoints'] is List &&
            responseData['endpoints'].isNotEmpty) {
          final mediaConvertEndpoint = responseData['endpoints'][0]['url'];
          print(
            'Using MediaConvert endpoint from describeEndpoints: $mediaConvertEndpoint',
          );
          return mediaConvertEndpoint;
        }
      }

      // 如果 API 調用失敗，回退到硬編碼端點
      final fallbackEndpoint =
          'https://mediaconvert.${AWSConfig.region}.amazonaws.com';
      print(
        'Falling back to hardcoded MediaConvert endpoint: $fallbackEndpoint',
      );
      return fallbackEndpoint;
    } catch (e) {
      // 異常情況下回退到硬編碼端點
      final fallbackEndpoint =
          'https://mediaconvert.${AWSConfig.region}.amazonaws.com';
      print(
        'Error getting MediaConvert endpoint: $e. Falling back to hardcoded endpoint: $fallbackEndpoint',
      );
      return fallbackEndpoint;
    }
  }

  // 添加片尾
  static Future<String> addEnding(
    String videoUrl, {
    bool isPortrait = false,
  }) async {
    try {
      if (!AWSConfig.isConfigured()) {
        throw Exception('AWS設定不完整，請先設定金鑰、Region、Bucket');
      }

      // 1. 從影片 URL 中提取 S3 路徑
      final videoKey = videoUrl.replaceAll(
        's3://${AWSConfig.s3BucketName}/',
        '',
      );

      // 2. 定義片尾影片路徑
      final endingVideoUrl =
          's3://${AWSConfig.s3BucketName}/videoEnding/videoEnding.mp4';

      // 3. 構建輸出檔名
      final videoFileName = videoKey.split('/').last;
      final dot = videoFileName.lastIndexOf('.');
      final fileNameWithoutExtension = dot > 0
          ? videoFileName.substring(0, dot)
          : videoFileName;
      final extension = dot > 0 ? videoFileName.substring(dot + 1) : 'mp4';
      final extLower = extension.toLowerCase();

      final container = extLower == 'mov' ? 'MOV' : 'MP4';
      final outputExtension = extLower == 'mov' ? 'mov' : 'mp4';

      final outputFileName =
          '${fileNameWithoutExtension}_with_ending.$outputExtension';
      final lastSlashIndex = videoKey.lastIndexOf('/');
      final outputPrefix = lastSlashIndex >= 0
          ? videoKey.substring(0, lastSlashIndex + 1)
          : 'temp/';

      // 4. 構建 MediaConvert 作業
      final inputs = [
        {
          'AudioSelectors': {
            'Audio Selector 1': {'DefaultSelection': 'DEFAULT'},
          },
          'VideoSelector': {'ColorSpace': 'FOLLOW', 'Rotate': 'AUTO'},
          'FileInput': videoUrl,
        },
        {
          'AudioSelectors': {
            'Audio Selector 1': {'DefaultSelection': 'DEFAULT'},
          },
          'VideoSelector': {'ColorSpace': 'FOLLOW', 'Rotate': 'AUTO'},
          'FileInput': endingVideoUrl,
        },
      ];

      final outWidth = isPortrait ? 720 : 1280;
      final outHeight = isPortrait ? 1280 : 720;
      final jobSettings = {
        'Inputs': inputs,
        'OutputGroups': [
          {
            'Name': 'File Group',
            'OutputGroupSettings': {
              'Type': 'FILE_GROUP_SETTINGS',
              'FileGroupSettings': {
                'Destination': 's3://${AWSConfig.s3BucketName}/$outputPrefix',
              },
            },
            'Outputs': [
              {
                'Extension': outputExtension,
                'NameModifier': '_with_ending',
                'ContainerSettings': {
                  'Container': container,
                  if (container == 'MP4')
                    'Mp4Settings': {
                      'CslgAtom': 'INCLUDE',
                      'CttsVersion': 0,
                      'FreeSpaceBox': 'EXCLUDE',
                      'MoovPlacement': 'PROGRESSIVE_DOWNLOAD',
                      'Mpeg4DurationMode': 'DEFAULT',
                      'Mpeg4FastStartEnabled': true,
                      'Mp4iAtom': 'INCLUDE',
                      'PictAtom': 'EXCLUDE',
                      'TrellisProcessing': 'DISABLED',
                      'VideoDuration': 'DEFAULT_CODEC_DURATION',
                      'AudioDuration': 'DEFAULT_CODEC_DURATION',
                      'ErnAtom': 'EXCLUDE',
                      'TimedMetadata': 'EXCLUDE',
                      'Hinting': 'NONE',
                      'TrackPhrase': 'track',
                      'AudioTrackType': 'NOT_SET',
                    },
                },
                'VideoDescription': {
                  'Width': outWidth,
                  'Height': outHeight,
                  'CodecSettings': {
                    'Codec': 'H_264',
                    'H264Settings': {
                      'RateControlMode': 'QVBR',
                      'MaxBitrate': 20000000,
                      'QvbrSettings': {'QvbrQualityLevel': 8},
                      'FramerateControl': 'INITIALIZE_FROM_SOURCE',
                      'FramerateConversionAlgorithm': 'DUPLICATE_DROP',
                      'CodecProfile': 'MAIN',
                      'CodecLevel': 'AUTO',
                      'InterlaceMode': 'PROGRESSIVE',
                      'NumberBFramesBetweenReferenceFrames': 2,
                      'GopClosedCadence': 1,
                      'GopSize': 90,
                      'Slices': 1,
                      'BufferSize': 10000000,
                      'TemporalAdaptiveQuantization': 'ENABLED',
                      'SpatialAdaptiveQuantization': 'ENABLED',
                      'EntropyEncoding': 'CABAC',
                      'SceneChangeDetect': 'ENABLED',
                      'QualityTuningLevel': 'SINGLE_PASS',
                      'FlickerAdaptiveQuantization': 'ENABLED',
                      'UnregisteredSeiTimecode': 'DISABLED',
                      'GopSizeUnits': 'FRAMES',
                      'ParControl': 'INITIALIZE_FROM_SOURCE',
                      'NumberReferenceFrames': 3,
                      'Syntax': 'DEFAULT',
                      'Softness': 0,
                      'Telecine': 'NONE',
                      'MinIInterval': 0,
                      'AdaptiveQuantization': 'HIGH',
                      'CodecVersion': 'DEFAULT',
                      'ProfileOverride': 'DISABLED',
                    },
                  },
                  'ScalingBehavior': 'DEFAULT',
                },
                'AudioDescriptions': [
                  {
                    'CodecSettings': {
                      'Codec': 'AAC',
                      'AacSettings': {
                        'AudioDescriptionBroadcasterMix': 'NORMAL',
                        'Bitrate': 192000,
                        'RateControlMode': 'CBR',
                        'CodecProfile': 'LC',
                        'CodingMode': 'CODING_MODE_2_0',
                        'RawFormat': 'NONE',
                        'SampleRate': 48000,
                        'Specification': 'MPEG4',
                      },
                    },
                  },
                ],
              },
            ],
          },
        ],
        'AdAvailOffset': 0,
      };

      final jobRequest = {
        'UserMetadata': {'application': 'video-editor'},
        'Role': AWSConfig.mediaConvertRoleArn,
        'Settings': jobSettings,
      };

      // 5. 獲取 MediaConvert 端點
      final mediaConvertEndpoint = await getMediaConvertEndpoint();

      // 6. 提交 MediaConvert 作業
      final response = await _sendSignedRequest(
        endpoint: mediaConvertEndpoint,
        method: 'POST',
        path: '/2017-08-29/jobs',
        service: 'mediaconvert',
        body: jsonEncode(jobRequest),
        contentType: 'application/json; charset=utf-8',
      );

      if (response.statusCode != 201) {
        throw Exception('創建 MediaConvert 作業失敗: ${response.body}');
      }

      final jobData = jsonDecode(response.body);
      // MediaConvert CreateJob response key can be 'job' (lowercase) or 'Job' (uppercase)
      final job = jobData['job'] ?? jobData['Job'];
      if (job == null) {
        throw Exception('MediaConvert API 回應體不包含 job 欄位: ${response.body}');
      }
      final jobId = job['Id'] ?? job['id']; // Also check id casing

      // 7. 等待作業完成
      await _waitForMediaConvertJob(mediaConvertEndpoint, jobId);

      // 8. 構建輸出文件路徑
      final outputVideoKey = '$outputPrefix$outputFileName';
      return 's3://${AWSConfig.s3BucketName}/$outputVideoKey';
    } catch (e) {
      print('添加片尾失敗: $e');
      // 如果失敗，返回原始影片
      return videoUrl;
    }
  }

  // 等待 MediaConvert 作業完成
  static Future<void> _waitForMediaConvertJob(
    String endpoint,
    String jobId,
  ) async {
    for (int i = 0; i < 120; i++) {
      // 最多等待 20 分鐘
      await Future.delayed(const Duration(seconds: 10));

      final response = await _sendSignedRequest(
        endpoint: endpoint,
        method: 'GET',
        path: '/2017-08-29/jobs/$jobId',
        service: 'mediaconvert',
      );

      if (response.statusCode == 200) {
        final jobData = jsonDecode(response.body);
        // 檢查回應體結構
        if (!jobData.containsKey('job')) {
          throw Exception('MediaConvert API 回應體不包含 job 欄位');
        }
        if (jobData['job'] == null) {
          throw Exception('MediaConvert API 回應體中的 job 欄位為 null');
        }
        if (!jobData['job'].containsKey('status')) {
          throw Exception('MediaConvert API 回應體中的 job 欄位不包含 status 欄位');
        }

        final status = jobData['job']['status'];

        if (status == 'COMPLETE') {
          return;
        } else if (status == 'ERROR') {
          // 檢查是否包含錯誤資訊
          String errorMessage = '未知錯誤';
          if (jobData['job'].containsKey('errorMessage')) {
            errorMessage = jobData['job']['errorMessage'] as String;
          } else if (jobData['job'].containsKey('messages') &&
              jobData['job']['messages'].containsKey('error')) {
            final errors = jobData['job']['messages']['error'] as List;
            if (errors.isNotEmpty) {
              errorMessage = errors.join(', ');
            }
          }
          throw Exception('MediaConvert 作業失敗: $errorMessage');
        }
      }
    }

    throw Exception('MediaConvert 作業超時');
  }

  static String _computePayloadHash(dynamic body) {
    if (body is Stream<List<int>>) {
      return 'UNSIGNED-PAYLOAD';
    }
    if (body is Uint8List) {
      return sha256.convert(body).toString();
    }
    if (body is List<int>) {
      return sha256.convert(body).toString();
    }
    if (body is String) {
      return _hash(body);
    }
    return _hash('');
  }

  static String _buildCanonicalHeaders(Map<String, String> headers) {
    final lower = <String, String>{};
    headers.forEach((k, v) {
      lower[k.toLowerCase()] = v.trim().replaceAll(RegExp(r'\s+'), ' ');
    });
    final keys = lower.keys.toList()..sort();
    return keys.map((k) => '$k:${lower[k]}\n').join();
  }

  static String _buildSignedHeaders(Map<String, String> headers) {
    final keys = headers.keys.map((k) => k.toLowerCase()).toSet().toList()
      ..sort();
    return keys.join(';');
  }

  static String _canonicalizeRawQuery(String rawQuery) {
    if (rawQuery.trim().isEmpty) return '';
    final parts = rawQuery.split('&');
    final pairs = <MapEntry<String, String>>[];
    for (final part in parts) {
      if (part.isEmpty) continue;
      final idx = part.indexOf('=');
      final k = idx >= 0 ? part.substring(0, idx) : part;
      final v = idx >= 0 ? part.substring(idx + 1) : '';
      final dk = Uri.decodeComponent(k);
      final dv = Uri.decodeComponent(v);
      pairs.add(MapEntry(Uri.encodeComponent(dk), Uri.encodeComponent(dv)));
    }
    pairs.sort((a, b) {
      final c = a.key.compareTo(b.key);
      if (c != 0) return c;
      return a.value.compareTo(b.value);
    });
    return pairs.map((e) => '${e.key}=${e.value}').join('&');
  }

  static String _buildCanonicalQueryString(Map<String, String> queryParams) {
    final pairs = queryParams.entries
        .map(
          (e) => MapEntry(
            Uri.encodeComponent(e.key),
            Uri.encodeComponent(e.value),
          ),
        )
        .toList();
    pairs.sort((a, b) {
      final c = a.key.compareTo(b.key);
      if (c != 0) return c;
      return a.value.compareTo(b.value);
    });
    return pairs.map((e) => '${e.key}=${e.value}').join('&');
  }

  static String _encodePath(String rawPath) {
    final input = rawPath.isEmpty ? '/' : rawPath;
    final segments = input.split('/');
    final encoded = segments.map((s) {
      if (s.isEmpty) return '';
      // 為了防止 Uri.decodeComponent 在遇到未編碼的字元 (例如 %) 時報錯
      // 我們改用更安全的做法：如果它已經被編碼過，就不要再亂動；如果沒有，就直接 encode
      try {
        return Uri.encodeComponent(Uri.decodeComponent(s));
      } catch (e) {
        // 若 decode 失敗 (通常是因為包含了不合法的 % 字元)，直接把原字串 encode
        return Uri.encodeComponent(s);
      }
    }).join('/');
    if (encoded.startsWith('/')) return encoded;
    return '/$encoded';
  }

  static String _hash(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  static String _hmacSha256Hex(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    final bytes = hmac.convert(utf8.encode(data)).bytes;
    final out = StringBuffer();
    for (final b in bytes) {
      out.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return out.toString();
  }

  static List<int> _getSigningKey({
    required String dateString,
    required String region,
    required String service,
  }) {
    final kDate = _hmacSha256Bytes(
      utf8.encode('AWS4${AWSConfig.secretAccessKey}'),
      dateString,
    );
    final kRegion = _hmacSha256Bytes(kDate, region);
    final kService = _hmacSha256Bytes(kRegion, service);
    final kSigning = _hmacSha256Bytes(kService, 'aws4_request');
    return kSigning;
  }

  static List<int> _hmacSha256Bytes(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }
}

class _CachedUrl {
  final String url;
  final DateTime expiry;

  _CachedUrl({required this.url, required this.expiry});
}
