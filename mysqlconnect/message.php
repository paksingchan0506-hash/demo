<?php
// 1. CORS 處理 (解決 XMLHttpRequest error)
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 2. 引入 common.php (不改動它)
require_once "common.php";

$conn = connectDB(); 
$method = $_SERVER['REQUEST_METHOD'];

if ($method == 'GET' && isset($_GET['mId'])) {
    $mId = mysqli_real_escape_string($conn, $_GET['mId']);

    // 根據你提供的 Table 結構修改 SQL
    // 欄位名分別為: title, content, sendDate, isRead, messageId
    $sql = "SELECT 
                title, 
                content, 
                sendDate as created_at, 
                isRead,
                messageId
            FROM Message 
            WHERE (recipientId = '$mId' OR recipientId IS NULL OR recipientId = '') 
            AND is_deleted = 0 
            ORDER BY sendDate DESC";

    $result = mysqli_query($conn, $sql);
    $messages = [];
    $unreadCount = 0;

    if ($result) {
        while ($row = mysqli_fetch_assoc($result)) {
            // 計算未讀數
            if ($row['isRead'] == 0) {
                $unreadCount++;
            }
            $messages[] = $row;
        }
        
        // 回傳 JSON
        echo json_encode([
            "status" => "success",
            "unreadCount" => (int)$unreadCount,
            "messages" => $messages // 對接 Flutter 的 _notifications = res['messages']
        ]);
    } else {
        // 如果 SQL 執行失敗，回傳錯誤訊息以便排錯
        echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Missing mId"]);
}

if(isset($conn)) mysqli_close($conn);
?>