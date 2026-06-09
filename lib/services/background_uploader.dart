import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'aws_config.dart';
import 'aws_service.dart';

class BackgroundUploader {
  static const MethodChannel _channel = MethodChannel(
    'com.example.realvideo/uploader',
  );

  static final BackgroundUploader _instance = BackgroundUploader._internal();
  factory BackgroundUploader() => _instance;
  BackgroundUploader._internal() {
    _channel.setMethodCallHandler(_handleCallback);
  }

  final _completeCtrl = StreamController<String>.broadcast();
  Stream<String> get onCompleted => _completeCtrl.stream;
  final _partCompleteCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPartCompleted => _partCompleteCtrl.stream;
  final _progressCtrl = StreamController<Map<String, num>>.broadcast();
  Stream<Map<String, num>> get onProgress => _progressCtrl.stream;

  Future<void> _handleCallback(MethodCall call) async {
    switch (call.method) {
      case 'uploadCompleted':
        final s3Url = call.arguments as String? ?? '';
        if (s3Url.isNotEmpty) _completeCtrl.add(s3Url);
        break;
      case 'uploadFailed':
        // ignore: avoid_print
        print('Background upload failed: ${call.arguments}');
        break;
      case 'uploadPartCompleted':
        final m = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        _partCompleteCtrl.add(m);
        break;
      case 'uploadProgress':
        final m = (call.arguments as Map?)?.cast<String, num>() ?? {};
        _progressCtrl.add(m);
        break;
    }
  }

  // Start a background upload using a presigned PUT URL
  Future<String> startBackgroundUpload({
    required File file,
    required String objectKey,
    int expiresSeconds = 3600,
  }) async {
    final presigned = await AWSService.generatePresignedPutUrl(
      objectKey,
      expiresSeconds: expiresSeconds,
    );
    await _channel.invokeMethod('startBackgroundUpload', {
      'filePath': file.path,
      'presignedUrl': presigned,
      'objectKey': objectKey,
      'bucket': AWSConfig.s3BucketName,
    });
    final s3Url = 's3://${AWSConfig.s3BucketName}/$objectKey';
    return s3Url;
  }

  // Start multipart background upload (iOS/Android both supported)
  Future<String> startBackgroundMultipartUpload({
    required File file,
    required String objectKey,
    int expiresSeconds = 3600,
    int chunkSize = 16 * 1024 * 1024,
    void Function(String uploadId)? onInitiated,
  }) async {
    final uploadId = await AWSService.initiateMultipartUpload(objectKey);
    onInitiated?.call(uploadId);
    final length = await file.length();
    final parts = <int, String>{}; // partNumber -> eTag
    int partNumber = 1;
    for (int offset = 0; offset < length; offset += chunkSize, partNumber++) {
      final remaining = length - offset;
      final size = remaining > chunkSize ? chunkSize : remaining;
      final url = await AWSService.generatePresignedUploadPartUrl(
        objectKey: objectKey,
        uploadId: uploadId,
        partNumber: partNumber,
        expiresSeconds: expiresSeconds,
      );
      await _channel.invokeMethod('startBackgroundUploadPart', {
        'filePath': file.path,
        'offset': offset,
        'length': size,
        'presignedUrl': url,
        'uploadId': uploadId,
        'partNumber': partNumber,
        'bucket': AWSConfig.s3BucketName,
        'objectKey': objectKey,
      });
    }
    // Collect completions
    int completed = 0;
    final needed = partNumber - 1;
    final completer = Completer<String>();
    late StreamSubscription sub;
    sub = onPartCompleted.listen((m) async {
      if (m['uploadId'] == uploadId) {
        final pn = (m['partNumber'] as num).toInt();
        final eTag = (m['eTag'] as String?) ?? '';
        if (eTag.isNotEmpty) {
          if (!parts.containsKey(pn)) {
            parts[pn] = eTag;
            completed++;
            _progressCtrl.add({
              'uploadedParts': completed,
              'totalParts': needed,
            });
          }
          if (completed >= needed && !completer.isCompleted) {
            final partList = parts.keys.toList()..sort();
            final completeParts = partList
                .map((k) => {'PartNumber': k, 'ETag': parts[k]})
                .toList();
            await AWSService.completeMultipartUpload(
              objectKey,
              uploadId,
              completeParts,
            );
            completer.complete('s3://${AWSConfig.s3BucketName}/$objectKey');
            await sub.cancel();
          }
        }
      }
    });
    try {
      return await completer.future;
    } catch (e) {
      await AWSService.abortMultipartUpload(objectKey, uploadId);
      rethrow;
    }
  }
}
