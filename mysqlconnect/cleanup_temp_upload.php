<?php
use Aws\S3\S3Client;
use Aws\Exception\AwsException;

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// AWS 設定
$aws_config = [
    'access_key' => 'AKIAQUJJNUOXKO2IBGHG',
    'secret_key' => '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',
    'region'     => 'ap-southeast-2',
    'bucket_name' => 'fypedu'
];

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    $objectKey = isset($data['objectKey']) ? $data['objectKey'] : null;
    $uploadId = isset($data['uploadId']) ? $data['uploadId'] : null;

    if (!$objectKey) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Missing objectKey parameter.']);
        exit;
    }

    // 檢查是否有 AWS SDK
    if (!file_exists(__DIR__ . '/vendor/autoload.php')) {
        error_log("AWS SDK not found at " . __DIR__ . '/vendor/autoload.php');
        echo json_encode(['status' => 'warning', 'message' => 'AWS SDK not found on server. Cleanup skipped.']);
        exit;
    }

    require_once __DIR__ . '/vendor/autoload.php';

    try {
        $s3Client = new S3Client([
            'version' => 'latest',
            'region'  => $aws_config['region'],
            'credentials' => [
                'key'    => $aws_config['access_key'],
                'secret' => $aws_config['secret_key'],
            ]
        ]);

        $bucket = $aws_config['bucket_name'];

        if ($uploadId) {
            // 中止 Multipart Upload
            $result = $s3Client->abortMultipartUpload([
                'Bucket'   => $bucket,
                'Key'      => $objectKey,
                'UploadId' => $uploadId,
            ]);
            error_log("Multipart upload aborted for key: $objectKey, UploadId: $uploadId");
            echo json_encode(['status' => 'success', 'message' => 'Multipart upload aborted.']);
        } else {
            // 刪除單一檔案
            $result = $s3Client->deleteObject([
                'Bucket' => $bucket,
                'Key'    => $objectKey,
            ]);
            error_log("Object deleted: $objectKey");
            echo json_encode(['status' => 'success', 'message' => 'Temporary file deleted.']);
        }
    } catch (AwsException $e) {
        http_response_code(500);
        error_log("Error cleaning up S3 object: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => $e->getAwsErrorMessage() ?? $e->getMessage()]);
    } catch (\Exception $e) {
        http_response_code(500);
        error_log("General error: " . $e->getMessage());
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }

} else {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed.']);
}
