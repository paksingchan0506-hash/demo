<?php
// update_bookmark.php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
require_once("common.php");

try {
    $conn = connectDB();
    $cId = mysqli_real_escape_string($conn, $_GET['cId']);
    $action = $_GET['action']; // 'add' 或 'remove'

    if ($action === 'add') {
        // 收藏人數 +1
        $sql = "UPDATE Course SET bookmarkCount = bookmarkCount + 1 WHERE cId = '$cId'";
    } else {
        // 收藏人數 -1 (確保不小於 0)
        $sql = "UPDATE Course SET bookmarkCount = GREATEST(0, bookmarkCount - 1) WHERE cId = '$cId'";
    }

    if (mysqli_query($conn, $sql)) {
        echo json_encode(["success" => true, "message" => "更新成功"]);
    } else {
        echo json_encode(["success" => false, "message" => mysqli_error($conn)]);
    }
} catch (Exception $e) {
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>