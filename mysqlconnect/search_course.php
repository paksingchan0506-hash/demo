<?php
/**
 * 檔案名稱：search_course.php
 * 功能：課程搜尋 - 支援關鍵字搜尋課程名稱、描述、講師名稱
 * 用法：GET /mysqlconnect/search_course.php?search=關鍵字
 */

ob_start();

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once("common.php");

try {
    $conn = connectDB();

    if ($_SERVER['REQUEST_METHOD'] != 'GET') {
        http_response_code(405);
        echo json_encode(["error" => "只支援 GET 請求"]);
        exit();
    }

    $keyword = isset($_GET['search']) ? trim($_GET['search']) : '';

    if (empty($keyword)) {
        http_response_code(400);
        echo json_encode(["error" => "請提供 search 參數"]);
        exit();
    }

    $safe = mysqli_real_escape_string($conn, $keyword);
    $like = "%$safe%";

    // 搜尋課程名稱、描述(summary)、講師 username
    // JOIN Member 以取得講師名稱
    $sql = "SELECT 
                c.cId,
                c.cName,
                c.unitPrice,
                c.summary,
                c.totalLesson,
                c.mId,
                m.username AS instructor
            FROM Course c
            LEFT JOIN Member m ON c.mId = m.mId
            WHERE c.is_deleted = 0
              AND (
                  c.cName    LIKE '$like'
               OR c.summary  LIKE '$like'
               OR m.username LIKE '$like'
              )
            ORDER BY c.cId DESC
            LIMIT 30";

    $result = mysqli_query($conn, $sql);

    if (!$result) {
        throw new Exception("SQL 錯誤: " . mysqli_error($conn));
    }

    $courses = [];
    while ($row = mysqli_fetch_assoc($result)) {
        $courses[] = [
            "cId"         => $row['cId'],
            "cName"       => $row['cName'],
            "unitPrice"   => (float)$row['unitPrice'],
            "summary"     => $row['summary'],
            "totalLesson" => (int)$row['totalLesson'],
            "mId"         => $row['mId'],
            "instructor"  => $row['instructor'] ?? '',
            "imageUrl"    => "https://via.placeholder.com/150",
            "rating"      => 0.0,
            "purchased"   => 0
        ];
    }

    ob_clean();
    echo json_encode($courses, JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    ob_clean();
    http_response_code(500);
    echo json_encode(["error" => $e->getMessage()], JSON_UNESCAPED_UNICODE);
} finally {
    if (isset($conn)) mysqli_close($conn);
}
?>
