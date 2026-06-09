<?php
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

    if ($method == 'GET') {
        if (isset($_GET['cId'])) {
            $cId = mysqli_real_escape_string($conn, $_GET['cId']);
            
            // --- 重點修改：實時計算評分 ---
            // 邏輯：從 Course 出發，找對應的所有 Lesson，再找這些 Lesson 在 MemberLesson 裡的 rating
            $sql = "SELECT 
                        C.*, 
                        M.username as mentorName, 
                        M.avatar as mentorAvatar,
                        (SELECT IFNULL(AVG(ML.rating), 0) 
                         FROM MemberLesson ML 
                         INNER JOIN Lesson L ON ML.lId = L.lId 
                         WHERE L.cId = C.cId AND ML.rating > 0) as realTimeRating
                    FROM Course C 
                    LEFT JOIN Member M ON C.mId = M.mId 
                    WHERE C.cId = '$cId' AND C.is_deleted = 0 LIMIT 1";
            
            $result = mysqli_query($conn, $sql);
            $row = mysqli_fetch_assoc($result);

            if ($row) {
                // 將計算出來的評分四捨五入到小數點第一位
                $finalRating = round((float)$row['realTimeRating'], 1);

                $courseDetail = [
                    "cId"            => $row['cId'],
                    "mId"            => $row['mId'],
                    "cName"          => $row['cName'],
                    "unitPrice"      => (float)$row['unitPrice'],
                    "summary"        => $row['summary'] ?? "",
                    "mentorName"     => $row['mentorName'] ?? "未知導師",
                    "mentorAvatar"   => $row['mentorAvatar'] ?? "",
                    "introImg"       => $row['introImg'] ?? "",
                    "rating"         => $finalRating, // 這裡傳回計算後的平均分
                    "purchasedCount" => (int)$row['purchasedCount'], 
                    "bookmarkCount"  => (int)$row['bookmarkCount']
                ];
                echo json_encode($courseDetail, JSON_UNESCAPED_UNICODE);
            } else {
                http_response_code(404);
                echo json_encode(["error" => "找不到課程"]);
            }
        } else {
            // 列表頁同樣套用實時評分邏輯（選填，若列表也要顯示準確評分）
            $sql = "SELECT C.*, M.username as mentorName,
                    (SELECT IFNULL(AVG(ML.rating), 0) FROM MemberLesson ML 
                     INNER JOIN Lesson L ON ML.lId = L.lId 
                     WHERE L.cId = C.cId AND ML.rating > 0) as realTimeRating
                    FROM Course C 
                    LEFT JOIN Member M ON C.mId = M.mId 
                    WHERE C.is_deleted = 0"; 
            
            $result = mysqli_query($conn, $sql);
            $courses = [];
            while ($row = mysqli_fetch_assoc($result)) {
                $courses[] = [
                    "cId"        => $row['cId'],
                    "cName"      => $row['cName'],
                    "mentorName" => $row['mentorName'] ?? "未知導師",
                    "unitPrice"  => (float)$row['unitPrice'],
                    "introImg"   => $row['introImg'] ?? "",
                    "rating"     => round((float)$row['realTimeRating'], 1)
                ];
            }
            echo json_encode($courses, JSON_UNESCAPED_UNICODE);
        }
    } 
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["error" => true, "message" => $e->getMessage()]);
} finally {
    if (isset($conn)) { mysqli_close($conn); }
}
?>