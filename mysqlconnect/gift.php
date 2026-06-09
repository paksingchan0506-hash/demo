<?php
/**
 * 檔案名稱：gift.php
 * 功能：直播禮物系統 - 學生送禮給老師，扣除學生 ACoin，增加老師 ACoin，並記錄交易
 * 上傳路徑：/var/www/html/mysqlconnect/gift.php
 */

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

error_reporting(0);
ini_set('display_errors', 0);

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once("common.php");

$GIFT_MAP = [
    'attG01' => ['name' => 'Star',    'emoji' => '⭐', 'cost' => 10],
    'attG02' => ['name' => 'Heart',   'emoji' => '❤️', 'cost' => 30],
    'attG03' => ['name' => 'Crown',   'emoji' => '👑', 'cost' => 60],
    'attG04' => ['name' => 'Diamond', 'emoji' => '💎', 'cost' => 100],
];

try {
    $conn = connectDB();
    if (!$conn) throw new Exception("資料庫連線失敗");

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception("僅支援 POST 請求");
    }

    $raw = file_get_contents("php://input");
    if (empty($raw)) throw new Exception("請求 body 為空");

    $input = json_decode($raw, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception("JSON 解析失敗：" . json_last_error_msg());
    }

    $studentId   = trim($input['studentId']   ?? '');
    $teacherId   = trim($input['teacherId']   ?? '');
    $actTypeId   = trim($input['actTypeId']   ?? '');
    $channelName = trim($input['channelName'] ?? '');

    if ($studentId === '')  throw new Exception("缺少參數：studentId");
    if ($teacherId === '')  throw new Exception("缺少參數：teacherId");
    if ($actTypeId === '')  throw new Exception("缺少參數：actTypeId");
    if ($studentId === $teacherId) throw new Exception("不能送禮給自己");
    if (!isset($GIFT_MAP[$actTypeId])) throw new Exception("無效的禮物類型：$actTypeId");

    $sStudentId   = mysqli_real_escape_string($conn, $studentId);
    $sTeacherId   = mysqli_real_escape_string($conn, $teacherId);
    $sActTypeId   = mysqli_real_escape_string($conn, $actTypeId);
    $sChannelName = mysqli_real_escape_string($conn, $channelName);

    $gift     = $GIFT_MAP[$actTypeId];
    $cost     = (int)$gift['cost'];
    $giftName = $gift['emoji'] . ' ' . $gift['name'];

    // ── 步驟 1：確保 ACoinTransType 有此禮物類型 ──
    $chkSql = "SELECT actTypeId FROM ACoinTransType WHERE actTypeId = '$sActTypeId' LIMIT 1";
    $chkRes = mysqli_query($conn, $chkSql);
    if (!$chkRes || mysqli_num_rows($chkRes) === 0) {
        $autoDesc   = mysqli_real_escape_string($conn, "Live Gift - " . $gift['name']);
        $insertType = "INSERT IGNORE INTO ACoinTransType (actTypeId, description, defaultValue)
                       VALUES ('$sActTypeId', '$autoDesc', $cost)";
        mysqli_query($conn, $insertType);
    }

    // ── 步驟 2：查學生餘額（與 acoin_api.php 相同寫法）──
    $balSql = "SELECT totalAmont FROM ACoinTransaction
               WHERE mId = '$sStudentId'
               ORDER BY transDate DESC, aId DESC LIMIT 1";
    $balRes = mysqli_query($conn, $balSql);
    if (!$balRes) throw new Exception("查詢學生餘額失敗：" . mysqli_error($conn));

    $studentBalance = ($balRes && mysqli_num_rows($balRes) > 0)
        ? (float)mysqli_fetch_assoc($balRes)['totalAmont']
        : 0.0;

    if ($studentBalance < $cost) {
        echo json_encode([
            "status"   => "insufficient",
            "message"  => "ACoin 不足，需要 {$cost} ACoin，目前餘額 {$studentBalance} ACoin",
            "balance"  => $studentBalance,
            "required" => $cost,
        ], JSON_UNESCAPED_UNICODE);
        mysqli_close($conn);
        exit();
    }

    // ── 步驟 3：查老師餘額 ──
    $tBalSql = "SELECT totalAmont FROM ACoinTransaction
                WHERE mId = '$sTeacherId'
                ORDER BY transDate DESC, aId DESC LIMIT 1";
    $tBalRes = mysqli_query($conn, $tBalSql);
    if (!$tBalRes) throw new Exception("查詢老師餘額失敗：" . mysqli_error($conn));

    $teacherBalance = ($tBalRes && mysqli_num_rows($tBalRes) > 0)
        ? (float)mysqli_fetch_assoc($tBalRes)['totalAmont']
        : 0.0;

    // ── 步驟 4：計算新餘額 ──
    $studentNewTotal = $studentBalance - $cost;
    $teacherNewTotal = $teacherBalance + $cost;

    // ── 步驟 5：原子寫入（INSERT 格式完全照抄 acoin_api.php）──
    mysqli_begin_transaction($conn);

    try {
        // 5a. 扣除學生 ACoin
        $studentAId  = genID($conn, "A", 10, "aId", "ACoinTransaction");
        $studentDesc = mysqli_real_escape_string($conn,
            "送出禮物 {$giftName} 給直播主 (頻道: {$channelName})"
        );
        $sql1 = "INSERT INTO ACoinTransaction
                    (aId, transValue, totalAmont, transDate, description, mId, actTypeId)
                 VALUES
                    ('$studentAId', -$cost, $studentNewTotal, NOW(),
                     '$studentDesc', '$sStudentId', '$sActTypeId')";

        if (!mysqli_query($conn, $sql1)) {
            throw new Exception("學生扣款失敗：" . mysqli_error($conn));
        }

        // 5b. 增加老師 ACoin
        $teacherAId  = genID($conn, "A", 10, "aId", "ACoinTransaction");
        $teacherDesc = mysqli_real_escape_string($conn,
            "收到禮物 {$giftName} 來自直播觀眾 (頻道: {$channelName})"
        );
        $sql2 = "INSERT INTO ACoinTransaction
                    (aId, transValue, totalAmont, transDate, description, mId, actTypeId)
                 VALUES
                    ('$teacherAId', $cost, $teacherNewTotal, NOW(),
                     '$teacherDesc', '$sTeacherId', '$sActTypeId')";

        if (!mysqli_query($conn, $sql2)) {
            throw new Exception("老師收款失敗：" . mysqli_error($conn));
        }

        mysqli_commit($conn);

        echo json_encode([
            "status"          => "success",
            "message"         => "成功送出 {$giftName}！",
            "gift"            => $gift['name'],
            "giftEmoji"       => $gift['emoji'],
            "cost"            => $cost,
            "studentNewTotal" => $studentNewTotal,
            "teacherNewTotal" => $teacherNewTotal,
            "studentTxId"     => $studentAId,
            "teacherTxId"     => $teacherAId,
        ], JSON_UNESCAPED_UNICODE);

    } catch (Exception $inner) {
        mysqli_rollback($conn);
        throw $inner;
    }

} catch (Exception $e) {
    http_response_code(200);
    echo json_encode([
        "status"  => "error",
        "message" => $e->getMessage(),
    ], JSON_UNESCAPED_UNICODE);
} finally {
    if (isset($conn) && $conn) {
        mysqli_close($conn);
    }
}
?>
