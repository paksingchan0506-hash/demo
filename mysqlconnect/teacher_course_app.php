<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 數據庫連接配置
$servername = "localhost";
$username = "root";
$password = "anony1edu2";
$dbname = "anonymousEduTest";

// 創建連接
$conn = new mysqli($servername, $username, $password, $dbname);

// 檢查連接
if ($conn->connect_error) {
    die(json_encode(array("status" => "error", "message" => "Connection failed: " . $conn->connect_error)));
}

// 設置字符集為 UTF-8
$conn->set_charset("utf8mb4");

// 獲取請求數據
$data = json_decode(file_get_contents('php://input'), true);
$action = isset($data['action']) ? $data['action'] : '';

// 處理不同的操作
switch ($action) {
    case 'get_teacher_courses':
        getTeacherCourses($conn, $data);
        break;
    case 'get_course_lessons':
        getCourseLessons($conn, $data);
        break;
    case 'get_lesson_resources':
        getLessonResources($conn, $data);
        break;
    case 'delete_lesson_video':
        deleteLessonVideo($conn, $data);
        break;
    case 'delete_lesson_files':
        deleteLessonFiles($conn, $data);
        break;
    case 'delete_lesson_resource':
        deleteLessonResource($conn, $data);
        break;
    case 'upload_lesson_resource':
        uploadLessonResource($conn, $data);
        break;
    case 'upload_lesson_resource_url':
        uploadLessonResourceUrl($conn, $data);
        break;
    case 'create_course':
        createCourse($conn, $data);
        break;
    case 'create_lesson':
        createLesson($conn, $data);
        break;
    case 'update_lesson_video':
        updateLessonVideo($conn, $data);
        break;
    case 'update_lesson':
        updateLesson($conn, $data);
        break;
    case 'update_course':
        updateCourse($conn, $data);
        break;
    case 'get_course_students':
        getCourseStudents($conn, $data);
        break;
    case 'get_student_detail':
        getStudentDetail($conn, $data);
        break;
    case 'get_course_student_stats':
        getCourseStudentStats($conn, $data);
        break;
    case 'get_teacher_overall_stats':
        getTeacherOverallStats($conn, $data);
        break;
    case 'get_course_stats':
        getCourseStats($conn, $data);
        break;
    case 'update_course_media':
        updateCourseMedia($conn, $data);
        break;
    case 'delete_lesson':
        deleteLesson($conn, $data);
        break;
    case 'delete_course':
        deleteCourse($conn, $data);
        break;
    case 'restore_lesson':
        restoreLesson($conn, $data);
        break;
    case 'restore_course':
        restoreCourse($conn, $data);
        break;
    case 'get_categories':
        getCategories($conn);
        break;
    case 'submit_heygen_job':
        submitHeygenJob($conn, $data);
        break;
    case 'poll_heygen_job':
        pollHeygenJob($conn, $data);
        break;
    case 'complete_heygen_job':
        completeHeygenJob($conn, $data);
        break;
    default:
        echo json_encode(array("status" => "error", "message" => "Invalid action"));
        break;
}


function getPathReferenceCount($conn, $path) {
    if (empty($path)) return array('total' => 0, 'details' => array());

    $tables = array(
        'Member' => array('cols' => array('selfIntroVideo', 'avatar'), 'hasDeleted' => true),
        'Course' => array('cols' => array('introImg', 'introVideo'), 'hasDeleted' => true),
        'Lesson' => array('cols' => array('video'), 'hasDeleted' => true),
        'LessonResource' => array('cols' => array('path'), 'hasDeleted' => false),
        'Payment' => array('cols' => array('receiptPath'), 'hasDeleted' => true),
        'WithdrawalApproval' => array('cols' => array('invoicePath'), 'hasDeleted' => true),
        'MemberReward' => array('cols' => array('picture'), 'hasDeleted' => false)
    );

    $totalCount = 0;
    $details = array();

    foreach ($tables as $table => $config) {
        foreach ($config['cols'] as $column) {
            $sql = "SELECT COUNT(*) as count FROM $table WHERE $column = ?";
            if ($config['hasDeleted']) {
                $sql .= " AND is_deleted = 0";
            }
            
            $stmt = $conn->prepare($sql);
            if ($stmt) {
                $stmt->bind_param("s", $path);
                $stmt->execute();
                $res = $stmt->get_result()->fetch_assoc();
                $count = (int)$res['count'];
                if ($count > 0) {
                    $totalCount += $count;
                    $details[] = "$table.$column ($count)";
                }
                $stmt->close();
            }
        }
    }

    return array('total' => $totalCount, 'details' => $details);
}

// 獲取教師課程
function getTeacherCourses($conn, $data)
{
    $mId = isset($data['mId']) ? $data['mId'] : '';

    if (empty($mId)) {
        echo json_encode(array("status" => "error", "message" => "Missing teacher ID"));
        return;
    }

    // 查詢教師的課程
    $showDeleted = isset($data['showDeleted']) && $data['showDeleted'] == 1;
    $sql = "SELECT c.*, ca.cateNameTC
            FROM Course c
            LEFT JOIN Category ca ON c.cateId = ca.cateId
            WHERE c.mId = ?";
    if (!$showDeleted) {
        $sql .= " AND c.is_deleted = 0";
    }

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $mId);
    $stmt->execute();
    $result = $stmt->get_result();

    $courses = array();
    while ($row = $result->fetch_assoc()) {
        $courses[] = array(
            "cId" => isset($row["cId"]) ? $row["cId"] : null,
            "cName" => isset($row["cName"]) ? $row["cName"] : null,
            "summary" => isset($row["summary"]) ? $row["summary"] : null,
            "cateNameTC" => isset($row["cateNameTC"]) ? $row["cateNameTC"] : null,
            "rating" => isset($row["avgRating"]) ? (float)$row["avgRating"] : 0.0,
            "purchased" => isset($row["purchasedCount"]) ? (int)$row["purchasedCount"] : 0,
            "is_deleted" => isset($row["is_deleted"]) ? (int)$row["is_deleted"] : 0
        );
    }

    echo json_encode(array(
        "status" => "success",
        "courses" => $courses,
        "count" => count($courses)
    ));

    $stmt->close();
}

// 獲取課程章節
function getCourseLessons($conn, $data)
{
    $cId = isset($data['cId']) ? $data['cId'] : '';

    if (empty($cId)) {
        echo json_encode(array("status" => "error", "message" => "Missing course ID"));
        return;
    }

    // 查詢課程的章節，包含平均評分與評分人數
    $showDeleted = isset($data['showDeleted']) && $data['showDeleted'] == 1;
    $sql = "SELECT l.*, 
            (SELECT AVG(rating) FROM MemberLesson WHERE lId = l.lId AND rating IS NOT NULL) as avgRating,
            (SELECT COUNT(rating) FROM MemberLesson WHERE lId = l.lId AND rating IS NOT NULL) as ratingCount
            FROM Lesson l WHERE l.cId = ?";
    if (!$showDeleted) {
        $sql .= " AND l.is_deleted = 0";
    }
    $sql .= " ORDER BY l.orderNum";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $cId);
    $stmt->execute();
    $result = $stmt->get_result();

    $lessons = array();
    while ($row = $result->fetch_assoc()) {
        $lessons[] = array(
            "lId" => isset($row["lId"]) ? $row["lId"] : null,
            "lName" => isset($row["lName"]) ? $row["lName"] : null,
            "orderNum" => isset($row["orderNum"]) ? $row["orderNum"] : null,
            "uploadDateTime" => isset($row["uploadDateTime"]) ? $row["uploadDateTime"] : null,
            "video" => isset($row["video"]) ? $row["video"] : null,
            "duration" => isset($row["duration"]) ? $row["duration"] : null,
            "status" => isset($row["status"]) ? $row["status"] : null,
            "price" => isset($row["price"]) ? (float)$row["price"] : 0.0,
            "cId" => isset($row["cId"]) ? $row["cId"] : null,
            "is_deleted" => isset($row["is_deleted"]) ? (int)$row["is_deleted"] : 0,
            "avgRating" => isset($row["avgRating"]) ? round((float)$row["avgRating"], 1) : 0.0,
            "ratingCount" => isset($row["ratingCount"]) ? (int)$row["ratingCount"] : 0
        );
    }

    echo json_encode(array(
        "status" => "success",
        "lessons" => $lessons,
        "count" => count($lessons)
    ));

    $stmt->close();
}

// 獲取章節資源
function getLessonResources($conn, $data)
{
    $lId = isset($data['lId']) ? $data['lId'] : '';

    if (empty($lId)) {
        echo json_encode(array("status" => "error", "message" => "Missing lesson ID"));
        return;
    }

    // 查詢章節的資源
    $sql = "SELECT * FROM LessonResource WHERE lId = ? ORDER BY modifiedDate DESC";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $lId);
    $stmt->execute();
    $result = $stmt->get_result();

    $resources = array();
    while ($row = $result->fetch_assoc()) {
        $resources[] = array(
            "lrId" => isset($row["lrId"]) ? $row["lrId"] : null,
            "lrName" => isset($row["lrName"]) ? $row["lrName"] : null,
            "orderNum" => isset($row["orderNum"]) ? $row["orderNum"] : null,
            "resourceType" => isset($row["resourceType"]) ? $row["resourceType"] : null,
            "path" => isset($row["path"]) ? $row["path"] : null,
            "modifiedDate" => isset($row["modifiedDate"]) ? $row["modifiedDate"] : null,
            "lId" => isset($row["lId"]) ? $row["lId"] : null
        );
    }

    echo json_encode(array(
        "status" => "success",
        "resources" => $resources,
        "count" => count($resources)
    ));

    $stmt->close();
}

// 刪除章節影片
function deleteLessonVideo($conn, $data)
{
    $lId = isset($data['lId']) ? $data['lId'] : '';

    if (empty($lId)) {
        echo json_encode(array("status" => "error", "message" => "Missing lesson ID"));
        return;
    }

    // 首先獲取影片路徑，以便刪除實際文件
    $sql = "SELECT video FROM Lesson WHERE lId = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $lId);
    $stmt->execute();
    $result = $stmt->get_result();

    $videoPath = null;
    if ($row = $result->fetch_assoc()) {
        $videoPath = isset($row["video"]) ? $row["video"] : null;
    }

    // 檢查是否有其他記錄引用此影片路徑
    $shouldDeletePhysicalFile = false;
    
    // 無論原本是否為空，都執行更新為 NULL 的動作，確保資料庫狀態一致
    $sql_upd = "UPDATE Lesson SET video = NULL, duration = 0 WHERE lId = ?";
    $stmt_upd = $conn->prepare($sql_upd);
    $stmt_upd->bind_param("s", $lId);
    $success = $stmt_upd->execute();
    $stmt_upd->close();

    if ($success && !empty($videoPath)) {
        $refData = getPathReferenceCount($conn, $videoPath);
        $refCount = $refData['total'];
        if ($refCount == 0) {
            $shouldDeletePhysicalFile = true;
            if (strpos($videoPath, 's3://') === false && strpos($videoPath, 'http') === false) {
                $fullPath = __DIR__ . "/../uploads/" . basename($videoPath);
                if (file_exists($fullPath)) {
                    unlink($fullPath);
                }
            }
        } else {
            $refDetails = implode(", ", $refData['details']);
        }
    }

    if ($success) {
        echo json_encode(array(
            "status" => "success", 
            "message" => "Video record removed from database",
            "shouldDeleteS3" => $shouldDeletePhysicalFile,
            "videoPath" => $videoPath,
            "refCount" => isset($refCount) ? $refCount : 0,
            "refDetails" => isset($refDetails) ? $refDetails : ""
        ));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to delete video"));
    }
}

// 刪除單個章節資源
function deleteLessonResource($conn, $data)
{
    $lrId = isset($data['lrId']) ? $data['lrId'] : '';

    if (empty($lrId)) {
        echo json_encode(array("status" => "error", "message" => "Missing resource ID"));
        return;
    }

    // 首先獲取資源路徑，以便刪除實際文件
    $sql = "SELECT path, resourceType FROM LessonResource WHERE lrId = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $lrId);
    $stmt->execute();
    $result = $stmt->get_result();

    $resourcePath = null;
    $resourceType = null;
    if ($row = $result->fetch_assoc()) {
        $resourcePath = isset($row["path"]) ? $row["path"] : null;
        $resourceType = isset($row["resourceType"]) ? $row["resourceType"] : null;
    }

    // 檢查是否有其他記錄引用此資源路徑
    $shouldDeletePhysicalFile = false;
    if (!empty($resourcePath)) {
        // 先從數據庫中刪除記錄，避免引用計數算到自己
        $sql = "DELETE FROM LessonResource WHERE lrId = ?";
        $stmt_del = $conn->prepare($sql);
        $stmt_del->bind_param("s", $lrId);
        $success = $stmt_del->execute();
        $stmt_del->close();

        if ($success) {
            $refData = getPathReferenceCount($conn, $resourcePath);
            $refCount = $refData['total'];
            if ($refCount == 0) {
                $shouldDeletePhysicalFile = true;
                if ($resourceType === 'FILE' || $resourceType === 'file') {
                    if (strpos($resourcePath, 's3://') === false && strpos($resourcePath, 'http') === false) {
                        $fullPath = __DIR__ . "/../uploads/" . basename($resourcePath);
                        if (file_exists($fullPath)) {
                            unlink($fullPath);
                        }
                    }
                }
            } else {
                $refDetails = implode(", ", $refData['details']);
            }
        }
    } else {
        $success = true;
    }

    if ($success) {
        echo json_encode(array(
            "status" => "success", 
            "message" => "Resource record removed from database",
            "shouldDeleteS3" => $shouldDeletePhysicalFile,
            "resourcePath" => $resourcePath,
            "refCount" => isset($refCount) ? $refCount : 0,
            "refDetails" => isset($refDetails) ? $refDetails : ""
        ));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to delete resource"));
    }
}

// 刪除章節文件
function deleteLessonFiles($conn, $data)
{
    $lId = isset($data['lId']) ? $data['lId'] : '';

    if (empty($lId)) {
        echo json_encode(array("status" => "error", "message" => "Missing lesson ID"));
        return;
    }

    // 首先獲取所有文件路徑，以便刪除實際文件
    $sql = "SELECT path FROM LessonResource WHERE lId = ? AND resourceType = 'file'";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $lId);
    $stmt->execute();
    $result = $stmt->get_result();

    $filePaths = array();
    while ($row = $result->fetch_assoc()) {
        $path = isset($row["path"]) ? $row["path"] : null;
        if (!empty($path)) {
            $filePaths[] = $path;
        }
    }

    // 從數據庫中刪除文件記錄
    $sql = "DELETE FROM LessonResource WHERE lId = ? AND resourceType = 'file'";
    $stmt_del = $conn->prepare($sql);
    $stmt_del->bind_param("s", $lId);
    $success = $stmt_del->execute();
    $stmt_del->close();

    // 檢查哪些檔案可以從 S3 刪除
    $filesToDelete = array();
    if ($success) {
        foreach ($filePaths as $filePath) {
            $refCount = getPathReferenceCount($conn, $filePath);
            if ($refCount == 0) {
                $filesToDelete[] = $filePath;
                if (strpos($filePath, 's3://') === false && strpos($filePath, 'http') === false) {
                    $fullPath = __DIR__ . "/../uploads/" . basename($filePath);
                    if (file_exists($fullPath)) {
                        unlink($fullPath);
                    }
                }
            }
        }
    }

    if ($success) {
        $s3Files = array();
        foreach ($filesToDelete as $f) {
            $isS3 = (strpos($f, 's3://') !== false || strpos($f, 's3.amazonaws.com') !== false || strpos($f, 'fypedu.s3') !== false);
            if ($isS3) {
                $s3Files[] = $f;
            }
        }
        echo json_encode(array(
            "status" => "success", 
            "message" => "File records removed from database",
            "shouldDeleteS3" => !empty($s3Files),
            "s3Files" => $s3Files
        ));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to delete files"));
    }
}

// 隱藏/刪除章節 (Soft Delete)
function deleteLesson($conn, $data) {
    $lId = isset($data['lId']) ? $data['lId'] : '';
    $cleanup = isset($data['cleanup']) && $data['cleanup'] == 1;

    if (empty($lId)) {
        echo json_encode(array("status" => "error", "message" => "Missing lesson ID"));
        return;
    }

    // 1. 先獲取該章節的所有檔案路徑 (不論是否 cleanup 都需要，為了檢查引用)
    $allPaths = array();
    
    // 影片路徑
    $sqlV = "SELECT video FROM Lesson WHERE lId = ?";
    $stmtV = $conn->prepare($sqlV);
    $stmtV->bind_param("s", $lId);
    $stmtV->execute();
    $resV = $stmtV->get_result()->fetch_assoc();
    if (!empty($resV['video'])) $allPaths[] = $resV['video'];
    $stmtV->close();

    // 資源檔案路徑
    $sqlR = "SELECT path FROM LessonResource WHERE lId = ? AND resourceType = 'FILE'";
    $stmtR = $conn->prepare($sqlR);
    $stmtR->bind_param("s", $lId);
    $stmtR->execute();
    $resR = $stmtR->get_result();
    while ($row = $resR->fetch_assoc()) {
        if (!empty($row['path'])) $allPaths[] = $row['path'];
    }
    $stmtR->close();

    // 2. 執行資料庫清理
    $conn->begin_transaction();
    try {
        // 標記章節為已隱藏
        if ($cleanup) {
            // 如果清理空間，則同時將資料庫中的路徑記錄設為 NULL
            $sqlDel = "UPDATE Lesson SET is_deleted = 1, video = NULL WHERE lId = ?";
        } else {
            $sqlDel = "UPDATE Lesson SET is_deleted = 1 WHERE lId = ?";
        }
        $stmtDel = $conn->prepare($sqlDel);
        $stmtDel->bind_param("s", $lId);
        $stmtDel->execute();
        $stmtDel->close();

        // 如果選擇了 cleanup，則刪除 LessonResource 中的相關記錄
        if ($cleanup) {
            $sqlDelRes = "DELETE FROM LessonResource WHERE lId = ?";
            $stmtDelRes = $conn->prepare($sqlDelRes);
            $stmtDelRes->bind_param("s", $lId);
            $stmtDelRes->execute();
            $stmtDelRes->close();
        }

        $conn->commit();
    } catch (Exception $e) {
        $conn->rollback();
        echo json_encode(array("status" => "error", "message" => "Database transaction failed: " . $e->getMessage()));
        return;
    }

    // 3. 檢查哪些檔案可以從 S3 刪除 (在記錄已被標記為 deleted 或已刪除後檢查)
    $s3FilesToDelete = array();
    $refInfo = array();
    if ($cleanup) {
        foreach (array_unique($allPaths) as $path) {
            $refData = getPathReferenceCount($conn, $path);
            if ($refData['total'] == 0) {
                $isCloud = (strpos($path, 's3://') !== false || strpos($path, 'http') !== false);
                if ($isCloud) {
                    $s3FilesToDelete[] = $path;
                } else {
                    $fullPath = __DIR__ . "/../uploads/" . basename($path);
                    if (file_exists($fullPath)) unlink($fullPath);
                }
            } else {
                $refInfo[$path] = implode(", ", $refData['details']);
            }
        }
    }

    echo json_encode(array(
        "status" => "success",
        "message" => "Lesson processed",
        "shouldDeleteS3" => !empty($s3FilesToDelete),
        "s3Files" => $s3FilesToDelete,
        "refInfo" => $refInfo
    ));
}

// 隱藏/刪除課程 (Soft Delete)
function deleteCourse($conn, $data) {
    $cId = isset($data['cId']) ? $data['cId'] : '';
    $cleanup = isset($data['cleanup']) && $data['cleanup'] == 1;

    if (empty($cId)) {
        echo json_encode(array("status" => "error", "message" => "Missing course ID"));
        return;
    }

    // 1. 收集檔案路徑
    $allPaths = array();
    
    // 課程介紹影片與圖片
    $sqlC = "SELECT introVideo, introImg FROM Course WHERE cId = ?";
    $stmtC = $conn->prepare($sqlC);
    $stmtC->bind_param("s", $cId);
    $stmtC->execute();
    $resC = $stmtC->get_result()->fetch_assoc();
    if (!empty($resC['introVideo'])) $allPaths[] = $resC['introVideo'];
    if (!empty($resC['introImg'])) $allPaths[] = $resC['introImg'];
    $stmtC->close();

    // 所有章節的影片
    $sqlLV = "SELECT video FROM Lesson WHERE cId = ?";
    $stmtLV = $conn->prepare($sqlLV);
    $stmtLV->bind_param("s", $cId);
    $stmtLV->execute();
    $resLV = $stmtLV->get_result();
    while ($row = $resLV->fetch_assoc()) {
        if (!empty($row['video'])) $allPaths[] = $row['video'];
    }
    $stmtLV->close();

    // 所有章節的資源檔案
    $sqlLR = "SELECT lr.path 
              FROM LessonResource lr
              JOIN Lesson l ON lr.lId = l.lId
              WHERE l.cId = ? AND lr.resourceType = 'FILE'";
    $stmtLR = $conn->prepare($sqlLR);
    $stmtLR->bind_param("s", $cId);
    $stmtLR->execute();
    $resLR = $stmtLR->get_result();
    while ($row = $resLR->fetch_assoc()) {
        if (!empty($row['path'])) $allPaths[] = $row['path'];
    }
    $stmtLR->close();

    // 2. 執行資料庫處理
    $conn->begin_transaction();
    try {
        // 隱藏課程及其章節
        if ($cleanup) {
            $sqlUpdC = "UPDATE Course SET is_deleted = 1, introVideo = NULL, introImg = NULL WHERE cId = ?";
            $sqlUpdL = "UPDATE Lesson SET is_deleted = 1, video = NULL WHERE cId = ?";
        } else {
            $sqlUpdC = "UPDATE Course SET is_deleted = 1 WHERE cId = ?";
            $sqlUpdL = "UPDATE Lesson SET is_deleted = 1 WHERE cId = ?";
        }
        $stmtUpdC = $conn->prepare($sqlUpdC);
        $stmtUpdC->bind_param("s", $cId);
        $stmtUpdC->execute();

        $stmtUpdL = $conn->prepare($sqlUpdL);
        $stmtUpdL->bind_param("s", $cId);
        $stmtUpdL->execute();

        // 如果 cleanup，則物理刪除該課程章節的所有資源記錄
        if ($cleanup) {
            $sqlDelLR = "DELETE lr FROM LessonResource lr 
                         JOIN Lesson l ON lr.lId = l.lId 
                         WHERE l.cId = ?";
            $stmtDelLR = $conn->prepare($sqlDelLR);
            $stmtDelLR->bind_param("s", $cId);
            $stmtDelLR->execute();
            $stmtDelLR->close();
        }

        $conn->commit();
    } catch (Exception $e) {
        $conn->rollback();
        echo json_encode(array("status" => "error", "message" => "Database transaction failed: " . $e->getMessage()));
        return;
    }

    // 3. 檢查哪些檔案可以從 S3 刪除
    $s3FilesToDelete = array();
    $refInfo = array();
    if ($cleanup) {
        foreach (array_unique($allPaths) as $path) {
            $refData = getPathReferenceCount($conn, $path);
            if ($refData['total'] == 0) {
                $isCloud = (strpos($path, 's3://') !== false || strpos($path, 'http') !== false);
                if ($isCloud) {
                    $s3FilesToDelete[] = $path;
                } else {
                    $fullPath = __DIR__ . "/../uploads/" . basename($path);
                    if (file_exists($fullPath)) unlink($fullPath);
                }
            } else {
                $refInfo[$path] = implode(", ", $refData['details']);
            }
        }
    }

    echo json_encode(array(
        "status" => "success",
        "message" => "Course processed",
        "shouldDeleteS3" => !empty($s3FilesToDelete),
        "s3Files" => $s3FilesToDelete,
        "refInfo" => $refInfo
    ));
}

// 恢復章節 (Restore Lesson)
function restoreLesson($conn, $data) {
    $lId = isset($data['lId']) ? $data['lId'] : '';

    if (empty($lId)) {
        echo json_encode(array("status" => "error", "message" => "Missing lesson ID"));
        return;
    }

    $sql = "UPDATE Lesson SET is_deleted = 0 WHERE lId = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $lId);
    $success = $stmt->execute();
    $stmt->close();

    if ($success) {
        echo json_encode(array("status" => "success", "message" => "Lesson restored successfully"));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to restore lesson"));
    }
}

// 恢復課程 (Restore Course)
function restoreCourse($conn, $data) {
    $cId = isset($data['cId']) ? $data['cId'] : '';

    if (empty($cId)) {
        echo json_encode(array("status" => "error", "message" => "Missing course ID"));
        return;
    }

    $conn->begin_transaction();
    try {
        // 恢復課程本身
        $sqlC = "UPDATE Course SET is_deleted = 0 WHERE cId = ?";
        $stmtC = $conn->prepare($sqlC);
        $stmtC->bind_param("s", $cId);
        $stmtC->execute();

        // 恢復所有章節 (也可以由用戶決定是否全部恢復，這裡默認全部恢復)
        $sqlL = "UPDATE Lesson SET is_deleted = 0 WHERE cId = ?";
        $stmtL = $conn->prepare($sqlL);
        $stmtL->bind_param("s", $cId);
        $stmtL->execute();

        $conn->commit();
        echo json_encode(array("status" => "success", "message" => "Course and lessons restored successfully"));
    } catch (Exception $e) {
        $conn->rollback();
        echo json_encode(array("status" => "error", "message" => "Failed to restore course"));
    }
}

// 獲取所有分類
function getCategories($conn) {
    $sql = "SELECT cateId, cateNameTC, cateNameE FROM Category ORDER BY cateId ASC";
    $result = $conn->query($sql);
    
    $categories = array();
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $categories[] = array(
                "cateId" => $row['cateId'],
                "cateNameTC" => $row['cateNameTC'],
                "cateNameEN" => $row['cateNameE']
            );
        }
    }
    
    echo json_encode(array(
        "status" => "success",
        "categories" => $categories
    ));
}

// 上傳章節資源（文件）
function uploadLessonResource($conn, $data)
{
    $lId = isset($data['lId']) ? $data['lId'] : '';
    $lrName = isset($data['lrName']) ? $data['lrName'] : '';
    $path = isset($data['path']) ? $data['path'] : '';

    if (empty($lId) || empty($lrName) || empty($path)) {
        echo json_encode(array("status" => "error", "message" => "Missing required parameters"));
        return;
    }

    // 生成唯一的lrId
    $sql = "SELECT MAX(SUBSTRING(lrId, 3)) as maxId FROM LessonResource";
    $result = $conn->query($sql);
    $maxId = 0;
    if ($row = $result->fetch_assoc()) {
        $maxId = isset($row['maxId']) ? intval($row['maxId']) : 0;
    }
    $newId = $maxId + 1;
    $lrId = 'Lr' . str_pad($newId, 6, '0', STR_PAD_LEFT);

    // 插入资源記錄
    $sql = "INSERT INTO LessonResource (lrId, lrName, resourceType, path, modifiedDate, lId) VALUES (?, ?, ?, ?, NOW(), ?)";
    $stmt = $conn->prepare($sql);
    $resourceType = 'FILE';
    $stmt->bind_param("sssss", $lrId, $lrName, $resourceType, $path, $lId);
    $success = $stmt->execute();

    $stmt->close();

    if ($success) {
        echo json_encode(array("status" => "success", "message" => "Resource uploaded successfully", "lrId" => $lrId));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to upload resource"));
    }
}

// 上傳章節資源（URL）
function uploadLessonResourceUrl($conn, $data)
{
    $lId = isset($data['lId']) ? $data['lId'] : '';
    $lrName = isset($data['lrName']) ? $data['lrName'] : '';
    $path = isset($data['path']) ? $data['path'] : '';

    if (empty($lId) || empty($lrName) || empty($path)) {
        echo json_encode(array("status" => "error", "message" => "Missing required parameters"));
        return;
    }

    // 生成唯一的lrId
    $sql = "SELECT MAX(SUBSTRING(lrId, 3)) as maxId FROM LessonResource";
    $result = $conn->query($sql);
    $maxId = 0;
    if ($row = $result->fetch_assoc()) {
        $maxId = isset($row['maxId']) ? intval($row['maxId']) : 0;
    }
    $newId = $maxId + 1;
    $lrId = 'Lr' . str_pad($newId, 6, '0', STR_PAD_LEFT);

    // 插入资源記錄
    $sql = "INSERT INTO LessonResource (lrId, lrName, resourceType, path, modifiedDate, lId) VALUES (?, ?, ?, ?, NOW(), ?)";
    $stmt = $conn->prepare($sql);
    $resourceType = 'URL';
    $stmt->bind_param("sssss", $lrId, $lrName, $resourceType, $path, $lId);
    $success = $stmt->execute();

    $stmt->close();

    if ($success) {
        echo json_encode(array("status" => "success", "message" => "Resource URL added successfully", "lrId" => $lrId));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to add resource URL"));
    }
}

// 創建課程
function createCourse($conn, $data)
{
    $cName = isset($data['cName']) ? $data['cName'] : '';
    $unitPrice = isset($data['unitPrice']) ? $data['unitPrice'] : 0;
    $summary = isset($data['summary']) ? $data['summary'] : '';
    $totalLesson = isset($data['totalLesson']) ? $data['totalLesson'] : 0;
    $cateId = isset($data['cateId']) ? $data['cateId'] : '';
    $mId = isset($data['mId']) ? $data['mId'] : '';
    $langId = isset($data['langId']) ? $data['langId'] : 'Lg000001'; // 默認英文

    if (empty($cName) || empty($mId) || empty($cateId)) {
        echo json_encode(array("status" => "error", "message" => "Missing required parameters"));
        return;
    }

    // 生成唯一的cId
    $sql = "SELECT MAX(SUBSTRING(cId, 2)) as maxId FROM Course";
    $result = $conn->query($sql);
    $maxId = 0;
    if ($row = $result->fetch_assoc()) {
        $maxId = isset($row['maxId']) ? intval($row['maxId']) : 0;
    }
    $newId = $maxId + 1;
    $cId = 'C' . str_pad($newId, 7, '0', STR_PAD_LEFT);

    // 插入课程记录
    $sql = "INSERT INTO Course (cId, cName, unitPrice, summary, totalLesson, cateId, mId, langId, is_deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssdsisss", $cId, $cName, $unitPrice, $summary, $totalLesson, $cateId, $mId, $langId);
    $success = $stmt->execute();

    $stmt->close();

    if ($success) {
        echo json_encode(array("status" => "success", "message" => "Course created successfully", "cId" => $cId));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to create course"));
    }
}

// 創建課時
function createLesson($conn, $data)
{
    $cId = isset($data['cId']) ? $data['cId'] : '';
    $lName = isset($data['lName']) ? $data['lName'] : '';
    $duration = isset($data['duration']) ? $data['duration'] : 0;
    $price = isset($data['price']) ? floatval($data['price']) : 0.0;
    $orderNum = isset($data['orderNum']) ? $data['orderNum'] : 1;

    if (empty($cId) || empty($lName)) {
        echo json_encode(array("status" => "error", "message" => "Missing required parameters"));
        return;
    }

    // 生成唯一的lId
    $sql = "SELECT MAX(SUBSTRING(lId, 2)) as maxId FROM Lesson";
    $result = $conn->query($sql);
    $maxId = 0;
    if ($row = $result->fetch_assoc()) {
        $maxId = isset($row['maxId']) ? intval($row['maxId']) : 0;
    }
    $newId = $maxId + 1;
    $lId = 'L' . str_pad($newId, 7, '0', STR_PAD_LEFT);

    // 插入課時記錄
    $sql = "INSERT INTO Lesson (lId, lName, orderNum, uploadDateTime, video, duration, status, price, cId) VALUES (?, ?, ?, NOW(), NULL, ?, 'COMPLETED', ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssisds", $lId, $lName, $orderNum, $duration, $price, $cId);
    $success = $stmt->execute();

    $stmt->close();

    if ($success) {
        echo json_encode(array("status" => "success", "message" => "Lesson created successfully", "lId" => $lId));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to create lesson"));
    }
}

// 更新課時影片與時長
function updateLessonVideo($conn, $data)
{
    $lId = isset($data['lId']) ? $data['lId'] : '';
    $videoPath = isset($data['videoPath']) ? $data['videoPath'] : '';
    $duration = isset($data['duration']) ? intval($data['duration']) : null;

    if (empty($lId) || empty($videoPath)) {
        echo json_encode(array("status" => "error", "message" => "Missing required parameters"));
        return;
    }

    // 構建更新語句
    $sql = "UPDATE Lesson SET video = ?, uploadDateTime = NOW()";
    $params = array($videoPath);
    $types = "s";

    if ($duration !== null) {
        $sql .= ", duration = ?";
        $params[] = $duration;
        $types .= "i";
    }

    $sql .= " WHERE lId = ?";
    $params[] = $lId;
    $types .= "s";

    // 更新數據庫
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $success = $stmt->execute();

    $stmt->close();

    if ($success) {
        echo json_encode(array("status" => "success", "message" => "Lesson video updated successfully"));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to update lesson video"));
    }
}

// 更新課程
function updateCourse($conn, $data) {
    $cId = isset($data['cId']) ? $data['cId'] : '';
    $cName = isset($data['cName']) ? $data['cName'] : '';
    $summary = isset($data['cDescription']) ? $data['cDescription'] : '';
    $unitPrice = isset($data['unitPrice']) ? $data['unitPrice'] : '';
    $totalLesson = isset($data['totalLesson']) ? $data['totalLesson'] : '';
    $subject = isset($data['subject']) ? $data['subject'] : '';

    if (empty($cId)) {
        echo json_encode(array("status" => "error", "message" => "Missing required parameters"));
        return;
    }

    // 獲取分類ID
    $cateId = '';
    if (!empty($subject)) {
        $cateSql = "SELECT cateId FROM Category WHERE cateNameTC = ?";
        $cateStmt = $conn->prepare($cateSql);
        $cateStmt->bind_param("s", $subject);
        $cateStmt->execute();
        $cateResult = $cateStmt->get_result();
        
        if ($cateRow = $cateResult->fetch_assoc()) {
            $cateId = $cateRow['cateId'];
        }
        
        $cateStmt->close();
    }

    // 構建SQL語句
    $sql = "UPDATE Course";
    $params = array();
    $types = "";
    $setClause = array();

    // 添加可選字段
    if (!empty($cName)) {
        $setClause[] = "cName = ?";
        $params[] = $cName;
        $types .= "s";
    }

    if (!empty($summary)) {
        $setClause[] = "summary = ?";
        $params[] = $summary;
        $types .= "s";
    }

    if (!empty($unitPrice)) {
        $setClause[] = "unitPrice = ?";
        $params[] = $unitPrice;
        $types .= "d";
    }

    if (!empty($totalLesson)) {
        $setClause[] = "totalLesson = ?";
        $params[] = $totalLesson;
        $types .= "i";
    }

    if (!empty($cateId)) {
        $setClause[] = "cateId = ?";
        $params[] = $cateId;
        $types .= "s";
    }

    // 檢查是否有字段需要更新
    if (empty($setClause)) {
        echo json_encode(array("status" => "error", "message" => "No fields to update"));
        return;
    }

    // 組合SQL語句
    $sql .= " SET " . implode(", ", $setClause);

    $sql .= " WHERE cId = ?";
    $params[] = $cId;
    $types .= "s";

    // 執行更新
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $success = $stmt->execute();

    $stmt->close();

    if ($success) {
        echo json_encode(array("status" => "success", "message" => "Course updated successfully"));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to update course"));
    }
}

// 更新課時
function updateLesson($conn, $data) {
    $lId = isset($data['lId']) ? $data['lId'] : '';
    $lName = isset($data['lName']) ? $data['lName'] : '';
    $duration = isset($data['duration']) ? $data['duration'] : '';
    $price = isset($data['price']) ? $data['price'] : '';
    $orderNum = isset($data['orderNum']) ? $data['orderNum'] : '';
    $video = isset($data['video']) ? $data['video'] : '';

    if (empty($lId) || empty($lName)) {
        echo json_encode(array("status" => "error", "message" => "Missing required parameters"));
        return;
    }

    // 構建SQL語句
    $sql = "UPDATE Lesson SET lName = ?, duration = ?";
    $params = array($lName, $duration);
    $types = "si";

    // 如果提供了價格，則更新
    if ($price !== '') {
        $sql .= ", price = ?";
        $params[] = floatval($price);
        $types .= "d";
    }

    // 如果提供了順序號，則更新
    if (!empty($orderNum)) {
        $sql .= ", orderNum = ?";
        $params[] = $orderNum;
        $types .= "i";
    }

    // 如果提供了影片，則更新 (如果是空字串則設為 NULL)
    if ($video !== null) {
        if ($video === '') {
            $sql .= ", video = NULL, duration = 0, uploadDateTime = NULL";
        } else {
            $sql .= ", video = ?, uploadDateTime = NOW()";
            $params[] = $video;
            $types .= "s";
        }
    }

    $sql .= " WHERE lId = ?";
    $params[] = $lId;
    $types .= "s";

    // 執行更新
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $success = $stmt->execute();

    $stmt->close();

    if ($success) {
        echo json_encode(array("status" => "success", "message" => "Lesson updated successfully"));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to update lesson"));
    }
}

// 獲取課程學生列表
function getCourseStudents($conn, $data) {
    $cId = isset($data['cId']) ? $data['cId'] : '';

    if (empty($cId)) {
        echo json_encode(array("status" => "error", "message" => "Missing course ID"));
        return;
    }

    // 查詢購買該課程的學生
    $sql = "SELECT m.mId, m.username, m.email, m.tel, mc.rating, mc.result, mc.PurchaseDate 
            FROM MemberCourse mc 
            JOIN Member m ON mc.mId = m.mId 
            WHERE mc.cId = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $cId);
    $stmt->execute();
    $result = $stmt->get_result();

    $students = array();
    while ($row = $result->fetch_assoc()) {
        $students[] = array(
            'mId' => $row['mId'],
            'username' => $row['username'],
            'email' => $row['email'],
            'tel' => $row['tel'],
            'rating' => $row['rating'],
            'result' => $row['result'],
            'purchaseDate' => $row['PurchaseDate']
        );
    }

    $stmt->close();

    echo json_encode(array(
        "status" => "success",
        "students" => $students
    ));
}

// 獲取學生在特定課程的詳細進度與資料
function getStudentDetail($conn, $data) {
    $cId = isset($data['cId']) ? $data['cId'] : '';
    $mId = isset($data['mId']) ? $data['mId'] : '';

    if (empty($cId) || empty($mId)) {
        echo json_encode(array("status" => "error", "message" => "Missing course ID or member ID"));
        return;
    }

    // 1. 獲取學生基本資料與課程購買資訊
    $sql = "SELECT m.mId, m.username, m.email, m.tel, m.avatar, m.gender, m.regDate,
                   mc.rating, mc.comment, mc.result, mc.PurchaseDate 
            FROM MemberCourse mc 
            JOIN Member m ON mc.mId = m.mId 
            WHERE mc.cId = ? AND mc.mId = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ss", $cId, $mId);
    $stmt->execute();
    $studentInfo = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$studentInfo) {
        echo json_encode(array("status" => "error", "message" => "Student not found for this course"));
        return;
    }

    // 2. 獲取該課程的所有章節及學生的完成情況 (包含評分)
    $sql = "SELECT l.lId, l.lName, l.orderNum, ml.firstLesson, ml.rating 
            FROM Lesson l 
            LEFT JOIN MemberLesson ml ON l.lId = ml.lId AND ml.mId = ?
            WHERE l.cId = ? 
            ORDER BY l.orderNum ASC";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ss", $mId, $cId);
    $stmt->execute();
    $result = $stmt->get_result();

    $lessons = array();
    while ($row = $result->fetch_assoc()) {
        $lessons[] = array(
            'lId' => $row['lId'],
            'lName' => $row['lName'],
            'orderNum' => $row['orderNum'],
            'completed' => $row['firstLesson'] !== null,
            'completionDate' => $row['firstLesson'],
            'rating' => isset($row['rating']) ? (int)$row['rating'] : null
        );
    }
    $stmt->close();

    echo json_encode(array(
        "status" => "success",
        "student" => $studentInfo,
        "lessons" => $lessons
    ));
}

// 獲取教師數據總覽 (AnalyticsDashboard)
function getTeacherOverallStats($conn, $data) {
    $mId = isset($data['mId']) ? $data['mId'] : '';

    if (empty($mId)) {
        echo json_encode(array("status" => "error", "message" => "Missing member ID"));
        return;
    }

    // 1. 核心指標 (總收入, 總學生數, 總收藏數, 課程總數)
    $sql = "SELECT 
            (SELECT SUM(c.unitPrice) FROM MemberCourse mc JOIN Course c ON mc.cId = c.cId WHERE c.mId = ?) as totalIncome,
            (SELECT COUNT(DISTINCT mc.mId) FROM MemberCourse mc JOIN Course c ON mc.cId = c.cId WHERE c.mId = ?) as totalStudents,
            (SELECT SUM(bookmarkCount) FROM Course WHERE mId = ?) as totalBookmarks,
            (SELECT COUNT(*) FROM Course WHERE mId = ?) as totalCourses";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssss", $mId, $mId, $mId, $mId);
    $stmt->execute();
    $result = $stmt->get_result();
    $baseStats = $result->fetch_assoc();
    $stmt->close();

    // 2. 獲取最近 7 天的收入趨勢 (累計總收入)
    $revenueTrend = array();
    $cumulativeIncome = 0;
    
    // 獲取 7 天前的累計收入
    $sevenDaysAgo = date('Y-m-d', strtotime("-7 days"));
    $sqlStart = "SELECT SUM(c.unitPrice) as startIncome 
                FROM MemberCourse mc 
                JOIN Course c ON mc.cId = c.cId 
                WHERE c.mId = ? AND DATE(mc.PurchaseDate) < ?";
    $stmtS = $conn->prepare($sqlStart);
    $stmtS->bind_param("ss", $mId, $sevenDaysAgo);
    $stmtS->execute();
    $resS = $stmtS->get_result()->fetch_assoc();
    $cumulativeIncome = (float)($resS['startIncome'] ?? 0);
    $stmtS->close();

    for ($i = 6; $i >= 0; $i--) {
        $date = date('Y-m-d', strtotime("-$i days"));
        $sqlTrend = "SELECT SUM(c.unitPrice) as dailyIncome 
                    FROM MemberCourse mc 
                    JOIN Course c ON mc.cId = c.cId 
                    WHERE c.mId = ? AND DATE(mc.PurchaseDate) = ?";
        $stmtT = $conn->prepare($sqlTrend);
        $stmtT->bind_param("ss", $mId, $date);
        $stmtT->execute();
        $resT = $stmtT->get_result()->fetch_assoc();
        $dailyIncome = (float)($resT['dailyIncome'] ?? 0);
        $cumulativeIncome += $dailyIncome;
        
        $revenueTrend[] = array(
            'date' => date('m/d', strtotime($date)),
            'value' => $cumulativeIncome,
            'dailyValue' => $dailyIncome
        );
        $stmtT->close();
    }

    // 3. 課程表現排行 (最高收入與最低評分)
    // 最高收入
    $sqlBest = "SELECT c.cName, SUM(c.unitPrice) as totalRevenue 
                FROM MemberCourse mc 
                JOIN Course c ON mc.cId = c.cId 
                WHERE c.mId = ? 
                GROUP BY c.cId 
                ORDER BY totalRevenue DESC LIMIT 1";
    $stmtB = $conn->prepare($sqlBest);
    $stmtB->bind_param("s", $mId);
    $stmtB->execute();
    $bestCourse = $stmtB->get_result()->fetch_assoc();
    $stmtB->close();

    // 需優化 (評分最低且有評分的課程)
    $sqlWorst = "SELECT cName, avgRating FROM Course WHERE mId = ? AND avgRating > 0 ORDER BY avgRating ASC LIMIT 1";
    $stmtW = $conn->prepare($sqlWorst);
    $stmtW->bind_param("s", $mId);
    $stmtW->execute();
    $worstCourse = $stmtW->get_result()->fetch_assoc();
    $stmtW->close();

    echo json_encode(array(
        "status" => "success",
        "stats" => array(
            'totalIncome' => (float)($baseStats['totalIncome'] ?? 0),
            'totalStudents' => (int)($baseStats['totalStudents'] ?? 0),
            'totalBookmarks' => (int)($baseStats['totalBookmarks'] ?? 0),
            'totalCourses' => (int)($baseStats['totalCourses'] ?? 0)
        ),
        'revenueTrend' => $revenueTrend,
        'performance' => array(
            'best' => $bestCourse ? array('name' => $bestCourse['cName'], 'value' => 'HK$ ' . number_format($bestCourse['totalRevenue'])) : null,
            'needsOptimization' => $worstCourse ? array('name' => $worstCourse['cName'], 'value' => '評分: ' . $worstCourse['avgRating']) : null
        )
    ));
}

// 獲取課程學生統計數據
function getCourseStudentStats($conn, $data) {
    $cId = isset($data['cId']) ? $data['cId'] : '';

    if (empty($cId)) {
        echo json_encode(array("status" => "error", "message" => "Missing course ID"));
        return;
    }

    // 1. 獲取基本統計數據 (收入、學生數、評分、收藏)
    $sql = "SELECT 
            c.unitPrice,
            c.bookmarkCount,
            c.purchasedCount,
            c.avgRating,
            (SELECT COUNT(*) FROM MemberCourse mc WHERE mc.cId = ?) as actualPurchasedCount,
            (SELECT SUM(c.unitPrice) FROM MemberCourse mc JOIN Course c ON mc.cId = c.cId WHERE mc.cId = ?) as totalIncome,
            (SELECT COUNT(DISTINCT mId) FROM MemberLesson ml JOIN Lesson l ON ml.lId = l.lId WHERE l.cId = ?) as activeStudents
            FROM Course c
            WHERE c.cId = ?";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssss", $cId, $cId, $cId, $cId);
    $stmt->execute();
    $result = $stmt->get_result();
    $courseBase = $result->fetch_assoc();
    $stmt->close();

    $stats = array(
        'totalStudents' => (int)($courseBase['actualPurchasedCount'] ?? 0),
        'activeStudents' => (int)($courseBase['activeStudents'] ?? 0),
        'avgRating' => (float)($courseBase['avgRating'] ?? 0),
        'totalIncome' => (float)($courseBase['totalIncome'] ?? 0),
        'bookmarkCount' => (int)($courseBase['bookmarkCount'] ?? 0)
    );

    // 2. 獲取最近 7 天的趨勢 (累計總收入與總銷售量)
    $revenueTrend = array();
    $salesTrend = array();
    $cumulativeCount = 0;
    $cumulativeIncome = 0;
    
    // 獲取 7 天前的累計數據
    $sevenDaysAgo = date('Y-m-d', strtotime("-7 days"));
    
    // 累計數量與收入
    $sqlStart = "SELECT COUNT(*) as startCount, SUM(c.unitPrice) as startIncome 
                FROM MemberCourse mc 
                JOIN Course c ON mc.cId = c.cId 
                WHERE mc.cId = ? AND DATE(mc.PurchaseDate) < ?";
    $stmtS = $conn->prepare($sqlStart);
    $stmtS->bind_param("ss", $cId, $sevenDaysAgo);
    $stmtS->execute();
    $resS = $stmtS->get_result()->fetch_assoc();
    $cumulativeCount = (int)($resS['startCount'] ?? 0);
    $cumulativeIncome = (float)($resS['startIncome'] ?? 0);
    $stmtS->close();

    for ($i = 6; $i >= 0; $i--) {
        $date = date('Y-m-d', strtotime("-$i days"));
        $sqlTrend = "SELECT COUNT(*) as dailyCount, SUM(c.unitPrice) as dailyIncome 
                    FROM MemberCourse mc 
                    JOIN Course c ON mc.cId = c.cId 
                    WHERE mc.cId = ? AND DATE(mc.PurchaseDate) = ?";
        $stmtT = $conn->prepare($sqlTrend);
        $stmtT->bind_param("ss", $cId, $date);
        $stmtT->execute();
        $resT = $stmtT->get_result()->fetch_assoc();
        
        $cumulativeCount += (int)($resT['dailyCount'] ?? 0);
        $cumulativeIncome += (float)($resT['dailyIncome'] ?? 0);
        
        $salesTrend[] = array(
            'date' => date('m/d', strtotime($date)),
            'count' => $cumulativeCount,
            'dailyCount' => (int)($resT['dailyCount'] ?? 0)
        );
        $revenueTrend[] = array(
            'date' => date('m/d', strtotime($date)),
            'value' => $cumulativeIncome,
            'dailyValue' => (float)($resT['dailyIncome'] ?? 0)
        );
        $stmtT->close();
    }

    // 3. 獲取最近活動
    $sql2 = "SELECT 
            m.username,
            h.history,
            h.regDate
            FROM History h
            JOIN Member m ON h.mId = m.mId
            WHERE h.history LIKE CONCAT('%', ? ,'%')
            ORDER BY h.regDate DESC
            LIMIT 10";
    $stmt2 = $conn->prepare($sql2);
    $stmt2->bind_param("s", $cId);
    $stmt2->execute();
    $result2 = $stmt2->get_result();

    $recentActivities = array();
    while ($row = $result2->fetch_assoc()) {
        $recentActivities[] = array(
            'username' => $row['username'],
            'history' => $row['history'],
            'regDate' => $row['regDate']
        );
    }
    $stmt2->close();

    echo json_encode(array(
        "status" => "success",
        "stats" => $stats,
        "salesTrend" => $salesTrend,
        "revenueTrend" => $revenueTrend,
        "recentActivities" => $recentActivities
    ));
}

// 獲取課程統計數據
function getCourseStats($conn, $data) {
    $cId = isset($data['cId']) ? $data['cId'] : '';

    if (empty($cId)) {
        echo json_encode(array("status" => "error", "message" => "Missing course ID"));
        return;
    }

    // 獲取課程詳細信息
    $sql = "SELECT 
            c.cName,
            c.unitPrice,
            c.cateId,
            c.totalLesson,
            c.summary,
            c.introImg,
            c.introVideo,
            c.nsfwScore,
            c.auditStatus
            FROM Course c 
            WHERE c.cId = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $cId);
    $stmt->execute();
    $result = $stmt->get_result();

    $stats = array();
    if ($row = $result->fetch_assoc()) {
        // 獲取分類名稱
        $cateId = $row['cateId'];
        $subject = '';
        
        $cateSql = "SELECT cateNameTC FROM Category WHERE cateId = ?";
        $cateStmt = $conn->prepare($cateSql);
        $cateStmt->bind_param("s", $cateId);
        $cateStmt->execute();
        $cateResult = $cateStmt->get_result();
        
        if ($cateRow = $cateResult->fetch_assoc()) {
            $subject = $cateRow['cateNameTC'];
        }
        
        $cateStmt->close();
        
        $stats = array(
            'cName' => $row['cName'],
            'unitPrice' => $row['unitPrice'],
            'subject' => $subject,
            'totalLesson' => $row['totalLesson'],
            'summary' => $row['summary'],
            'introImg' => $row['introImg'] ?? null,
            'introVideo' => $row['introVideo'] ?? null,
            'nsfwScore' => $row['nsfwScore'] ?? 0,
            'auditStatus' => $row['auditStatus'] ?? 'approved'
        );
    }

    $stmt->close();

    echo json_encode(array(
        "status" => "success",
        "stats" => $stats
    ));
}

// 更新課程媒體（圖片與影片）
function updateCourseMedia($conn, $data) {
    $cId = isset($data['cId']) ? $data['cId'] : '';
    $introImg = isset($data['introImg']) ? $data['introImg'] : (isset($data['courseImage']) ? $data['courseImage'] : null);
    $introVideo = isset($data['introVideo']) ? $data['introVideo'] : null;
    $nsfwScore = isset($data['nsfwScore']) ? $data['nsfwScore'] : null;
    $auditStatus = isset($data['auditStatus']) ? $data['auditStatus'] : null;

    if (empty($cId)) {
        echo json_encode(array("status" => "error", "message" => "Missing course ID"));
        return;
    }

    $updates = array();
    $params = array();
    $types = "";

    if ($introImg !== null) {
        if ($introImg === '') {
            $updates[] = "introImg = NULL";
        } else {
            $updates[] = "introImg = ?";
            $params[] = $introImg;
            $types .= "s";
        }
    }

    if ($introVideo !== null) {
        if ($introVideo === '') {
            $updates[] = "introVideo = NULL";
        } else {
            $updates[] = "introVideo = ?";
            $params[] = $introVideo;
            $types .= "s";
        }
    }

    if ($nsfwScore !== null) {
        $updates[] = "nsfwScore = ?";
        $params[] = $nsfwScore;
        $types .= "d";
    }

    if ($auditStatus !== null) {
        $updates[] = "auditStatus = ?";
        $params[] = $auditStatus;
        $types .= "s";
    }

    if (empty($updates)) {
        echo json_encode(array("status" => "error", "message" => "No media provided to update"));
        return;
    }

    // 檢查欄位是否存在，若不存在則自動創建
    $conn->query("ALTER TABLE Course ADD COLUMN IF NOT EXISTS nsfwScore DOUBLE DEFAULT 0");
    $conn->query("ALTER TABLE Course ADD COLUMN IF NOT EXISTS auditStatus VARCHAR(20) DEFAULT 'approved'");

    $sql = "UPDATE Course SET " . implode(", ", $updates) . " WHERE cId = ?";
    $params[] = $cId;
    $types .= "s";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $success = $stmt->execute();

    if ($success) {
        echo json_encode(array("status" => "success", "message" => "Course media updated successfully"));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to update course media: " . $conn->error));
    }

    $stmt->close();
}

// ================================================================
// 將以下 3 個 case 加入 switch($action) 的 default 之前
// ================================================================
//    case 'submit_heygen_job':
//        submitHeygenJob($conn, $data);
//        break;
//    case 'poll_heygen_job':
//        pollHeygenJob($conn, $data);
//        break;
//    case 'complete_heygen_job':
//        completeHeygenJob($conn, $data);
//        break;

// ================================================================
// DB 建表 SQL（在 phpMyAdmin 或 MySQL CLI 執行一次）
// ================================================================
// CREATE TABLE IF NOT EXISTS HeyGenJob (
//     jobId        VARCHAR(20)  NOT NULL PRIMARY KEY,
//     mId          VARCHAR(10)  NOT NULL,
//     lId          VARCHAR(10),
//     cId          VARCHAR(10),
//     audioS3Url   TEXT         NOT NULL,
//     avatarId     VARCHAR(100) NOT NULL,
//     heygenVideoId VARCHAR(100),
//     status       ENUM('processing','heygen_done','error') DEFAULT 'processing',
//     progress     INT          DEFAULT 5,
//     resultVideoUrl TEXT,
//     errorMsg     TEXT,
//     createdAt    DATETIME     DEFAULT NOW(),
//     updatedAt    DATETIME     DEFAULT NOW() ON UPDATE NOW()
// ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

// ================================================================
// 函數 1: 提交 HeyGen 任務
// App 調用: POST { action: submit_heygen_job, mId, lId, cId, audioS3Url, avatarId }
// 回傳: { status, jobId, heygenVideoId }
// ================================================================
function submitHeygenJob($conn, $data) {
    $mId      = isset($data['mId'])        ? trim($data['mId'])        : '';
    $lId      = isset($data['lId'])        ? trim($data['lId'])        : '';
    $cId      = isset($data['cId'])        ? trim($data['cId'])        : '';
    $audioUrl = isset($data['audioS3Url']) ? trim($data['audioS3Url']) : '';
    $avatarId = isset($data['avatarId'])   ? trim($data['avatarId'])   : '';

    if (empty($mId) || empty($audioUrl) || empty($avatarId)) {
        echo json_encode(array("status" => "error", "message" => "Missing required: mId, audioS3Url, avatarId"));
        return;
    }

    $apiKey = 'sk_V2_hgu_kAKJHu08jRg_7x0pJdAFRrB3DLgnXqQAufqiG1C8OFAV'; // ← 換成你的真實 API Key

    // 1a. 上傳聲音到 HeyGen
    $uploadResp = _heygenUploadAudio($apiKey, $audioUrl);
    if (!$uploadResp || empty($uploadResp['data']['id'])) {
        echo json_encode(array(
            "status"  => "error",
            "message" => "HeyGen audio upload failed",
            "detail"  => $uploadResp
        ));
        return;
    }
    $audioAssetId = $uploadResp['data']['id'];

    // 1b. 提交影片生成
    $createResp = _heygenCreateVideo($apiKey, $avatarId, $audioAssetId);
    if (!$createResp || empty($createResp['data']['video_id'])) {
        echo json_encode(array(
            "status"  => "error",
            "message" => "HeyGen video creation failed",
            "detail"  => $createResp
        ));
        return;
    }
    $heygenVideoId = $createResp['data']['video_id'];

    // 1c. 生成 jobId，寫入 DB
    $result = $conn->query("SELECT MAX(CAST(SUBSTRING(jobId, 4) AS UNSIGNED)) as maxId FROM HeyGenJob");
    $row   = $result->fetch_assoc();
    $maxId = isset($row['maxId']) ? intval($row['maxId']) : 0;
    $jobId = 'HYG' . str_pad($maxId + 1, 6, '0', STR_PAD_LEFT);

    $sql  = "INSERT INTO HeyGenJob (jobId, mId, lId, cId, audioS3Url, avatarId, heygenVideoId, status, progress) VALUES (?, ?, ?, ?, ?, ?, ?, 'processing', 5)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssssss", $jobId, $mId, $lId, $cId, $audioUrl, $avatarId, $heygenVideoId);
    $ok = $stmt->execute();
    $stmt->close();

    if (!$ok) {
        echo json_encode(array("status" => "error", "message" => "DB insert failed: " . $conn->error));
        return;
    }

    echo json_encode(array(
        "status"        => "success",
        "jobId"         => $jobId,
        "heygenVideoId" => $heygenVideoId
    ));
}

// ================================================================
// 函數 2: 輪詢任務進度 (App 每 15 秒調用)
// App 調用: POST { action: poll_heygen_job, jobId }
// 回傳: { status, jobStatus, progress, resultVideoUrl }
// jobStatus 值: processing | heygen_done | error
// ================================================================
function pollHeygenJob($conn, $data) {
    $jobId = isset($data['jobId']) ? trim($data['jobId']) : '';
    if (empty($jobId)) {
        echo json_encode(array("status" => "error", "message" => "Missing jobId"));
        return;
    }

    $sql  = "SELECT * FROM HeyGenJob WHERE jobId = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $jobId);
    $stmt->execute();
    $job = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$job) {
        echo json_encode(array("status" => "error", "message" => "Job not found: $jobId"));
        return;
    }

    // 如果已是 heygen_done 或 error，直接回傳 DB 狀態（不再查 HeyGen）
    if ($job['status'] === 'heygen_done' || $job['status'] === 'error') {
        echo json_encode(array(
            "status"         => "success",
            "jobStatus"      => $job['status'],
            "progress"       => (int)$job['progress'],
            "resultVideoUrl" => $job['resultVideoUrl'],
            "errorMsg"       => $job['errorMsg']
        ));
        return;
    }

    // 查詢 HeyGen 最新狀態
    $apiKey      = 'sk_V2_hgu_kAKJHu08jRg_7x0pJdAFRrB3DLgnXqQAufqiG1C8OFAV';
    $heygenResp  = _heygenGetStatus($apiKey, $job['heygenVideoId']);

    if (!$heygenResp || !isset($heygenResp['data']['status'])) {
        // HeyGen API 暫時不可用，回傳目前 DB 進度
        echo json_encode(array(
            "status"    => "success",
            "jobStatus" => "processing",
            "progress"  => (int)$job['progress'],
            "message"   => "HeyGen API unavailable, will retry"
        ));
        return;
    }

    $hStatus  = $heygenResp['data']['status']; // pending / processing / completed / failed
    $videoUrl = isset($heygenResp['data']['video_url']) ? $heygenResp['data']['video_url'] : null;

    // 進度映射
    $progressMap = array('pending' => 15, 'processing' => 40, 'completed' => 65, 'failed' => 0);
    $progress = isset($progressMap[$hStatus]) ? $progressMap[$hStatus] : 30;

    if ($hStatus === 'completed' && $videoUrl) {
        // HeyGen 完成！更新 DB
        $sqlU = "UPDATE HeyGenJob SET status='heygen_done', progress=65, resultVideoUrl=? WHERE jobId=?";
        $sU   = $conn->prepare($sqlU);
        $sU->bind_param("ss", $videoUrl, $jobId);
        $sU->execute();
        $sU->close();

        echo json_encode(array(
            "status"         => "success",
            "jobStatus"      => "heygen_done",
            "progress"       => 65,
            "resultVideoUrl" => $videoUrl
        ));

    } elseif ($hStatus === 'failed') {
        $errMsg = isset($heygenResp['data']['error']['message']) ? $heygenResp['data']['error']['message'] : 'HeyGen failed';
        $sqlU   = "UPDATE HeyGenJob SET status='error', errorMsg=? WHERE jobId=?";
        $sU     = $conn->prepare($sqlU);
        $sU->bind_param("ss", $errMsg, $jobId);
        $sU->execute();
        $sU->close();

        echo json_encode(array(
            "status"    => "success",
            "jobStatus" => "error",
            "progress"  => 0,
            "errorMsg"  => $errMsg
        ));

    } else {
        // 仍在生成中
        $sqlU = "UPDATE HeyGenJob SET progress=? WHERE jobId=?";
        $sU   = $conn->prepare($sqlU);
        $sU->bind_param("is", $progress, $jobId);
        $sU->execute();
        $sU->close();

        echo json_encode(array(
            "status"    => "success",
            "jobStatus" => "processing",
            "progress"  => $progress
        ));
    }
}

// ================================================================
// 函數 3: App 完成後處理後，更新最終影片路徑
// App 調用: POST { action: complete_heygen_job, jobId, finalVideoPath }
// 此函數在 Flutter 完成水印+片尾+字幕+合併後調用
// ================================================================
function completeHeygenJob($conn, $data) {
    $jobId         = isset($data['jobId'])         ? trim($data['jobId'])         : '';
    $finalVideoPath = isset($data['finalVideoPath']) ? trim($data['finalVideoPath']) : '';
    $lId           = isset($data['lId'])           ? trim($data['lId'])           : '';

    if (empty($jobId)) {
        echo json_encode(array("status" => "error", "message" => "Missing jobId"));
        return;
    }

    // 標記任務完成（刪除記錄或保留作審計）
    // 這裡選擇保留記錄，只更新狀態
    $sqlU = "UPDATE HeyGenJob SET status='heygen_done', progress=100 WHERE jobId=?";
    $sU   = $conn->prepare($sqlU);
    $sU->bind_param("s", $jobId);
    $sU->execute();
    $sU->close();

    // 如果有 lId 和 finalVideoPath，同時更新 Lesson 的 video 欄位
    if (!empty($lId) && !empty($finalVideoPath)) {
        $sqlL = "UPDATE Lesson SET video=?, uploadDateTime=NOW() WHERE lId=?";
        $sL   = $conn->prepare($sqlL);
        $sL->bind_param("ss", $finalVideoPath, $lId);
        $sL->execute();
        $sL->close();
    }

    echo json_encode(array("status" => "success", "message" => "Job marked as complete"));
}

// ================================================================
// HeyGen API 內部輔助函數
// ================================================================

function _heygenUploadAudio($apiKey, $audioUrl) {
    // HeyGen Upload Asset API（支持直接上傳 S3 Public URL 或本地二進制）
    // 如果你的 S3 檔案是私有的，需要先生成 presigned URL 再傳給 HeyGen
    $payload = json_encode(array('url' => $audioUrl, 'type' => 'audio'));
    $ch = curl_init('https://upload.heygen.com/v1/asset');
    curl_setopt_array($ch, array(
        CURLOPT_POST           => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 60,
        CURLOPT_HTTPHEADER     => array(
            'X-Api-Key: ' . $apiKey,
            'Content-Type: application/json',
            'Content-Length: ' . strlen($payload)
        ),
        CURLOPT_POSTFIELDS => $payload
    ));
    $resp     = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if (!$resp || $httpCode !== 200) return null;
    return json_decode($resp, true);
}

function _heygenCreateVideo($apiKey, $avatarId, $audioAssetId) {
    $payload = json_encode(array(
        'video_inputs' => array(array(
            'character' => array(
                'type'         => 'avatar',
                'avatar_id'    => $avatarId,
                'avatar_style' => 'normal'
            ),
            'voice' => array(
                'type'           => 'audio',
                'audio_asset_id' => $audioAssetId
            )
        )),
        'dimension' => array('width' => 1280, 'height' => 720),
        'test'      => false
    ));
    $ch = curl_init('https://api.heygen.com/v2/video/generate');
    curl_setopt_array($ch, array(
        CURLOPT_POST           => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 30,
        CURLOPT_HTTPHEADER     => array(
            'X-Api-Key: ' . $apiKey,
            'Content-Type: application/json',
            'Content-Length: ' . strlen($payload)
        ),
        CURLOPT_POSTFIELDS => $payload
    ));
    $resp     = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if (!$resp || $httpCode !== 200) return null;
    return json_decode($resp, true);
}

function _heygenGetStatus($apiKey, $videoId) {
    $ch = curl_init('https://api.heygen.com/v1/video_status.get?video_id=' . urlencode($videoId));
    curl_setopt_array($ch, array(
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_HTTPHEADER     => array(
            'X-Api-Key: ' . $apiKey,
            'Accept: application/json'
        )
    ));
    $resp     = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if (!$resp || $httpCode !== 200) return null;
    return json_decode($resp, true);
}


// 關閉連接
$conn->close();
