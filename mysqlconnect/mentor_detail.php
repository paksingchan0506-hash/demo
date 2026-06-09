<?php
/**
 * 檔案名稱：mentor_detail.php (完整修正版)
 */

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Origin, Accept");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once("common.php");

try {
    $conn = connectDB();
    
    if (!isset($_GET['mId'])) {
        echo json_encode(["error" => "缺少導師 ID"]);
        exit;
    }

    $mId = mysqli_real_escape_string($conn, $_GET['mId']);

    // 1. 查詢導師個人資訊 (包含頭像與等級)
    $sql_mentor = "SELECT username, avatar, teacherLevel, selfIntro 
                   FROM Member 
                   WHERE mId = '$mId' AND is_deleted = 0 LIMIT 1";
    $res_mentor = mysqli_query($conn, $sql_mentor);
    $mentor_info = mysqli_fetch_assoc($res_mentor);

    if (!$mentor_info) {
        http_response_code(404);
        echo json_encode(["error" => "找不到該成員資料"]);
        exit;
    }

    // 2. 查詢該導師名下的所有課程，並實時計算每門課的平均分
    $sql_courses = "SELECT 
                        C.cId, 
                        C.cName, 
                        C.unitPrice, 
                        C.introImg,
                        (SELECT IFNULL(AVG(ML.rating), 0) 
                         FROM MemberLesson ML 
                         INNER JOIN Lesson L ON ML.lId = L.lId 
                         WHERE L.cId = C.cId AND ML.rating > 0) as avgRating
                    FROM Course C 
                    WHERE C.mId = '$mId' AND C.is_deleted = 0";
    
    $res_courses = mysqli_query($conn, $sql_courses);
    
    $courses = [];
    $total_rating_sum = 0;
    $course_count = 0;

    while ($row = mysqli_fetch_assoc($res_courses)) {
        $current_avg = round((float)$row['avgRating'], 1);
        $courses[] = [
            "cId"       => $row['cId'],
            "cName"     => $row['cName'],
            "unitPrice" => (float)$row['unitPrice'],
            "introImg"  => $row['introImg'] ?? "",
            "rating"    => $current_avg
        ];
        
        if ($current_avg > 0) {
            $total_rating_sum += $current_avg;
            $course_count++;
        }
    }

    // 計算該導師整體的平均評分
    $overall_rating = ($course_count > 0) ? round($total_rating_sum / $course_count, 1) : 0;

    // 3. 輸出最終 JSON (移除所有死數)
echo json_encode([
    "mentorName"    => $mentor_info['username'],
    "mentorAvatar"  => $mentor_info['avatar'] ?? "", // 這個值會傳給 Flutter 的 url 參數
    "teacherLevel"  => (int)$mentor_info['teacherLevel'],
    "averageRating" => $overall_rating,
    "courseCount"   => count($courses),
    "courses"       => $courses
], JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["error" => $e->getMessage()]);
}
?>