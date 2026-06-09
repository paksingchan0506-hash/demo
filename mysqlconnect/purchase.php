<?php
/**
 * 檔案名稱：purchase.php
 * 功能：處理課程或課時購買，並手動生成字串 ID
 */

// 1. 強制設定 Header
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

// 2. 隱藏所有 HTML 報錯，避免污染 JSON
error_reporting(0);
ini_set('display_errors', 0);

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once("common.php");

try {
    $conn = connectDB();
    if (!$conn) throw new Exception("資料庫連線失敗");

    // 3. 獲取 POST 資料
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (!$data || !isset($data['mId']) || !isset($data['cId'])) {
        throw new Exception("缺少必要參數 mId 或 cId");
    }

    $mId = mysqli_real_escape_string($conn, $data['mId']);
    $cId = mysqli_real_escape_string($conn, $data['cId']);
    $lId = isset($data['lId']) ? mysqli_real_escape_string($conn, $data['lId']) : null;

    if ($lId) {
    // --- 處理 MemberLesson (單節課時) ---
    // 獲取目前最大的 mlId
    $res = mysqli_query($conn, "SELECT mlId FROM MemberLesson ORDER BY mlId DESC LIMIT 1");
    $row = mysqli_fetch_assoc($res);
        if ($row) {
            // 解析出數字部分，例如從 'ml00000005' 提取出 5
            $lastNum = (int)substr($row['mlId'], 2);
            $newNum = $lastNum + 1;
        } else {
            $newNum = 1; // 如果表是空的，從 1 開始
        }
        // 格式化回字串：ml + 8位數字(補零) -> ml00000006
        $newMlId = "ml" . str_pad($newNum, 8, "0", STR_PAD_LEFT);

        $sql = "INSERT INTO MemberLesson (mlId, mId, lId) VALUES ('$newMlId', '$mId', '$lId')";

    } else {
        // --- 處理 MemberCourse (整門課) ---
        // 1. 查詢資料庫目前最大的 mcId
        $res = mysqli_query($conn, "SELECT mcId FROM MemberCourse ORDER BY mcId DESC LIMIT 1");
        $row = mysqli_fetch_assoc($res);
        
        if ($row) {
            // 2. 解析：從 'mc00000005' 截取掉前 2 碼 'mc'，剩餘部分轉為整數
            $lastNum = (int)substr($row['mcId'], 2);
            $newNum = $lastNum + 1;
        } else {
            $newNum = 1; // 如果表完全沒資料，從 1 開始
        }
        
        // 3. 補零：將數字格式化為 8 位數，不足前面補 0，前面再加上 'mc'
        // 結果會像：mc00000006
        $newMcId = "mc" . str_pad($newNum, 8, "0", STR_PAD_LEFT);

        $sql = "INSERT INTO MemberCourse (mcId, mId, cId) VALUES ('$newMcId', '$mId', '$cId')";
    }

    if (mysqli_query($conn, $sql)) {
        echo json_encode(["status" => "success", "message" => "購買成功"]);
    } else {
        throw new Exception("資料庫寫入失敗: " . mysqli_error($conn));
    }

} catch (Exception $e) {
    // 即使失敗也回傳 JSON
    http_response_code(200); // 讓 Flutter 能接收到 body
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
?>