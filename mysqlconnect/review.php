<?php
/**
 * 檔案名稱：review.php (修正版)
 */

error_reporting(0);
ini_set('display_errors', 0);

header("Access-Control-Allow-Origin: *"); 
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Origin, Accept");
header("Content-Type: application/json; charset=UTF-8");

require_once("common.php");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $conn = connectDB();
    $method = $_SERVER['REQUEST_METHOD'];

    // --- 功能 A：獲取評論與個人評分 (GET) ---
    if ($method == 'GET') {
        if (isset($_GET['cId'])) {
            $cId = mysqli_real_escape_string($conn, $_GET['cId']);
            $mId = isset($_GET['mId']) ? mysqli_real_escape_string($conn, $_GET['mId']) : "";
            
            // 獲取所有評論
            $sql = "SELECT TR.trId, TR.comment, TR.createDate, M.username, M.avatar 
                    FROM TutorReview TR
                    INNER JOIN Member M ON TR.mId = M.mId
                    WHERE TR.cId = '$cId'
                    ORDER BY TR.createDate DESC";
            
            $result = mysqli_query($conn, $sql);
            $reviews = [];
                while ($row = mysqli_fetch_assoc($result)) {
                    // 如果資料庫是 null，給予空字串
                    $row['avatar'] = $row['avatar'] ?? ""; 
                    $reviews[] = $row;
                }

            // --- 修正：從 MemberLesson 獲取該用戶對該課程的評分 ---
            $userRating = 0;
            if (!empty($mId)) {
                $rateSql = "SELECT ml.rating 
                            FROM MemberLesson ml 
                            JOIN Lesson l ON ml.lId = l.lId 
                            WHERE l.cId = '$cId' AND ml.mId = '$mId' 
                            AND ml.rating > 0 LIMIT 1";
                $rateRes = mysqli_query($conn, $rateSql);
                if ($rRow = mysqli_fetch_assoc($rateRes)) {
                    $userRating = (int)$rRow['rating'];
                }
            }

            echo json_encode([
                "reviews" => $reviews,
                "userRating" => $userRating
            ], JSON_UNESCAPED_UNICODE);
        }
        exit();
    }

    // --- 功能 B：提交 (POST) ---
    else if ($method == 'POST') {
        $input = json_decode(file_get_contents("php://input"), true);
        $action = $input['action'] ?? ''; 
        $mId = mysqli_real_escape_string($conn, $input['mId']);
        $cId = mysqli_real_escape_string($conn, $input['cId']);

        if ($action == 'rating') {
            $rating = intval($input['rating']);
            
            // 更新該用戶購買的所有該課程章節評分
            $sql = "UPDATE MemberLesson ml 
                    INNER JOIN Lesson l ON ml.lId = l.lId 
                    SET ml.rating = $rating 
                    WHERE ml.mId = '$mId' AND l.cId = '$cId'";
            
            if(mysqli_query($conn, $sql)) {
                // 重新計算 Course 表中的 avgRating (加入 COALESCE 防止 NULL)
                $updateAvg = "UPDATE Course SET avgRating = (
                                SELECT COALESCE(AVG(rating), 0) 
                                FROM MemberLesson ml 
                                JOIN Lesson l ON ml.lId = l.lId 
                                WHERE l.cId = '$cId' AND rating > 0
                              ) WHERE cId = '$cId'";
                mysqli_query($conn, $updateAvg);
                
                echo json_encode(["status" => "success", "message" => "評分已更新"]);
            } else {
                throw new Exception("更新評分失敗");
            }
        } 
        else if ($action == 'comment') {
            $comment = mysqli_real_escape_string($conn, $input['comment']);
            if (empty($comment)) {
                echo json_encode(["status" => "error", "message" => "內容不能為空"]);
                exit();
            }

            $trId = genID($conn, "TR", 8, "trId", "TutorReview");
            $sql = "INSERT INTO TutorReview (trId, mId, cId, comment, createDate) 
                    VALUES ('$trId', '$mId', '$cId', '$comment', NOW())";
            
            if(mysqli_query($conn, $sql)) {
                echo json_encode(["status" => "success", "message" => "評論成功"]);
            } else {
                throw new Exception("評論失敗");
            }
        }
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>