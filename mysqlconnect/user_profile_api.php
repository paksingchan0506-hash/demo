<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

include_once 'common.php'; 

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit;
}

$conn = connectDB();

// --- 統一讀取資料 ---
// 合併 JSON (php://input) 與 傳統表單 ($_POST)
$json_data = json_decode(file_get_contents("php://input"), true) ?? [];
$all_data = array_merge($json_data, $_POST);

$action = $all_data['action'] ?? ($_GET['action'] ?? '');
$mId = $all_data['mId'] ?? ($_GET['mId'] ?? '');

if (empty($mId)) {
    echo json_encode(["status" => "error", "message" => "Missing User ID"]);
    exit;
}

switch ($action) {
        case 'getUser':
            $sql = "SELECT mId, username, email, tel, gender, selfIntro, avatar,
                    avgRating, tBookCount, teacherLevel FROM Member WHERE mId = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("s", $mId);
            $stmt->execute();
            $result = $stmt->get_result();
            if ($user = $result->fetch_assoc()) {
                echo json_encode(["status" => "success", "data" => $user]);
            } else {
                echo json_encode(["status" => "error", "message" => "User not found"]);
            }
            $stmt->close();
            break;

    case 'update_info':
        $main_updates = [];
        $params = [];
        $types = '';

        $sync_updates = []; 
        $sync_params = [];
        $sync_types = '';

        // 1. 處理所有文字欄位 (包含 Email 與 SelfIntro)
        // 這些鍵值必須與 Flutter 中 request.fields['xxx'] 的名稱完全一致
        $fields = [
            'username'  => 'username',
            'email'     => 'email',      // 確保 Flutter 有傳 email
            'tel'       => 'tel',
            'gender'    => 'gender',
            'selfIntro' => 'selfIntro',  // 確保 Flutter 有傳 selfIntro
            'address'   => 'address'
        ];

        // 需要同步到關聯帳號的欄位
        $sync_list = ['email', 'tel', 'gender'];

        foreach ($fields as $key => $column) {
            if (isset($all_data[$key])) {
                $value = $all_data[$key];
                
                // 加到主更新列表
                $main_updates[] = "$column = ?";
                $params[] = $value;
                $types .= 's';

                // 如果在同步清單內，加到同步列表
                if (in_array($key, $sync_list)) {
                    $sync_updates[] = "$column = ?";
                    $sync_params[] = $value;
                    $sync_types .= 's';
                }
            }
        }

        // 2. 處理頭像上傳 (使用 $_FILES)
if (isset($_FILES['avatar']) && $_FILES['avatar']['error'] === UPLOAD_ERR_OK) {
    $targetDir = "uploads/";
    if (!is_dir($targetDir)) mkdir($targetDir, 0777, true);
    
    $fileName = time() . "_" . basename($_FILES['avatar']['name']);
    $dest_path = $targetDir . $fileName; // 例如: "uploads/1740000000_me.jpg"

    if (move_uploaded_file($_FILES['avatar']['tmp_name'], $dest_path)) {
        // 【重新編寫】：直接存入相對路徑，不要加 http://...
        $main_updates[] = "avatar = ?";
        $params[] = $dest_path; 
        $types .= 's';
    }
}

        // 3. 處理刪除頭像
        if (isset($all_data['delete_avatar']) && $all_data['delete_avatar'] == '1') {
            $main_updates[] = "avatar = NULL";
        }

        if (empty($main_updates)) {
            echo json_encode(["status" => "error", "message" => "No data to update."]);
            exit;
        }

        // 執行主帳號更新
        $sql = "UPDATE Member SET " . implode(', ', $main_updates) . " WHERE mId = ?";
        $params[] = $mId;
        $types .= 's';
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $success = $stmt->execute();
        $stmt->close();

        if ($success) {
            // 4. 同步更新關聯帳號 (如：老師與學生身分共用 email/tel)
            if (!empty($sync_updates)) {
                $rel_sql = "SELECT studentId, teacherId FROM MemberRelation WHERE studentId = ? OR teacherId = ?";
                $rel_stmt = $conn->prepare($rel_sql);
                $rel_stmt->bind_param("ss", $mId, $mId);
                $rel_stmt->execute();
                $rel_res = $rel_stmt->get_result();

                if ($relation = $rel_res->fetch_assoc()) {
                    $related_mId = ($relation['studentId'] == $mId) ? $relation['teacherId'] : $relation['studentId'];
                    if ($related_mId) {
                        $sync_sql = "UPDATE Member SET " . implode(', ', $sync_updates) . " WHERE mId = ?";
                        $sync_params[] = $related_mId;
                        $sync_types .= 's';
                        $s_stmt = $conn->prepare($sync_sql);
                        $s_stmt->bind_param($sync_types, ...$sync_params);
                        $s_stmt->execute();
                        $s_stmt->close();
                    }
                }
                $rel_stmt->close();
            }
            echo json_encode(["status" => "success", "message" => "Profile updated successfully."]);
        } else {
            echo json_encode(["status" => "error", "message" => "Database execution failed."]);
        }
        break;

    // --- 修改密碼 ---
case 'change_password':
        // 確保使用 $all_data 而不是 $data
        $oldPwd = $all_data['oldPassword'] ?? '';
        $newPwd = $all_data['newPassword'] ?? ''; // 這裡原本你寫 $data，會導致錯誤
        
        if (empty($oldPwd) || empty($newPwd)) {
            echo json_encode(["status" => "error", "message" => "Missing password data"]);
            exit;
        }

        $sql = "SELECT password FROM Member WHERE mId = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $mId);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();

        if ($user && (password_verify($oldPwd, $user['password']) || $oldPwd === $user['password'])) {
            $updateSql = "UPDATE Member SET password = ? WHERE mId = ?";
            $updateStmt = $conn->prepare($updateSql);
            $updateStmt->bind_param("ss", $newPwd, $mId);
            
            if ($updateStmt->execute()) {
                echo json_encode(["status" => "success", "message" => "Password updated"]);
            } else {
                echo json_encode(["status" => "error", "message" => "Update failed"]);
            }
            $updateStmt->close();
        } else {
            echo json_encode(["status" => "error", "message" => "Old password incorrect"]);
        }
        $stmt->close();
        break; // 確保有 break;

    default:
        echo json_encode(["status" => "error", "message" => "Invalid action: " . $action]);
        break;
} //
?>