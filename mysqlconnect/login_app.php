<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, GET, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include 'common.php';

// 1. 建立資料庫連線
try {
    $conn = connectDB();
} catch (Exception $e) {
    die(json_encode(array("message" => "Database connection error: " . $e->getMessage())));
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method == 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    // 登入邏輯 (檢查 email 和 password)
    if (isset($data['email']) && isset($data['password']) && !isset($data['fName'])) {
        $email = mysqli_real_escape_string($conn, $data['email']);
        $password = mysqli_real_escape_string($conn, $data['password']);

        $sql = "SELECT * FROM Member WHERE email = '$email' AND password = '$password' AND is_deleted = 0";
        $result = mysqli_query($conn, $sql);

        if (mysqli_num_rows($result) > 0) {
            $row = mysqli_fetch_assoc($result);
            $mId = $row['mId'];
            $mType = $row['mType'];

            // 檢查是否有另一種身份的關聯
            $hasRelation = false;
            if ($mType == 'S') {
                $rel_sql = "SELECT teacherId FROM MemberRelation WHERE studentId = '$mId' AND teacherId IS NOT NULL";
            } else {
                $rel_sql = "SELECT studentId FROM MemberRelation WHERE teacherId = '$mId' AND studentId IS NOT NULL";
            }
            $rel_res = mysqli_query($conn, $rel_sql);
            if (mysqli_num_rows($rel_res) > 0) {
                $hasRelation = true;
            }
            
            $row['hasRelation'] = $hasRelation;
            echo json_encode($row);
        } else {
            http_response_code(401);
            echo json_encode(array("message" => "Login failed. Invalid credentials."));
        }
    }
    // 註冊邏輯
    else if (isset($data['fName'])) {
        $email = mysqli_real_escape_string($conn, $data['email']);

        // 1. 檢查 Email 是否已存在
        $check_sql = "SELECT * FROM Member WHERE email = '$email'";
        $check_result = mysqli_query($conn, $check_sql);

        if (mysqli_num_rows($check_result) > 0) {
            http_response_code(409); // Conflict
            echo json_encode(array("message" => "Email already exists"));
        } else {
            // 2. 準備註冊資料
            $password = mysqli_real_escape_string($conn, $data['password']);
            $fName = mysqli_real_escape_string($conn, $data['fName']); // 這裡是 name
            $mtype = mysqli_real_escape_string($conn, $data['mtype']); // 'S' or 'T'
            // 預設語言改為繁體中文 (Lg000002)
            $langId = 'Lg000002'; 
            $tel = isset($data['tel']) ? (int)$data['tel'] : 'NULL';

            // 3. 產生新的 mId
            $new_id = genID($conn, "M", 8, "mId", "Member");

            // 開始交易
            mysqli_begin_transaction($conn);

            try {
                // 4. 插入新用戶 (移除不存在的 address 欄位)
                $insert_sql = "INSERT INTO Member (mId, username, mType, password, email, tel, regDate, loginMethod, is_deleted, langId) 
                               VALUES ('$new_id', '$fName', '$mtype', '$password', '$email', $tel, NOW(), 'SYSTEM', 0, '$langId')";

                if (!mysqli_query($conn, $insert_sql)) {
                    throw new Exception("Member insertion failed: " . mysqli_error($conn));
                }

                // 5. 註冊成功，給予註冊獎勵 (att005: 1000 ACoin)
                $trans_id = genID($conn, "A", 10, "aId", "ACoinTransaction");
                $reward_sql = "INSERT INTO ACoinTransaction (aId, mId, actTypeId, transValue, totalAmont, transDate, description) 
                               VALUES ('$trans_id', '$new_id', 'att005', 1000, 1000, NOW(), 'Registration Reward')";
                
                if (!mysqli_query($conn, $reward_sql)) {
                    throw new Exception("Reward insertion failed: " . mysqli_error($conn));
                }

                // 提交交易
                mysqli_commit($conn);
                http_response_code(201); // Created
                echo json_encode(array("message" => "User registered successfully", "mId" => $new_id));
            } catch (Exception $e) {
                // 回滾交易
                mysqli_rollback($conn);
                http_response_code(500);
                echo json_encode(array("message" => "Registration failed: " . $e->getMessage()));
            }
        }
    }
}
// 關閉連線
mysqli_close($conn);
