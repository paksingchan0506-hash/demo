import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'aws_config.dart';
import 'aws_service.dart';

class WatermarkService {
  // 為影片添加浮水印
  static Future<String> addWatermark(String videoUrl, {bool isPortrait = false}) async {
    try {
      // 驗證 AWS 設定
      if (!AWSConfig.isConfigured()) {
        throw Exception('AWS 設定不完整，請先設定 AWS 金鑰和儲存桶資訊。');
      }

      // 從影片 URL 中提取 S3 物件鍵和原始檔名
      final objectKey = videoUrl.replaceFirst(
        's3://${AWSConfig.s3BucketName}/',
        '',
      );

      // 從原始檔名中提取基本名稱（不包含副檔名）
      final originalFileName = objectKey.split('/').last;
      final baseName = originalFileName.substring(
        0,
        originalFileName.lastIndexOf('.'),
      );

      // 獲取原始檔案的目錄路徑
      final directoryPath = objectKey.substring(
        0,
        objectKey.lastIndexOf('/') + 1,
      );

      // 構造輸出物件鍵（使用原始檔名加上浮水印後綴）
      final outputObjectKey = '$directoryPath${baseName}_with_watermark.mp4';

      // 構造輸出 S3 URL
      final outputUrl = 's3://${AWSConfig.s3BucketName}/$outputObjectKey';

      // 選擇浮水印圖片路徑（優先 PNG，再回退 TGA）
      final bucket = AWSConfig.s3BucketName;
      final pngUrl = 's3://$bucket/image/watermark/EDULogo.png';
      final jpgUrl = 's3://$bucket/image/watermark/EDULogo.jpg';
      final tgaUrl = 's3://$bucket/image/watermark/EDULogo.tga';

      String watermarkImagePath;
      final pngExists = await AWSService.checkS3UrlExists(pngUrl);
      if (pngExists) {
        watermarkImagePath = pngUrl;
      } else {
        final jpgExists = await AWSService.checkS3UrlExists(jpgUrl);
        if (jpgExists) {
          print('檢測到 JPG 浮水印，開始轉換為 PNG 並上傳到 S3');
          final endpoint =
              'https://$bucket.s3.${AWSConfig.region}.amazonaws.com';
          final path = '/image/watermark/EDULogo.jpg';
          final getResp = await AWSService.sendSignedRequest(
            endpoint: endpoint,
            method: 'GET',
            path: path,
            service: 's3',
          );
          if (getResp.statusCode == 200) {
            final jpgBytes = getResp.bodyBytes;
            final decoded = img.decodeImage(jpgBytes);
            if (decoded == null) {
              throw Exception('無法解析 JPG 浮水印圖片');
            }
            final pngBytes = Uint8List.fromList(img.encodePng(decoded));
            await AWSService.uploadToS3(
              pngBytes,
              'image/watermark/EDULogo.png',
            );
            print('已將 JPG 轉換並上傳為 PNG');
            watermarkImagePath = pngUrl;
          } else {
            print(
              '下載 JPG 浮水印失敗: ${getResp.statusCode} ${getResp.reasonPhrase}',
            );
            final tgaExists = await AWSService.checkS3UrlExists(tgaUrl);
            if (tgaExists) {
              watermarkImagePath = tgaUrl;
            } else {
              throw Exception('未找到可用的浮水印圖片 (PNG/TGA)，且 JPG 下載失敗');
            }
          }
        } else {
          final tgaExists = await AWSService.checkS3UrlExists(tgaUrl);
          if (tgaExists) {
            watermarkImagePath = tgaUrl;
          } else {
            throw Exception('未找到可用的浮水印圖片，請在 S3 上傳 EDULogo.png 或 EDULogo.tga');
          }
        }
      }

      final outputWidth = isPortrait ? 720 : 1280;
      final outputHeight = isPortrait ? 1280 : 720;
      final margin = 20;
      final baseSize = ((outputWidth * 0.06).round()).clamp(48, 96).toInt();
      final logoWidth = baseSize;
      final logoHeight = baseSize;
      final logoX = outputWidth - logoWidth - margin;
      final logoY = margin;

      // 構造 MediaConvert API 請求體
      final Map<String, dynamic> requestBody = {
        'Role': AWSConfig.mediaConvertRoleArn,
        'Settings': {
          'Inputs': [
            {
              'FileInput': videoUrl,
              'AudioSelectors': {
                'Audio Selector 1': {'DefaultSelection': 'DEFAULT'},
              },
              'VideoSelector': {},
              'TimecodeSource': 'ZEROBASED',
            },
          ],
          'OutputGroups': [
            {
              'Name': 'File Group',
              'OutputGroupSettings': {
                'Type': 'FILE_GROUP_SETTINGS',
                'FileGroupSettings': {
                  'Destination':
                      's3://${AWSConfig.s3BucketName}/${objectKey.substring(0, objectKey.lastIndexOf('/') + 1)}',
                },
              },
              'Outputs': [
                {
                  'NameModifier': '_with_watermark',
                  'VideoDescription': {
                    'Width': outputWidth,
                    'Height': outputHeight,
                    'ScalingBehavior': 'DEFAULT',
                    'TimecodeInsertion': 'DISABLED',
                    'AntiAlias': 'ENABLED',
                    'Sharpness': 50,
                    'CodecSettings': {
                      'Codec': 'H_264',
                      'H264Settings': {
                        'InterlaceMode': 'PROGRESSIVE',
                        'NumberReferenceFrames': 3,
                        'Syntax': 'DEFAULT',
                        'Softness': 0,
                        'GopClosedCadence': 1,
                        'GopSize': 90,
                        'Slices': 1,
                        'GopBReference': 'DISABLED',
                        'SlowPal': 'DISABLED',
                        'SpatialAdaptiveQuantization': 'ENABLED',
                        'TemporalAdaptiveQuantization': 'ENABLED',
                        'FlickerAdaptiveQuantization': 'DISABLED',
                        'EntropyEncoding': 'CABAC',
                        'Bitrate': 5000000,
                        'FramerateControl': 'SPECIFIED',
                        'FramerateNumerator': 30,
                        'FramerateDenominator': 1,
                        'RateControlMode': 'CBR',
                        'CodecProfile': 'MAIN',
                        'CodecLevel': 'AUTO',
                        'FieldEncoding': 'PAFF',
                        'SceneChangeDetect': 'ENABLED',
                        'QualityTuningLevel': 'SINGLE_PASS',
                        'Telecine': 'NONE',
                        'MinIInterval': 0,
                        'AdaptiveQuantization': 'HIGH',
                        'CodecVersion': 'DEFAULT',
                        'LumaDenoise': 0,
                        'ChromaDenoise': 0,
                      },
                    },
                    'AfdSignaling': 'NONE',
                    'DropFrameTimecode': 'ENABLED',
                    'RespondToAfd': 'NONE',
                    'ColorMetadata': 'INSERT',
                    'VideoPreprocessors': {
                      'ImageInserter': {
                        'InsertableImages': [
                          {
                            'ImageInserterInput': watermarkImagePath,
                            'Opacity': 60,
                            'Layer': 1,
                            'Width': logoWidth,
                            'Height': logoHeight,
                            'ImageX': logoX,
                            'ImageY': logoY,
                            'StartTime': '00:00:00:00',
                          },
                        ],
                      },
                    },
                  },
                  'AudioDescriptions': [
                    {
                      'AudioSourceName': 'Audio Selector 1',
                      'CodecSettings': {
                        'Codec': 'AAC',
                        'AacSettings': {
                          'AudioDescriptionBroadcasterMix': 'NORMAL',
                          'RateControlMode': 'CBR',
                          'CodecProfile': 'LC',
                          'CodingMode': 'CODING_MODE_2_0',
                          'RawFormat': 'NONE',
                          'SampleRate': 48000,
                          'Specification': 'MPEG4',
                          'Bitrate': 192000,
                        },
                      },
                      'LanguageCodeControl': 'FOLLOW_INPUT',
                    },
                  ],
                  'ContainerSettings': {
                    'Container': 'MP4',
                    'Mp4Settings': {
                      'CslgAtom': 'INCLUDE',
                      'FreeSpaceBox': 'EXCLUDE',
                      'MoovPlacement': 'PROGRESSIVE_DOWNLOAD',
                    },
                  },
                  'CaptionDescriptions': [],
                },
              ],
            },
          ],
          'TimecodeConfig': {'Source': 'ZEROBASED'},
        },
        'AccelerationSettings': {'Mode': 'DISABLED'},
        'StatusUpdateInterval': 'SECONDS_60',
        'Priority': 0,
      };

      // 獲取 AWS MediaConvert 的服務端點
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

      if (response.statusCode == 201) {
        // 作業創建成功，解析回應獲取 jobId
        final responseData = jsonDecode(response.body);

        // 安全檢查回應結構
        if (responseData == null || !responseData.containsKey('job')) {
          throw Exception(
            'MediaConvert 回應結構無效: 未找到 job 欄位。回應: ${response.body}',
          );
        }

        final jobData = responseData['job'];
        if (jobData == null || !jobData.containsKey('id')) {
          throw Exception('MediaConvert 回應結構無效: 未找到 job.id 欄位');
        }

        final jobId = jobData['id'];
        if (jobId == null || jobId.toString().isEmpty) {
          throw Exception('MediaConvert 回應無效: Job ID 為空');
        }
        print('成功創建 MediaConvert 作業，Job ID: $jobId');

        // 等待作業完成並獲取完成後的回應
        final completedJob = await _waitForMediaConvertJob(jobId);
        print('MediaConvert 作業完成回應: ${jsonEncode(completedJob)}');

        // 從完成的作業回應中提取實際的輸出檔案路徑
        String actualOutputUrl;
        if (completedJob.containsKey('job') &&
            completedJob['job'].containsKey('outputGroupDetails') &&
            completedJob['job']['outputGroupDetails'].isNotEmpty &&
            completedJob['job']['outputGroupDetails'][0].containsKey(
              'outputDetails',
            ) &&
            completedJob['job']['outputGroupDetails'][0]['outputDetails']
                .isNotEmpty &&
            completedJob['job']['outputGroupDetails'][0]['outputDetails'][0]
                .containsKey('outputFilePaths')) {
          actualOutputUrl =
              completedJob['job']['outputGroupDetails'][0]['outputDetails'][0]['outputFilePaths'][0];
          print('實際輸出檔案路徑: $actualOutputUrl');
        } else {
          // 如果無法從回應中獲取實際輸出路徑，使用構造的路徑作為後備
          print('無法從 MediaConvert 回應中提取實際輸出路徑，使用構造的路徑');
          print('回應結構: ${jsonEncode(completedJob)}');
          actualOutputUrl = outputUrl;
        }

        // 作業完成後返回實際的輸出 URL
        return actualOutputUrl;
      } else {
        // 列印回應體以獲取更詳細的錯誤資訊
        final responseBody = response.body;
        print('MediaConvert API 錯誤回應: $responseBody');
        throw Exception(
          '創建 MediaConvert 作業失敗: ${response.statusCode} ${response.reasonPhrase}. 回應內容: $responseBody',
        );
      }
    } catch (e) {
      throw Exception('添加浮水印時發生錯誤: $e');
    }
  }

  // 獲取 MediaConvert 作業狀態
  static Future<Map<String, dynamic>> getMediaConvertJobStatus(
    String jobId,
  ) async {
    try {
      // 獲取 MediaConvert 服務端點
      final endpoint = await AWSService.getMediaConvertEndpoint();

      // 構造請求路徑
      final path = '/2017-08-29/jobs/$jobId';

      // 發送帶有 AWS 簽名的 GET 請求來獲取作業狀態
      final response = await AWSService.sendSignedRequest(
        endpoint: endpoint,
        method: 'GET',
        path: path,
        service: 'mediaconvert',
        contentType: 'application/json',
      );

      if (response.statusCode == 200) {
        // 列印完整回應以進行調試
        print('MediaConvert 作業狀態 API 回應: ${response.body}');
        // 解析回應體
        final responseData = jsonDecode(response.body);
        return responseData;
      } else {
        // 處理 API 調用失敗的情況
        final responseBody = response.body;
        print('MediaConvert API 錯誤回應: $responseBody');
        throw Exception(
          '獲取 MediaConvert 作業狀態失敗: ${response.statusCode} ${response.reasonPhrase}. 回應內容: $responseBody',
        );
      }
    } catch (e) {
      throw Exception('獲取 MediaConvert 作業狀態時發生錯誤: $e');
    }
  }

  // 等待 MediaConvert 作業完成
  static Future<Map<String, dynamic>> _waitForMediaConvertJob(
    String jobId,
  ) async {
    try {
      // 輪詢作業狀態，直到作業完成或失敗
      // 設定最大重試次數，避免無限循環 (120次 * 5秒 = 600秒 = 10分鐘)
      int maxRetries = 120;
      int retryCount = 0;

      while (retryCount < maxRetries) {
        final jobStatus = await getMediaConvertJobStatus(jobId);

        // 安全檢查回應結構
        if (!jobStatus.containsKey('job')) {
          throw Exception('MediaConvert 狀態回應結構無效: 未找到 job 欄位');
        }

        final jobData = jobStatus['job'];
        if (jobData == null || !jobData.containsKey('status')) {
          throw Exception('MediaConvert 狀態回應結構無效: 未找到 job.status 欄位');
        }

        final status = jobData['status'];
        if (status == null) {
          throw Exception('MediaConvert 狀態回應無效: Status 為 null');
        }

        // 將狀態轉換為大寫，確保大小寫不敏感的匹配
        final statusUpper = status.toString().toUpperCase();

        switch (statusUpper) {
          case 'COMPLETE':
            // 作業成功完成，返回結果
            return jobStatus;
          case 'FAILED':
          case 'ERROR':
            // 作業失敗或出錯，拋出異常
            final errorMessage =
                jobData['errorMessage'] ?? 'MediaConvert 作業失敗，狀態: $status';
            final errorCode = jobData['errorCode'];

            // 列印詳細的錯誤資訊
            print('❌ MediaConvert 作業失敗');
            print('   狀態: $status');
            if (errorCode != null) {
              print('   錯誤代碼: $errorCode');
            }
            print('   錯誤消息: $errorMessage');
            print('   完整作業資訊: ${jsonEncode(jobData)}');

            // 根據錯誤代碼提供更具體的解決方案
            if (errorMessage.contains('Unable to open input file')) {
              print('\n🔧 可能的解決方案:');
              print('   1. 檢查 S3 影片檔案路徑是否正確');
              print('   2. 確保 MediaConvert 角色有權限訪問該 S3 檔案');
              print('   3. 驗證 S3 存儲桶策略是否允許 MediaConvert 訪問');
              print('   4. 確認檔案格式受支持');
              // 添加安全檢查以避免空指標異常
              if (jobData.containsKey('Settings') &&
                  jobData['Settings'] != null &&
                  jobData['Settings'].containsKey('Inputs') &&
                  jobData['Settings']['Inputs'] != null &&
                  jobData['Settings']['Inputs'].isNotEmpty &&
                  jobData['Settings']['Inputs'][0] != null &&
                  jobData['Settings']['Inputs'][0].containsKey('FileInput')) {
                print(
                  '   5. 使用 AWS CLI 驗證檔案是否存在: aws s3 ls ${jobData['Settings']['Inputs'][0]['FileInput']}',
                );
              }
            } else if (errorMessage.contains('Unable to open watermark file')) {
              print('\n🔧 可能的解決方案:');
              print('   1. 檢查浮水印圖像檔案路徑是否正確');
              print('   2. 確保 MediaConvert 角色有權限訪問該浮水印圖像');
              print('   3. 驗證浮水印圖像格式是否受支持 (推薦使用 PNG 或 TGA)');
              // 添加安全檢查以避免空指標異常
              if (jobData.containsKey('Settings') &&
                  jobData['Settings'] != null &&
                  jobData['Settings'].containsKey('Inputs') &&
                  jobData['Settings']['Inputs'] != null &&
                  jobData['Settings']['Inputs'].length > 1 &&
                  jobData['Settings']['Inputs'][1] != null &&
                  jobData['Settings']['Inputs'][1].containsKey('FileInput')) {
                print(
                  '   4. 使用 AWS CLI 驗證檔案是否存在: aws s3 ls ${jobData['Settings']['Inputs'][1]['FileInput']}',
                );
              }
            }

            throw Exception(
              'MediaConvert 作業失敗: $errorMessage${errorCode != null ? ' (錯誤代碼: $errorCode)' : ''}',
            );
          case 'IN_PROGRESS':
          case 'PROGRESSING':
          case 'SUBMITTED':
            // 作業正在進行中，等待一段時間後繼續輪詢
            if (retryCount % 6 == 0) {
              // 每 30 秒打印一次
              print(
                'MediaConvert 作業正在進行中，狀態: $status，等待 5 秒後繼續檢查... (已等待 ${retryCount * 5} 秒)',
              );
            }
            await Future.delayed(Duration(seconds: 5));
            retryCount++;
            break;
          default:
            // 未知作業狀態，拋出異常
            print('❌ 未知的 MediaConvert 作業狀態: $status');
            print('   完整作業資訊: ${jsonEncode(jobData)}');
            throw Exception('未知的 MediaConvert 作業狀態: $status');
        }
      }

      throw Exception('MediaConvert 作業超時 (超過 10 分鐘)');
    } catch (e) {
      throw Exception('等待 MediaConvert 作業完成時發生錯誤: $e');
    }
  }
}
