<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// 引入你的通用工具檔 (內含 connectDB, genID 等)
include 'common.php';

try {
    $conn = connectDB();
} catch (Exception $e) {
    die(json_encode(array("status" => "error", "message" => "資料庫連線失敗: " . $e->getMessage())));
}

$method = $_SERVER['REQUEST_METHOD'];
if ($method == 'OPTIONS') { exit; }

// 獲取輸入資料
$input = json_decode(file_get_contents("php://input"), true);
$action = $input['action'] ?? $_GET['action'] ?? '';
$mId = $input['mId'] ?? $_GET['mId'] ?? '';

if (empty($mId)) {
    http_response_code(400);
    echo json_encode(array("status" => "error", "message" => "缺少 mId"));
    mysqli_close($conn);
    exit;
}

$mId = mysqli_real_escape_string($conn, $mId);

// --- 核心邏輯 0：用戶身份識別與轉向 (老師查看學生紀錄) ---
$check_type_sql = "SELECT mType FROM Member WHERE mId = '$mId'";
$type_res = mysqli_query($conn, $check_type_sql);
$user_type_data = mysqli_fetch_assoc($type_res);

if ($user_type_data && $user_type_data['mType'] == 'T') {
    $relation_sql = "SELECT studentId FROM MemberRelation WHERE teacherId = '$mId' LIMIT 1";
    $relation_res = mysqli_query($conn, $relation_sql);
    if ($relation_data = mysqli_fetch_assoc($relation_res)) {
        $mId = $relation_data['studentId'];
    }
}

switch ($action) {
    // 1. 獲取紀錄
    case 'get_history':
        $sql = "SELECT t.*, type.description as typeName 
                FROM ACoinTransaction t
                LEFT JOIN ACoinTransType type ON t.actTypeId = type.actTypeId
                WHERE t.mId = '$mId' 
                ORDER BY t.transDate DESC, t.aId DESC";
        
        $result = mysqli_query($conn, $sql);
        $history = [];

        if ($result) {
            while ($row = mysqli_fetch_assoc($result)) {
                $history[] = [
                    "aId" => $row['aId'],
                    "title" => $row['typeName'] ?? $row['description'],
                    "amount" => (int)$row['transValue'],
                    "total" => (int)$row['totalAmont'],
                    "date" => $row['transDate']
                ];
            }
            echo json_encode(array("status" => "success", "data" => $history));
        } else {
            echo json_encode(array("status" => "error", "message" => mysqli_error($conn)));
        }
        break;

    // 2. 執行交易 (簽到或課金儲值)
    case 'add_transaction':
        $actTypeId = mysqli_real_escape_string($conn, $input['actTypeId']);
        $customDesc = isset($input['description']) ? mysqli_real_escape_string($conn, $input['description']) : '';
        
        // 獲取基本資訊
        $type_sql = "SELECT defaultValue, description FROM ACoinTransType WHERE actTypeId = '$actTypeId'";
        $type_res = mysqli_query($conn, $type_sql);
        $type_data = mysqli_fetch_assoc($type_res);

        if (!$type_data) {
            echo json_encode(array("status" => "error", "message" => "無效的交易類型"));
            break;
        }

        $typeName = $type_data['description'];
        $streak_msg = "";

        // --- 核心邏輯 A：確定本次交易的積分數額 ---
        // 如果前端有傳 points (例如課金)，優先使用傳入值；否則使用資料庫預設值 (簽到)
        if (isset($input['points']) && is_numeric($input['points'])) {
            $final_reward = (int)$input['points'];
        } else {
            $final_reward = (int)$type_data['defaultValue'];
        }

        // --- 核心邏輯 B：連續簽到判定 (僅針對 att014) ---
        if ($actTypeId == 'att014') {
            $today = date('Y-m-d');
            $yesterday = date('Y-m-d', strtotime('-1 day'));

            // 檢查今天是否已簽到
            $check_today = mysqli_query($conn, "SELECT aId FROM ACoinTransaction WHERE mId='$mId' AND actTypeId='att014' AND DATE(transDate)='$today'");
            if (mysqli_num_rows($check_today) > 0) {
                echo json_encode(array("status" => "error", "message" => "今日已領取過，請明天再來"));
                break;
            }

            // 檢查昨天是否有簽到 (做法 A)
            $check_yesterday = mysqli_query($conn, "SELECT aId FROM ACoinTransaction WHERE mId='$mId' AND actTypeId='att014' AND DATE(transDate)='$yesterday'");
            
            if (mysqli_num_rows($check_yesterday) > 0) {
                $bonus = 5; // 連續簽到獎勵
                $final_reward += $bonus;
                $streak_msg = " (含連續簽到獎勵 +$bonus)";
            } else {
                $streak_msg = " (連續簽到已中斷，重新計算)";
            }
        }

        // --- 核心邏輯 C：計算餘額 ---
        $balance_sql = "SELECT totalAmont FROM ACoinTransaction WHERE mId='$mId' ORDER BY transDate DESC, aId DESC LIMIT 1";
        $balance_res = mysqli_query($conn, $balance_sql);
        $current_total = (mysqli_num_rows($balance_res) > 0) ? mysqli_fetch_assoc($balance_res)['totalAmont'] : 0;
        $new_total = $current_total + $final_reward;

        // --- 核心邏輯 D：寫入資料庫 ---
        $newAId = genID($conn, "A", 10, "aId", "ACoinTransaction");
        $final_desc = (empty($customDesc) ? $typeName : $customDesc) . $streak_msg;

        $insert_sql = "INSERT INTO ACoinTransaction (aId, transValue, totalAmont, transDate, description, mId, actTypeId) 
                       VALUES ('$newAId', $final_reward, $new_total, NOW(), '$final_desc', '$mId', '$actTypeId')";
        
        if (mysqli_query($conn, $insert_sql)) {
            echo json_encode(array(
                "status" => "success", 
                "newTotal" => $new_total, 
                "reward" => $final_reward,
                "message" => "操作成功" . $streak_msg
            ));
        } else {
            http_response_code(500);
            echo json_encode(array("status" => "error", "message" => "資料寫入失敗"));
        }
        break;

    default:
        echo json_encode(array("status" => "error", "message" => "不明的 action: $action"));
        break;
}

mysqli_close($conn);
?>