<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include 'common.php';

try {
    $conn = connectDB();
} catch (Exception $e) {
    die(json_encode(array("message" => "Database connection error: " . $e->getMessage())));
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method == 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($method == 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    if (isset($data['currentMid'])) {
        $currentMid = mysqli_real_escape_string($conn, $data['currentMid']);
        $member_sql = "SELECT mType FROM Member WHERE mId = '$currentMid' AND is_deleted = 0";
        $member_result = mysqli_query($conn, $member_sql);

        if (mysqli_num_rows($member_result) > 0) {
            $member_row = mysqli_fetch_assoc($member_result);
            $currentType = $member_row['mType']; // 'S' 或 'T'
            $relation_sql = "";
            if ($currentType == 'S') {
                $relation_sql = "SELECT teacherId as targetId FROM MemberRelation WHERE studentId = '$currentMid'";
            } else {
                $relation_sql = "SELECT studentId as targetId FROM MemberRelation WHERE teacherId = '$currentMid'";
            }

            $relation_result = mysqli_query($conn, $relation_sql);

            if (mysqli_num_rows($relation_result) > 0) {
                $relation_row = mysqli_fetch_assoc($relation_result);
                $targetId = $relation_row['targetId'];

                // 3. 獲取目標用戶的所有資訊
                $target_sql = "SELECT * FROM Member WHERE mId = '$targetId' AND is_deleted = 0";
                $target_result = mysqli_query($conn, $target_sql);

                if (mysqli_num_rows($target_result) > 0) {
                    $target_row = mysqli_fetch_assoc($target_result);
                    echo json_encode($target_row);
                } else {
                    http_response_code(404);
                    echo json_encode(array("message" => "找不到關聯的帳號資料。"));
                }
            } else {
                http_response_code(404);
                echo json_encode(array("message" => "您尚未開通另一種身分的帳號。"));
            }
        } else {
            http_response_code(404);
            echo json_encode(array("message" => "Current member not found."));
        }
    } else {
        http_response_code(400);
        echo json_encode(array("message" => "Missing currentMid parameter."));
    }
} else {
    http_response_code(405);
    echo json_encode(array("message" => "Method not allowed."));
}

mysqli_close($conn);
?>
