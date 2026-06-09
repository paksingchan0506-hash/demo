<?php
/**
 * 檔案名稱：search_popular.php
 * 功能：熱門搜尋 - GET 獲取熱門課程列表 / POST 記錄課程被搜尋次數
 * 資料表：CourseSearch (cId, searchCount)
 */

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once("common.php");

try {
    $conn = connectDB();
    $method = $_SERVER['REQUEST_METHOD'];

    // ── GET：獲取熱門搜尋（按 searchCount 排序，取前10筆課程名稱）──
    if ($method == 'GET') {
        $sql = "SELECT cs.cId, c.cName, cs.searchCount 
                FROM CourseSearch cs
                LEFT JOIN Course c ON cs.cId = c.cId
                WHERE c.is_deleted = 0
                ORDER BY cs.searchCount DESC
                LIMIT 10";

        $result = mysqli_query($conn, $sql);

        $popular = [];
        while ($row = mysqli_fetch_assoc($result)) {
            $popular[] = [
                "keyword"      => $row['cName'],
                "search_count" => (int)$row['searchCount']
            ];
        }

        // 若尚無搜尋記錄，回傳預設熱門關鍵字
        if (empty($popular)) {
            $defaults = [
                'AI 人工智能', 'ChatGPT 應用', '數據科學',
                '手機App開發', '深度學習', '區塊鏈技術',
                '雲端計算', '大數據分析', '物聯網 IoT', '網絡安全'
            ];
            foreach ($defaults as $kw) {
                $popular[] = ["keyword" => $kw, "search_count" => 0];
            }
        }

        echo json_encode($popular, JSON_UNESCAPED_UNICODE);

    // ── POST：記錄課程被搜尋（+1）──
    // 請求格式: {"cId": "C0000001"}
    } else if ($method == 'POST') {
        $data = json_decode(file_get_contents("php://input"), true);
        $cId = isset($data['cId']) ? trim($data['cId']) : '';

        if (empty($cId)) {
            http_response_code(400);
            echo json_encode(["error" => "cId 不可為空"]);
            exit();
        }

        $cId = mysqli_real_escape_string($conn, $cId);

        // 已存在則 +1，否則新增
        $sql = "INSERT INTO CourseSearch (cId, searchCount)
                VALUES ('$cId', 1)
                ON DUPLICATE KEY UPDATE searchCount = searchCount + 1";

        if (mysqli_query($conn, $sql)) {
            echo json_encode(["success" => true, "cId" => $cId], JSON_UNESCAPED_UNICODE);
        } else {
            http_response_code(500);
            echo json_encode(["error" => mysqli_error($conn)]);
        }
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["error" => $e->getMessage()], JSON_UNESCAPED_UNICODE);
} finally {
    if (isset($conn)) mysqli_close($conn);
}
?>
