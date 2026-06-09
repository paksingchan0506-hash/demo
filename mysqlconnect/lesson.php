<?php
/**
 * 檔案名稱：lesson.php
 * 功能：獲取特定課程 (cId) 的所有課時清單，並判斷該使用者 (mId) 是否已購買（鎖定狀態）
 */

ob_start();

// 1. 設定 Header (解決跨域與 JSON 格式問題)
header("Access-Control-Allow-Origin: *"); 
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Origin, Accept");
header("Content-Type: application/json; charset=UTF-8");

// 處理預檢請求 (Preflight request)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once("common.php"); 

try {
    $conn = connectDB();
    if (!$conn) {
        throw new Exception("資料庫連線失敗");
    }

    // 檢查必要的 cId 參數
    if (isset($_GET['cId'])) {
        $cId = mysqli_real_escape_string($conn, $_GET['cId']);
        // mId 可能為空（訪客狀態），則全部鎖定
        $mId = isset($_GET['mId']) ? mysqli_real_escape_string($conn, $_GET['mId']) : '';

        /**
         * SQL 邏輯說明：
         * 1. 從 Lesson 表選取該課程的所有課時。
         * 2. LEFT JOIN MemberCourse (MC)：檢查學生是否買了「整門課程」。
         * 3. LEFT JOIN MemberLesson (ML)：檢查學生是否單獨買了「該節課時」。
         * 4. 判斷 isLocked：
         * - 若 MC.mId 有值 (代表買了整門課) -> 解鎖 (0)
         * - 若 ML.mId 有值 (代表單買這節課) -> 解鎖 (0)
         * - 否則 -> 鎖定 (1)
         */
        $sql = "SELECT 
                    L.lId, L.lName, L.price, L.cId, L.video,
                    CASE 
                        WHEN MC.mId IS NOT NULL THEN 0 
                        WHEN ML.mId IS NOT NULL THEN 0 
                        ELSE 1 
                    END as isLocked
                FROM Lesson L
                LEFT JOIN MemberCourse MC ON L.cId = MC.cId AND MC.mId = '$mId'
                LEFT JOIN MemberLesson ML ON L.lId = ML.lId AND ML.mId = '$mId'
                WHERE L.cId = '$cId' AND L.is_deleted = 0 
                ORDER BY L.orderNum ASC";

        $result = mysqli_query($conn, $sql);

        if (!$result) {
            throw new Exception("SQL 查詢失敗: " . mysqli_error($conn));
        }

        $lessons = [];
        while ($row = mysqli_fetch_assoc($result)) {
            $isLocked = ((int)$row['isLocked'] == 1);
            
            $lessons[] = [
                "lId"      => $row['lId'],
                "title"    => $row['lName'], 
                "price"    => (float)$row['price'],
                "cId"      => $row['cId'],
                // 安全優化：如果處於鎖定狀態，不回傳影片 URL，防止被直接讀取網址
                "video"    => $isLocked ? "" : ($row['video'] ?? ""), 
                "isLocked" => $isLocked
            ];
        }

        // 清除任何緩衝區內容，確保只輸出 JSON
        ob_clean();
        echo json_encode($lessons, JSON_UNESCAPED_UNICODE);
        
    } else {
        throw new Exception("缺少 cId 參數");
    }

} catch (Exception $e) {
    ob_clean();
    http_response_code(500);
    echo json_encode([
        "error" => true,
        "message" => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
?>