class AWSConfig {
  static String accessKeyId = 'AKIAQUJJNUOXKO2IBGHG';
  static String secretAccessKey = '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';
  static String region = 'ap-southeast-2';
  static String s3BucketName = 'fypedu';
  static String accountId = '043573420974';
  static String mediaConvertRoleArn =
      'arn:aws:iam::043573420974:role/MediaConvertRole';
  static bool useTransferAcceleration = false;

  static void setConfig({
    String? accessKeyId,
    String? secretAccessKey,
    String? region,
    String? s3BucketName,
    String? accountId,
    String? mediaConvertRoleArn,
    bool? useTransferAcceleration,
  }) {
    if (accessKeyId != null) {
      AWSConfig.accessKeyId = accessKeyId;
    }
    if (secretAccessKey != null) {
      AWSConfig.secretAccessKey = secretAccessKey;
    }
    if (region != null) {
      AWSConfig.region = region;
    }
    if (s3BucketName != null) {
      AWSConfig.s3BucketName = s3BucketName;
    }
    if (accountId != null) {
      AWSConfig.accountId = accountId;
    }
    if (mediaConvertRoleArn != null) {
      AWSConfig.mediaConvertRoleArn = mediaConvertRoleArn;
    }
    if (useTransferAcceleration != null) {
      AWSConfig.useTransferAcceleration = useTransferAcceleration;
    }
  }

  static bool isConfigured() {
    return accessKeyId.isNotEmpty &&
        secretAccessKey.isNotEmpty &&
        region.isNotEmpty &&
        s3BucketName.isNotEmpty &&
        accountId.isNotEmpty;
  }
}
