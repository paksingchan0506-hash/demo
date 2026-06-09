<?php
/**
 * 檔案名稱：get_home_ranks.php
 * 功能：獲取首頁排行榜數據（熱門課程與熱門導師）
 */

// 1. 設定 Header (解決跨域與 JSON 格式問題)
header("Access-Control-Allow-Origin: *"); 
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

// 處理預檢請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 2. 引入連線設定
require_once("common.php"); 

try {
    $conn = connectDB();
    
    // 初始化回傳結構
    $response = [
        "status" => "success",
        "data" => [
            "courses" => [],
            "teachers" => []
        ]
    ];

    // 3. 獲取熱門課程 Top 5 (依購買人數排序)
    $courseSql = "SELECT cId, cName, purchasedCount ,introImg FROM Course WHERE is_deleted = 0 ORDER BY purchasedCount DESC LIMIT 5";
    $courseRes = mysqli_query($conn, $courseSql);
    while ($row = mysqli_fetch_assoc($courseRes)) {
        $response["data"]["courses"][] = [
            "id" => $row['cId'],
            "name" => $row['cName'],
            "imageUrl" => $row['introImg']
        ];
    }

    // 4. 獲取熱門導師 Top 5 (依收藏次數排序)
    $teacherSql = "SELECT mId, username,avatar, tBookCount FROM Member WHERE mType = 'T' AND is_deleted = 0 ORDER BY tBookCount DESC LIMIT 5";
    $teacherRes = mysqli_query($conn, $teacherSql);
    while ($row = mysqli_fetch_assoc($teacherRes)) {
        $response["data"]["teachers"][] = [
            "id" => $row['mId'],
            "name" => $row['username'],
            "imageUrl" => $row['avatar'] // 測試用頭像
        ];
    }

    echo json_encode($response, JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>