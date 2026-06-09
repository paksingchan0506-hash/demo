-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- 主機： localhost
-- 生成日期： 2025-09-09 05:49:39
-- 服務器版本： 10.5.29-MariaDB
-- PHP 版本： 8.4.10

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- 数据库： `anonymousEduTest`
--

-- --------------------------------------------------------

--
-- 表的结构 `AdminRole`
--

CREATE TABLE `AdminRole` (
  `roleId` varchar(10) NOT NULL COMMENT '角色ID',
  `roleName` varchar(50) NOT NULL COMMENT '角色名稱',
  `description` varchar(200) DEFAULT NULL COMMENT '角色描述',
  `is_active` tinyint(1) NOT NULL DEFAULT 1 COMMENT '是否激活',
  `createDate` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- --------------------------------------------------------

--
-- 表的结构 `AdminPermission`
--


CREATE TABLE `AdminPermission` (
  `permissionId` varchar(10) NOT NULL COMMENT '權限ID',
  `permissionName` varchar(50) NOT NULL COMMENT '權限名稱',
  `description` varchar(200) DEFAULT NULL COMMENT '權限描述',
  `is_active` tinyint(1) NOT NULL DEFAULT 1 COMMENT '是否激活'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- --------------------------------------------------------

--
-- 表的结构 `AdminRolePermission`
--


CREATE TABLE `AdminRolePermission` (
  `roleId` varchar(10) NOT NULL COMMENT '角色ID',
  `permissionId` varchar(10) NOT NULL COMMENT '權限ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- --------------------------------------------------------

--
-- 表的结构 `Admin`
--


CREATE TABLE `Admin` (
  `adminID` varchar(10) NOT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(100) NOT NULL,
  `email` varchar(50) NULL,
  `tel` int(8) DEFAULT NULL,
  `langId` varchar(10) NOT NULL COMMENT '語言ID',
  `roleId` varchar(10) NOT NULL COMMENT '角色ID',
  `createDate` datetime NOT NULL DEFAULT current_timestamp(),
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0=未刪除, 1=已刪除'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `AdminRole`
--

INSERT INTO `AdminRole` (`roleId`, `roleName`, `description`) VALUES
('RL000001', '超級管理員', '擁有所有權限'),
('RL000002', '內容管理員', '管理課程和內容'),
('RL000003', '用戶管理員', '管理用戶和會員');

--
-- 转存表中的数据 `AdminPermission`
--

INSERT INTO `AdminPermission` (`permissionId`, `permissionName`, `description`) VALUES
('PM000001', '管理管理員', '查看和管理管理員'),
('PM000002', '管理用戶', '查看和管理用戶'),
('PM000003', '管理文件', '查看和管理文件'),
('PM000004', '管理課程', '查看和管理課程'),
('PM000005', '管理舉報', '查看和處理用戶舉報'),
('PM000006', '管理留言', '查看和管理用戶留言');

--
-- 转存表中的数据 `AdminRolePermission`
--

INSERT INTO `AdminRolePermission` (`roleId`, `permissionId`) VALUES
('RL000001', 'PM000001'),
('RL000001', 'PM000002'),
('RL000001', 'PM000003'),
('RL000001', 'PM000004'),
('RL000001', 'PM000005'),
('RL000001', 'PM000006'),
('RL000002', 'PM000002'),
('RL000003', 'PM000003'),
('RL000003', 'PM000005');

--
-- 转存表中的数据 `Admin`
--

INSERT INTO `Admin` (`adminID`, `username`, `password`, `email`, `tel`, `langId`, `roleId`, `createDate`, `is_deleted`) VALUES
('AD000001', 'admin', 'adminedu', 'admin@example.com', 12345678, 'Lg000002', 'RL000001', '2025-08-04 11:16:10', 0),
('AD000002', 'admin2', 'adminedu', 'teacher@example.com', 87654321, 'Lg000001', 'RL000002', '2025-08-05 10:30:00', 0);

-- --------------------------------------------------------

--
-- 表的结构 `Language`
--

CREATE TABLE `Language` (
  `langId` varchar(10) NOT NULL COMMENT 'Lg000001-Lg999999',
  `language` varchar(50) NOT NULL COMMENT 'ENG，繁，簡'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `Language`
--

INSERT INTO `Language` (`langId`, `language`) VALUES
('Lg000001', 'English'),
('Lg000002', 'Traditional Chinese'),
('Lg000003', 'Simplified Chinese');

-- --------------------------------------------------------

--
-- 表的结构 `Category`
--

CREATE TABLE `Category` (
  `cateId` varchar(10) NOT NULL COMMENT 'Cy000001- Cy999999',
  `cateNameTC` varchar(40) NOT NULL COMMENT '科目繁體中文名',
  `cateNameSC` varchar(40) NOT NULL COMMENT '科目簡體中文名',
  `cateNameE` varchar(40) NOT NULL COMMENT '科目英文名'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `Category`
--

INSERT INTO `Category` (`cateId`, `cateNameTC`, `cateNameSC`, `cateNameE`) VALUES
('Cy000001', '語言學習', '語言學習', 'LANGUAGE'),
('Cy000002', '科學教育', '科學教育', 'SCIENCE'),
('Cy000003', '藝術文化', '藝術文化', 'ART'),
('Cy000004', '技術技能', '技術技能', 'TECH');

-- --------------------------------------------------------

--
-- 表的结构 `Member`
--

CREATE TABLE `Member` (
  `mId` varchar(10) NOT NULL COMMENT 'M0000001-M9999999',
  `username` varchar(50) NOT NULL COMMENT '用戶名',
  `mType` varchar(1) NOT NULL COMMENT 'S-學生, T-教師',
  `password` varchar(24) NOT NULL COMMENT '密碼',
  `email` varchar(50) NOT NULL COMMENT '郵箱',
  `tel` int(8) DEFAULT NULL COMMENT '電話號碼',
  `regDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '註冊時間',
  `loginMethod` varchar(10) NOT NULL DEFAULT 'SYSTEM' COMMENT '登錄方式',
  `langId` varchar(10) NOT NULL COMMENT '語言ID',
  `selfIntro` text DEFAULT NULL COMMENT '導師自我介紹',
  `selfIntroVideo` text DEFAULT NULL COMMENT '導師自我介紹影片',
  `gender` varchar(10) DEFAULT NULL COMMENT '性別',
  `avgRating` double(3,2) DEFAULT 0.00 COMMENT '導師平均評分',
  `stBookCount` int(11) DEFAULT 0 COMMENT '學生收藏次數',
  `tBookCount` int(11) DEFAULT 0 COMMENT '老師被收藏次數',
  `stCourseBookCount` int(11) DEFAULT 0 COMMENT '學生收藏課程次數',
  `teacherLevel` int(1) DEFAULT NULL COMMENT '導師等級 1-5',
  `avatar` varchar(200) DEFAULT NULL COMMENT '頭像',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0=未刪除, 1=已刪除'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `Member`
--

INSERT INTO `Member` (`mId`, `username`, `mType`, `password`, `email`, `tel`, `regDate`, `loginMethod`, `langId`, `selfIntro`, `selfIntroVideo`, `gender`, `avgRating`, `stBookCount`, `tBookCount`, `stCourseBookCount`, `teacherLevel`, `avatar`, `is_deleted`) VALUES
('M0000001', 'chow taiman', 'S', '99123', 'example@gmail.com', 91234567, '2025-08-01 10:00:00', 'SYSTEM', 'Lg000002', NULL, NULL, 'M', 0.00, 1, 0, 1, NULL, 'avatar001.jpg', 0),
('M0000002', 'chan siuman', 'T', 'abcwww', 'example@gmail.com', 98765432, '2025-08-02 11:30:00', 'SYSTEM', 'Lg000002', 'I am an experienced art teacher passionate about creativity.', 'wew.mp4', 'F', 4.50, 0, 10, 0, 3, 'avatar002.jpg', 0),
('M0000003', 'john doe', 'S', 'password123', 'john.doe@example.com', 12345678, '2025-08-03 09:15:00', 'SYSTEM', 'Lg000001', NULL, NULL, 'M', 0.00, 0, 0, 0, NULL, 'avatar003.jpg', 0),
('M0000004', 'chen maria', 'T', 'maria456', 'maria.chen@example.com', 87654321, '2025-08-04 14:20:00', 'SYSTEM', 'Lg000003', 'Specialized in languages and science education.', 'maria.mp4', 'F', 4.80, 0, 15, 0, 5, 'avatar004.jpg', 0);

-- --------------------------------------------------------

--
-- 表的结构 `MemberRelation`
--

CREATE TABLE `MemberRelation` (
  `studentId` varchar(10) NOT NULL COMMENT '學生ID',
  `teacherId` varchar(10) DEFAULT NULL COMMENT '老師ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
--
-- 转存表中的数据 `MemberRelation`
--
INSERT INTO `MemberRelation` (`studentId`, `teacherId`) VALUES
('M0000001', 'M0000002'),
('M0000003', 'M0000004');

-- --------------------------------------------------------

--
-- 表的结构 `Course`
--

CREATE TABLE `Course` (
  `cId` varchar(10) NOT NULL COMMENT 'C0000001-C9999999',
  `cName` varchar(50) NOT NULL COMMENT '課程名稱',
  `unitPrice` double(6,2) NOT NULL COMMENT '單價',
  `discount` int(3) NOT NULL DEFAULT 100 COMMENT '折扣百分比',
  `summary` varchar(200) NOT NULL COMMENT '課程概要',
  `totalLesson` int(10) NOT NULL COMMENT '總課堂',
  `cateId` varchar(10) NOT NULL COMMENT '分類ID',
  `mId` varchar(10) NOT NULL COMMENT '教師ID',
  `langId` varchar(10) NOT NULL COMMENT '語言ID',
  `avgRating` double(3,2) DEFAULT 0.00 COMMENT '課程平均評分',
  `bookmarkCount` int(11) DEFAULT 0 COMMENT '被收藏次數',
  `introImg` varchar(200) DEFAULT NULL COMMENT '課程介紹圖片',
  `introVideo` varchar(200) DEFAULT NULL COMMENT '課程介紹視頻',
  `purchasedCount` int(11) DEFAULT 0 COMMENT '已購買人數',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0=未刪除, 1=已刪除'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `Course`
--

INSERT INTO `Course` (`cId`, `cName`, `unitPrice`, `discount`, `summary`, `totalLesson`, `cateId`, `mId`, `langId`, `avgRating`, `bookmarkCount`, `introImg`, `introVideo`, `purchasedCount`, `is_deleted`) VALUES
('C0000001', '教你廣東話', 100.00, 100, '入門級廣東話課程', 10, 'Cy000001', 'M0000002', 'Lg000002', 4.50, 5, 'course001.jpg', 'course001.mp4', 20, 0),
('C0000002', 'How to write Traditional Chinese?', 80.00, 100, 'Learn Traditional Chinese characters', 8, 'Cy000001', 'M0000004', 'Lg000003', 0.00, 0, 'course002.jpg', 'course002.mp4', 5, 0),
('C0000003', '基礎科學實驗', 120.00, 100, '有趣的科學實驗課程', 12, 'Cy000002', 'M0000004', 'Lg000003', 0.00, 2, 'course003.jpg', 'course003.mp4', 8, 0),
('C0000004', 'Introduction to Programming', 150.00, 100, 'Python programming basics', 15, 'Cy000004', 'M0000002', 'Lg000001', 4.00, 8, 'course004.jpg', 'course004.mp4', 15, 0);

-- --------------------------------------------------------

--
-- 表的结构 `CourseSearch`
--

CREATE TABLE `CourseSearch` (
  `cId` varchar(10) NOT NULL COMMENT '課程ID',
  `searchCount` int(11) NOT NULL DEFAULT 0 COMMENT '搜尋次數'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `CourseSearch`
--

INSERT INTO `CourseSearch` (`cId`, `searchCount`) VALUES
('C0000001', 0),
('C0000002', 0),
('C0000003', 0),
('C0000004', 0);

-- --------------------------------------------------------

--
-- 表的结构 `Lesson`
--

CREATE TABLE `Lesson` (
  `lId` varchar(10) NOT NULL COMMENT 'L0000001-L9999999',
  `lName` varchar(50) NOT NULL COMMENT '課時名稱',
  `orderNum` int(3) NOT NULL COMMENT '課時順序',
  `uploadDateTime` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '上傳時間',
  `video` varchar(200) DEFAULT NULL COMMENT '視頻文件名',
  `duration` int(5) NOT NULL COMMENT '課時時長(分鐘)',
  `status` varchar(15) NOT NULL COMMENT '狀態：PENDING, PROCESSING, COMPLETED',
  `price` double(6,2) DEFAULT NULL COMMENT '課時價格',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0=未刪除, 1=已刪除',
  `cId` varchar(10) NOT NULL COMMENT '課程ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `Lesson`
--

INSERT INTO `Lesson` (`lId`, `lName`, `orderNum`, `uploadDateTime`, `video`, `duration`, `status`, `price`, `is_deleted`, `cId`) VALUES
('L0000001', 'Your first TC Lesson 1', 1, '2025-08-04 08:00:00', 'lesson1.mp4', 45, 'COMPLETED', 10.00, 0, 'C0000001'),
('L0000002', 'Your first TC Lesson 2', 2, '2025-08-04 08:30:00', 'lesson2.mp4', 50, 'COMPLETED', 10.00, 0, 'C0000001'),
('L0000003', 'Your first TC Lesson 1', 1, '2025-08-05 09:00:00', 'lesson3.mp4', 40, 'COMPLETED', 8.00, 0, 'C0000002'),
('L0000004', 'Your first TC Lesson 2', 2, '2025-08-05 09:30:00', 'lesson4.mp4', 45, 'COMPLETED', 8.00, 0, 'C0000002'),
('L0000005', 'Python Basics', 1, '2025-08-07 11:00:00', 'lesson5.mp4', 60, 'COMPLETED', 15.00, 0, 'C0000004'),
('L0000006', 'Variables and Data Types', 2, '2025-08-07 11:30:00', 'lesson6.mp4', 55, 'COMPLETED', 15.00, 0, 'C0000004');

-- --------------------------------------------------------

--
-- 表的结构 `LessonResource`
--

CREATE TABLE `LessonResource` (
  `lrId` varchar(10) NOT NULL COMMENT 'Lr000001-Lr999999',
  `lrName` varchar(100) NOT NULL COMMENT '資源名稱',
  `resourceType` varchar(10) NOT NULL COMMENT 'URL或FILE',
  `path` varchar(200) NOT NULL COMMENT '資源路徑',
  `modifiedDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '修改時間',
  `lId` varchar(10) NOT NULL COMMENT '課時ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `LessonResource`
--

INSERT INTO `LessonResource` (`lrId`, `lrName`, `resourceType`, `path`, `modifiedDate`, `lId`) VALUES
('Lr000001', '第一課教材', 'FILE', 'uploads/2025/08/lesson1_materials.pdf', '2025-08-04 08:00:00', 'L0000001'),
('Lr000002', '發音練習音頻', 'FILE', 'uploads/2025/08/pronunciation_drills.mp3', '2025-08-04 08:05:00', 'L0000001'),
('Lr000003', '數字練習工作表', 'FILE', 'uploads/2025/08/numbers_worksheet.pdf', '2025-08-04 08:30:00', 'L0000002'),
('Lr000004', '谷歌翻譯工具', 'URL', 'https://translate.google.com/', '2025-08-04 08:35:00', 'L0000002'),
('Lr000005', '繁體中文基礎視頻', 'FILE', 'uploads/2025/08/traditional_chinese_basics.mp4', '2025-08-05 09:00:00', 'L0000003'),
('Lr000006', '中文書寫練習網站', 'URL', 'https://www.example.com/chinese-writing-practice', '2025-08-05 09:30:00', 'L0000004'),
('Lr000007', 'Python安裝指南', 'FILE', 'uploads/2025/08/python_install_guide.pdf', '2025-08-07 11:00:00', 'L0000005'),
('Lr000008', 'Hello World示例代碼', 'FILE', 'uploads/2025/08/hello_world.py', '2025-08-07 11:10:00', 'L0000005');

-- --------------------------------------------------------

--
-- 表的结构 `MemberCourse`
--

CREATE TABLE `MemberCourse` (
  `mcId` varchar(10) NOT NULL COMMENT 'mc000001-mc999999',
  `mId` varchar(10) NOT NULL COMMENT '會員ID',
  `cId` varchar(10) NOT NULL COMMENT '課程ID',
  `rating` int(1) DEFAULT NULL COMMENT '評分',
  `comment` varchar(500) DEFAULT NULL COMMENT '課程評論',
  `result` double(3,2) DEFAULT NULL COMMENT '學生的課程分數',
  `PurchaseDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '購買時間'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `MemberCourse`
--

INSERT INTO `MemberCourse` (`mcId`, `mId`, `cId`, `rating`, `comment`, `result`, `PurchaseDate`) VALUES
('mc000001', 'M0000001', 'C0000001', 5, '非常實用的課程，老師講得很清楚！', 7.00, '2025-08-10 09:00:00'),
('mc000002', 'M0000001', 'C0000002', NULL, NULL, NULL, '2025-08-27 06:16:01'),
('mc000003', 'M0000003', 'C0000004', 4, 'Good introduction to Python.', 7.00, '2025-08-15 14:30:00'),
('mc000004', 'M0000003', 'C0000001', NULL, NULL, NULL, '2025-08-20 10:00:00');

-- --------------------------------------------------------

--
-- 表的结构 `MemberLesson`
--

CREATE TABLE `MemberLesson` (
  `mlId` varchar(10) NOT NULL COMMENT 'ml000001-ml999999',
  `mId` varchar(10) NOT NULL COMMENT '會員ID',
  `lId` varchar(10) NOT NULL COMMENT '課時ID',
  `firstLesson` timestamp NULL DEFAULT NULL COMMENT '首次學習時間',
  `rating` int(1) DEFAULT NULL COMMENT '評分'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `MemberLesson`
--

INSERT INTO `MemberLesson` (`mlId`, `mId`, `lId`, `firstLesson`, `rating`) VALUES
('ml000001', 'M0000001', 'L0000001', '2025-08-27 06:48:38', 5),
('ml000002', 'M0000001', 'L0000002', NULL, NULL),
('ml000003', 'M0000001', 'L0000003', '2025-08-28 09:00:00', 4),
('ml000004', 'M0000003', 'L0000005', '2025-08-16 10:00:00', 3);

-- --------------------------------------------------------

--
-- 表的结构 `History`
--

CREATE TABLE `History` (
  `hId` varchar(10) NOT NULL COMMENT 'h0000001-h9999999',
  `history` varchar(200) NOT NULL COMMENT '搜索記錄',
  `regDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '記錄時間',
  `mId` varchar(10) NOT NULL COMMENT '會員ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `History`
--

INSERT INTO `History` (`hId`, `history`, `regDate`, `mId`) VALUES
('h0000001', '完成了課程C0000001的第一課L0000001', '2025-08-27 06:48:38', 'M0000001'),
('h0000002', '註冊了課程C0000002', '2025-08-27 06:16:01', 'M0000001'),
('h0000003', '註冊了課程C0000004', '2025-08-15 14:30:00', 'M0000003'),
('h0000004', '訪問了課程資源Lr000007', '2025-08-16 09:20:00', 'M0000003');

-- --------------------------------------------------------

--
-- 表的结构 `ACoinTransType`
--

CREATE TABLE `ACoinTransType` (
  `actTypeId` varchar(10) NOT NULL COMMENT 'att001- att999',
  `description` varchar(200) NOT NULL COMMENT '來源描述',
  `defaultValue` double(6,2) NOT NULL COMMENT '默認獲取數量',
  `conId` varchar(10) DEFAULT NULL COMMENT '轉換ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `ACoinTransType`
--

INSERT INTO `ACoinTransType` (`actTypeId`, `description`, `defaultValue`, `conId`) VALUES
('att001', '推廣套餐A', -1200.00, NULL),
('att002', '推廣套餐B', -900.00, NULL),
('att003', '推廣套餐C', -600.00, NULL),
('att004', '推廣套餐D', -300.00, NULL),
('att005', '註冊獎勵', 1000.00, NULL),
('att006', '登錄獎勵', 100.00, NULL),
('att007', 'A幣購買', 0.00, 'Cn000001'),
('att008', '課程購買', 0.00, NULL),
('att009', '遊戲獎勵', 0.00, NULL),
('att010', '遊戲消費', 0.00, NULL);

-- --------------------------------------------------------

--
-- 表的结构 `ACoinTransaction`
--

CREATE TABLE `ACoinTransaction` (
  `aId` varchar(10) NOT NULL COMMENT 'A0000001-A9999999',
  `transValue` double(6,2) NOT NULL COMMENT '交易金額(正負數)',
  `totalAmont` double(6,2) NOT NULL COMMENT '賬戶總A幣',
  `transDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '交易時間',
  `description` varchar(100) DEFAULT NULL COMMENT '變動原因',
  `mId` varchar(10) NOT NULL COMMENT '會員ID',
  `actTypeId` varchar(10) NOT NULL COMMENT '交易類型ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `ACoinTransaction`
--

INSERT INTO `ACoinTransaction` (`aId`, `transValue`, `totalAmont`, `transDate`, `description`, `mId`, `actTypeId`) VALUES
('A0000001', 1000.00, 1000.00, '2025-08-12 08:43:41', '註冊獎勵', 'M0000001', 'att005'),
('A0000002', -100.00, 900.00, '2025-08-12 08:43:49', '購買課程C0000001', 'M0000001', 'att008'),
('A0000003', 1000.00, 1000.00, '2025-08-15 14:25:00', '註冊獎勵', 'M0000003', 'att005'),
('A0000004', 100.00, 1100.00, '2025-08-16 09:00:00', '每日登錄獎勵', 'M0000003', 'att006'),
('A0000005', 5000.00, 5000.00, '2025-08-01 09:00:00', '註冊獎勵', 'M0000002', 'att005'),
('A0000006', -1200.00, 3800.00, '2025-08-01 10:00:00', '購買推廣套餐A', 'M0000002', 'att001'),
('A0000007', 5000.00, 5000.00, '2025-08-01 09:00:00', '註冊獎勵', 'M0000004', 'att005'),
('A0000008', -300.00, 4700.00, '2025-08-04 09:15:00', '購買推廣套餐D', 'M0000004', 'att004');


-- --------------------------------------------------------

--
-- 表的结构 `Conversion`
--

CREATE TABLE `Conversion` (
  `conId` varchar(10) NOT NULL COMMENT 'Cn000001-Cn999999',
  `price` double(6,2) NOT NULL COMMENT '價格(HKD)',
  `aCoin` double(6,2) NOT NULL COMMENT '可獲得A幣數量'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `Conversion`
--

INSERT INTO `Conversion` (`conId`, `price`, `aCoin`) VALUES
('Cn000001', 100.00, 1250.00),
('Cn000002', 50.00, 625.00),
('Cn000003', 200.00, 2500.00);

-- --------------------------------------------------------

--
-- 表的结构 `Payment`
--

CREATE TABLE `Payment` (
  `paymentId` varchar(10) NOT NULL COMMENT 'P0000001-P9999999',
  `receiptPath` varchar(200) NOT NULL COMMENT '收據檔案存放路徑',
  `paymentDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '付款時間',
  `mId` varchar(10) NOT NULL COMMENT '會員ID',
  `amount` decimal(10,2) NOT NULL COMMENT '付款金額',
  `paymentMethod` varchar(20) NOT NULL COMMENT '付款方式',
  `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT '付款狀態',
  `transactionRef` varchar(50) DEFAULT NULL COMMENT '交易參考號',
  `description` varchar(200) DEFAULT NULL COMMENT '付款描述',
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '建立時間',
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT '最後更新時間',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0=未刪除, 1=已刪除'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `Payment`
--

INSERT INTO `Payment` (`paymentId`, `receiptPath`, `paymentDate`, `mId`, `amount`, `paymentMethod`, `status`, `transactionRef`, `description`, `createdAt`, `updatedAt`, `is_deleted`) VALUES
('P0000001', 'uploads/receipts/P0000001.pdf', '2025-08-01 10:30:00', 'M0000001', 599.00, 'CREDIT_CARD', 'completed', 'TXN123456789', '課程報名費', '2025-08-01 10:30:00', '2025-08-01 10:30:00', 0),
('P0000002', 'uploads/receipts/P0000002.pdf', '2025-08-02 14:15:00', 'M0000002', 299.50, 'BANK_TRANSFER', 'completed', 'TXN987654321', '教學材料費用', '2025-08-02 14:15:00', '2025-08-02 14:15:00', 0),
('P0000003', 'uploads/receipts/P0000003.pdf', '2025-08-03 16:45:00', 'M0000003', 1299.00, 'CREDIT_CARD', 'completed', 'TXN456789123', '全年課程費用', '2025-08-03 16:45:00', '2025-08-03 16:45:00', 0),
('P0000004', 'uploads/receipts/P0000004.pdf', '2025-08-04 11:20:00', 'M0000004', 199.99, 'PAYPAL', 'pending', NULL, '月度訂閱費用', '2025-08-04 11:20:00', '2025-08-04 11:20:00', 0),
('P0000005', 'uploads/receipts/P0000005.pdf', '2025-08-05 09:10:00', 'M0000001', 89.90, 'BANK_TRANSFER', 'completed', 'TXN789123456', '額外教材費用', '2025-08-05 09:10:00', '2025-08-05 09:10:00', 0);

-- --------------------------------------------------------

--
-- 表的结构 `WithdrawalRequest`
--

CREATE TABLE `WithdrawalRequest` (
  `requestId` varchar(10) NOT NULL COMMENT 'WR0000001-WR9999999',
  `teacherId` varchar(10) NOT NULL COMMENT '教師ID',
  `amount` decimal(10,2) NOT NULL COMMENT '請求金額',
  `requestDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '請求時間',
  `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT '請求狀態',
  `requestReason` varchar(200) DEFAULT NULL COMMENT '請求原因',
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '建立時間',
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT '更新時間',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0=未刪除, 1=已刪除'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `WithdrawalRequest`
--

INSERT INTO `WithdrawalRequest` (`requestId`, `teacherId`, `amount`, `requestDate`, `status`, `requestReason`, `createdAt`, `updatedAt`, `is_deleted`) VALUES
('WR0000001', 'M0000002', 1500.00, '2025-08-10 10:00:00', 'pending', '月度課程收入提款', '2025-08-10 10:00:00', '2025-08-10 10:00:00', 0),
('WR0000002', 'M0000004', 3000.50, '2025-08-12 14:30:00', 'approved', '學期結束收入提款', '2025-08-12 14:30:00', '2025-08-12 16:00:00', 0),
('WR0000003', 'M0000002', 800.00, '2025-08-15 09:15:00', 'rejected', '緊急提款需求', '2025-08-15 09:15:00', '2025-08-15 11:30:00', 0);

-- --------------------------------------------------------

--
-- 表的结构 `ReportReason`
--

CREATE TABLE `ReportReason` (
  `reasonId` varchar(10) NOT NULL COMMENT 'RR0000001-RR9999999',
  `title` varchar(50) NOT NULL COMMENT '原因標題',
  `description` varchar(200) NOT NULL COMMENT '原因描述',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '是否啟用',
  `sortOrder` int(3) NOT NULL DEFAULT 0 COMMENT '排序順序',
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '創建時間',
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT '更新時間',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0=未刪除, 1=已刪除'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `ReportReason`
--

INSERT INTO `ReportReason` (`reasonId`, `title`, `description`, `isActive`, `sortOrder`, `createdAt`, `updatedAt`, `is_deleted`) VALUES
('RR0000001', '語言不當', '使用不當言語或冒犯性語言', 1, 1, '2025-08-01 00:00:00', '2025-08-01 00:00:00', 0),
('RR0000002', '內容抄襲', '盜用他人創作內容', 1, 2, '2025-08-01 00:00:00', '2025-08-01 00:00:00', 0),
('RR0000003', '課程品質問題', '課程內容品質不符合期望', 1, 3, '2025-08-01 00:00:00', '2025-08-01 00:00:00', 0),
('RR0000004', '收費問題', '收費不合理或欺詐行為', 1, 4, '2025-08-01 00:00:00', '2025-08-01 00:00:00', 0),
('RR0000005', '教學態度問題', '教學態度不專業或不友善', 1, 5, '2025-08-01 00:00:00', '2025-08-01 00:00:00', 0),
('RR0000006', '其他', '其他未列出的問題', 1, 6, '2025-08-01 00:00:00', '2025-08-01 00:00:00', 0);


-- --------------------------------------------------------

--
-- 表的结构 `MemberReport`
--

CREATE TABLE `MemberReport` (
  `reportId` varchar(10) NOT NULL COMMENT 'MR0000001-MR9999999',
  `reporterId` varchar(10) NOT NULL COMMENT '舉報人ID',
  `reportedId` varchar(10) NOT NULL COMMENT '被舉報人ID',
  `commentId` varchar(10) DEFAULT NULL COMMENT '被舉報的評論ID',
  `videoId` varchar(10) DEFAULT NULL COMMENT '被舉報的視頻ID',
  `reasonId` varchar(10) NOT NULL COMMENT '舉報原因ID',
  `customReason` varchar(200) DEFAULT NULL COMMENT '自定義原因',
  `reportType` varchar(20) NOT NULL COMMENT '舉報類型',
  `description` varchar(500) NOT NULL COMMENT '舉報詳細描述',
  `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT '舉報狀態',
  `handledBy` varchar(10) DEFAULT NULL COMMENT '處理人ID',
  `handledAt` timestamp NULL DEFAULT NULL COMMENT '處理時間',
  `result` varchar(200) DEFAULT NULL COMMENT '處理結果',
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '創建時間',
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT '更新時間',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0=未刪除, 1=已刪除'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `MemberReport`
--

INSERT INTO `MemberReport` (`reportId`, `reporterId`, `reportedId`, `commentId`, `videoId`, `reasonId`, `customReason`, `reportType`, `description`, `status`, `handledBy`, `handledAt`, `result`, `createdAt`, `updatedAt`, `is_deleted`) VALUES
('MR0000001', 'M0000001', 'M0000002', NULL, 'L0000001', 'RR0000001', NULL, 'teacher', '老師在上課時使用了不當言辭，讓我感到不舒服。', 'reviewed', 'AD000001', '2025-08-15 14:30:00', '已警告該教師，要求改進教學態度', '2025-08-14 10:00:00', '2025-08-15 14:30:00', 0),
('MR0000002', 'M0000003', 'M0000002', NULL, NULL, 'RR0000005', NULL, 'teacher', '老師經常遲到，教學態度不專業。', 'pending', NULL, NULL, NULL, '2025-08-16 09:15:00', '2025-08-16 09:15:00', 0),
('MR0000003', 'M0000001', 'M0000004', NULL, NULL, 'RR0000006', '老師要求額外付費但沒有在課程說明中提到', 'teacher', '老師要求額外付費才願意提供完整課程內容，這種行為不合理。', 'resolved', 'AD000001', '2025-08-17 11:00:00', '已退款並對教師進行處罰', '2025-08-16 16:45:00', '2025-08-17 11:00:00', 0);

-- --------------------------------------------------------

--
-- 表的结构 `WithdrawalApproval`
--

CREATE TABLE `WithdrawalApproval` (
  `approvalId` varchar(10) NOT NULL COMMENT 'WA0000001-WA9999999',
  `requestId` varchar(10) NOT NULL COMMENT '關聯的請求ID',
  `processedBy` varchar(10) NOT NULL COMMENT '處理人員ID',
  `status` varchar(20) NOT NULL COMMENT '處理狀態',
  `approvedAmount` decimal(10,2) NOT NULL COMMENT '批准金額',
  `fee` decimal(10,2) NOT NULL DEFAULT 0.00 COMMENT '手續費',
  `netAmount` decimal(10,2) NOT NULL COMMENT '實際支付金額',
  `paymentMethod` varchar(20) NOT NULL COMMENT '付款方式',
  `accountInfo` varchar(200) NOT NULL COMMENT '收款帳戶資訊',
  `invoicePath` varchar(200) DEFAULT NULL COMMENT '發票上傳路徑',
  `rejectionReason` varchar(200) DEFAULT NULL COMMENT '拒絕原因',
  `processedDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '處理時間',
  `createdAt` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '建立時間',
  `updatedAt` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT '更新時間',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0=未刪除, 1=已刪除'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `WithdrawalApproval`
--

INSERT INTO `WithdrawalApproval` (`approvalId`, `requestId`, `processedBy`, `status`, `approvedAmount`, `fee`, `netAmount`, `paymentMethod`, `accountInfo`, `invoicePath`, `rejectionReason`, `processedDate`, `createdAt`, `updatedAt`, `is_deleted`) VALUES
('WA0000001', 'WR0000002', 'AD000001', 'approved', 3000.00, 15.00, 2985.00, 'BANK_TRANSFER', '匯豐銀行 123-456-789012', 'uploads/invoices/WA0000001.pdf', NULL, '2025-08-12 16:00:00', '2025-08-12 16:00:00', '2025-08-12 16:00:00', 0),
('WA0000002', 'WR0000003', 'AD000001', 'rejected', 0.00, 0.00, 0.00, NULL, NULL, NULL, '不符合提款條件', '2025-08-15 11:30:00', '2025-08-15 11:30:00', '2025-08-15 11:30:00', 0);

-- --------------------------------------------------------

--
-- 表的结构 `Reward`
--

CREATE TABLE `Reward` (
  `RewardID` varchar(10) NOT NULL,
  `RewardName` varchar(100) NOT NULL,
  `RewardDescription` varchar(200) NOT NULL,
  `RewardValue` double(6,2) NOT NULL,
  `RewardType` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `Reward`
--

INSERT INTO `Reward` (`RewardID`, `RewardName`, `RewardDescription`, `RewardValue`, `RewardType`) VALUES
('R0000001', 'Give me five', '完成5個課時的獎勵', 5.00, 'LESSON_COMPLETION'),
('R0000002', '100%', '完成整個課程的獎勵', 100.00, 'COURSE_COMPLETION'),
('R0000003', 'Early Bird', '提前完成課時的額外獎勵', 20.00, 'BONUS'),
('R0000004', 'Social Butterfly', '邀請好友註冊的獎勵', 50.00, 'REFERRAL');

-- --------------------------------------------------------

--
-- 表的结构 `Chatroom`
--

CREATE TABLE `Chatroom` (
  `crId` varchar(10) NOT NULL COMMENT '聊天室ID',
  `createGroupDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '創建日期和時間',
  `mId` varchar(10) NOT NULL COMMENT '聊天室管理員ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `Chatroom`
--

INSERT INTO `Chatroom` (`crId`, `mId`) VALUES
('CR000001', 'M0000001'),
('CR000002', 'M0000002'),
('CR000003', 'M0000003'),
('CR000004', 'M0000004');

-- --------------------------------------------------------

--
-- 表的结构 `ChatroomMSG`
--

CREATE TABLE `ChatroomMSG` (
  `msgId` varchar(12) NOT NULL COMMENT '消息ID',
  `msg` varchar(200) NOT NULL COMMENT '消息內容',
  `msgSend` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '消息發送時間',
  `mId` varchar(10) NOT NULL COMMENT '聊天室成員ID',
  `crId` varchar(10) NOT NULL COMMENT '聊天室ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `ChatroomMSG`
--

INSERT INTO `ChatroomMSG` (`msgId`, `msg`, `mId`, `crId`) VALUES
('MSG000000001', '大家好！歡迎來到聊天室。', 'M0000001', 'CR000001'),
('MSG000000002', '請問有什麼可以幫助的？', 'M0000002', 'CR000001'),
('MSG000000003', '我想了解更多關於課程的信息。', 'M0000003', 'CR000002'),
('MSG000000004', '這個平台的使用體驗真不錯！', 'M0000004', 'CR000003');

-- --------------------------------------------------------

--
-- 表的结构 `MemberReward`
--

CREATE TABLE `MemberReward` (
  `rId` varchar(10) NOT NULL,
  `price` double(6,2) NOT NULL,
  `picture` varchar(200) NOT NULL,
  `title` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `MemberReward`
--

INSERT INTO `MemberReward` (`rId`, `price`, `picture`, `title`) VALUES
('MR000001', 100.00, 'reward001.jpg', '完成整個課程的獎勵'),
('MR000002', 5.00, 'reward002.jpg', '完成5個課時的獎勵');

-- --------------------------------------------------------

--
-- 表的结构 `TutorSubject`
--

CREATE TABLE `TutorSubject` (
  `tsId` varchar(10) NOT NULL COMMENT 'TS000001-TS999999',
  `tutorId` varchar(10) NOT NULL COMMENT '導師ID',
  `cateId` varchar(10) NOT NULL COMMENT '科目ID'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `TutorSubject`
--

INSERT INTO `TutorSubject` (`tsId`, `tutorId`, `cateId`) VALUES
('TS000001', 'M0000002', 'Cy000001'),
('TS000002', 'M0000002', 'Cy000004'),
('TS000003', 'M0000004', 'Cy000001'),
('TS000004', 'M0000004', 'Cy000002');

-- --------------------------------------------------------

--
-- 表的结构 `TutorBookmark`
--

CREATE TABLE `TutorBookmark` (
  `tbId` varchar(10) NOT NULL COMMENT 'TB000001-TB999999',
  `mId` varchar(10) NOT NULL COMMENT '會員ID',
  `tutorId` varchar(10) NOT NULL COMMENT '導師ID',
  `createDate` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `TutorBookmark`
--

INSERT INTO `TutorBookmark` (`tbId`, `mId`, `tutorId`, `createDate`) VALUES
('TB000001', 'M0000001', 'M0000002', '2025-08-10 10:00:00'),
('TB000002', 'M0000003', 'M0000004', '2025-08-15 15:00:00');

-- --------------------------------------------------------

--
-- 表的结构 `CourseBookmark`
--

CREATE TABLE `CourseBookmark` (
  `cbId` varchar(10) NOT NULL COMMENT 'CB000001-CB999999',
  `mId` varchar(10) NOT NULL COMMENT '會員ID',
  `cId` varchar(10) NOT NULL COMMENT '課程ID',
  `createDate` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `CourseBookmark`
--

INSERT INTO `CourseBookmark` (`cbId`, `mId`, `cId`, `createDate`) VALUES
('CB000001', 'M0000001', 'C0000004', '2025-08-11 09:30:00');

-- --------------------------------------------------------

--
-- 表的结构 `TutorReview`
--

CREATE TABLE `TutorReview` (
  `trId` varchar(10) NOT NULL COMMENT 'TR000001-TR999999',
  `mId` varchar(10) NOT NULL COMMENT '評論者ID',
  `cId` varchar(10) NOT NULL COMMENT '課程ID',
  `comment` varchar(500) DEFAULT NULL COMMENT '評論',
  `createDate` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `TutorReview`
--

INSERT INTO `TutorReview` (`trId`, `mId`, `cId`, `comment`, `createDate`) VALUES
('TR000001', 'M0000001', 'C0000001', '老師很有耐心，解答問題很詳細。', '2025-08-12 14:00:00'),
('TR000002', 'M0000003', 'C0000004', 'Very clear explanations and good examples.', '2025-08-18 10:20:00');

-- --------------------------------------------------------

--
-- 表的结构 `Message`
--

CREATE TABLE `Message` (
  `messageId` varchar(10) NOT NULL COMMENT '消息ID',
  `senderId` varchar(10) NOT NULL COMMENT '發送者ID (Admin或系統)',
  `recipientId` varchar(10) DEFAULT NULL COMMENT '接收者ID (null表示發送給所有成員)',
  `title` varchar(100) NOT NULL COMMENT '消息標題',
  `content` text NOT NULL COMMENT '消息內容',
  `messageType` varchar(20) NOT NULL COMMENT '消息類型 (SYSTEM, BROADCAST, PERSONAL)',
  `sendDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '發送時間',
  `isRead` tinyint(1) NOT NULL DEFAULT 0 COMMENT '是否已讀',
  `readDate` timestamp NULL DEFAULT NULL COMMENT '閱讀時間',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0=未刪除, 1=已刪除'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `Message`
--

INSERT INTO `Message` (`messageId`, `senderId`, `recipientId`, `title`, `content`, `messageType`, `sendDate`, `isRead`, `readDate`, `is_deleted`) VALUES
('MSG000001', 'AD000001', NULL, '系統公告', '歡迎使用我們的教育平台，我們將持續更新優質課程！', 'BROADCAST', '2025-08-01 00:00:00', 0, NULL, 0),
('MSG000002', 'AD000001', 'M0000001', '個人消息', '您的課程《教你廣東話》已成功購買', 'PERSONAL', '2025-08-10 09:00:00', 0, NULL, 0),
('MSG000003', 'AD000001', NULL, '課程更新', '新課程《Python高級編程》已上線，歡迎報名！', 'BROADCAST', '2025-08-15 10:00:00', 0, NULL, 0);

-- --------------------------------------------------------

--
-- 表的结构 `test`
--

CREATE TABLE `test` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `test`
--

INSERT INTO `test` (`id`, `name`) VALUES
(1, '單元測試1'),
(2, '單元測試2');

--
-- 转储表的索引
--

--
-- 表的索引 `AdminRole`
--
ALTER TABLE `AdminRole`
  ADD PRIMARY KEY (`roleId`);

--
-- 表的索引 `AdminPermission`
--
ALTER TABLE `AdminPermission`
  ADD PRIMARY KEY (`permissionId`);

--
-- 表的索引 `AdminRolePermission`
--
ALTER TABLE `AdminRolePermission`
  ADD PRIMARY KEY (`roleId`,`permissionId`),
  ADD KEY `permissionId` (`permissionId`);

--
-- 表的索引 `MemberRelation`
--
ALTER TABLE `MemberRelation`
  ADD PRIMARY KEY (`studentId`,`teacherId`),
  ADD KEY `teacherId` (`teacherId`);

--
-- 表的索引 `Admin`
--
ALTER TABLE `Admin`
  ADD PRIMARY KEY (`adminID`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `langId` (`langId`),
  ADD KEY `roleId` (`roleId`);

--
-- 表的索引 `Language`
--
ALTER TABLE `Language`
  ADD PRIMARY KEY (`langId`);

--
-- 表的索引 `Category`
--
ALTER TABLE `Category`
  ADD PRIMARY KEY (`cateId`);

--
-- 表的索引 `Member`
--
ALTER TABLE `Member`
  ADD PRIMARY KEY (`mId`),
  ADD KEY `langId` (`langId`);

--
-- 表的索引 `Course`
--
ALTER TABLE `Course`
  ADD PRIMARY KEY (`cId`),
  ADD KEY `cateId` (`cateId`),
  ADD KEY `mId` (`mId`),
  ADD KEY `langId` (`langId`);

--
-- 表的索引 `CourseSearch`
--
ALTER TABLE `CourseSearch`
  ADD PRIMARY KEY (`cId`);

--
-- 表的索引 `Lesson`
--
ALTER TABLE `Lesson`
  ADD PRIMARY KEY (`lId`),
  ADD KEY `cId` (`cId`),
  ADD KEY `is_deleted` (`is_deleted`);

--
-- 表的索引 `LessonResource`
--
ALTER TABLE `LessonResource`
  ADD PRIMARY KEY (`lrId`),
  ADD KEY `lId` (`lId`);

--
-- 表的索引 `MemberCourse`
--
ALTER TABLE `MemberCourse`
  ADD PRIMARY KEY (`mcId`),
  ADD KEY `mId` (`mId`),
  ADD KEY `cId` (`cId`);

--
-- 表的索引 `MemberLesson`
--
ALTER TABLE `MemberLesson`
  ADD PRIMARY KEY (`mlId`),
  ADD KEY `mId` (`mId`),
  ADD KEY `lId` (`lId`);

--
-- 表的索引 `History`
--
ALTER TABLE `History`
  ADD PRIMARY KEY (`hId`),
  ADD KEY `mId` (`mId`);

--
-- 表的索引 `ACoinTransType`
--
ALTER TABLE `ACoinTransType`
  ADD PRIMARY KEY (`actTypeId`),
  ADD KEY `conId` (`conId`);

--
-- 表的索引 `ACoinTransaction`
--
ALTER TABLE `ACoinTransaction`
  ADD PRIMARY KEY (`aId`),
  ADD KEY `mId` (`mId`),
  ADD KEY `actTypeId` (`actTypeId`);

--
-- 表的索引 `Conversion`
--
ALTER TABLE `Conversion`
  ADD PRIMARY KEY (`conId`);

--
-- 表的索引 `Reward`
--
ALTER TABLE `Reward`
  ADD PRIMARY KEY (`RewardID`);

--
-- 表的索引 `Chatroom`
--
ALTER TABLE `Chatroom`
  ADD PRIMARY KEY (`crId`),
  ADD KEY `mId` (`mId`);

--
-- 表的索引 `ChatroomMSG`
--
ALTER TABLE `ChatroomMSG`
  ADD PRIMARY KEY (`msgId`),
  ADD KEY `mId` (`mId`),
  ADD KEY `crId` (`crId`);

--
-- 表的索引 `MemberReward`
--
ALTER TABLE `MemberReward`
  ADD PRIMARY KEY (`rId`),
  ADD KEY `rId` (`rId`);

--
-- 表的索引 `Message`
--
ALTER TABLE `Message`
  ADD PRIMARY KEY (`messageId`),
  ADD KEY `senderId` (`senderId`),
  ADD KEY `recipientId` (`recipientId`),
  ADD KEY `isRead` (`isRead`),
  ADD KEY `sendDate` (`sendDate`),
  ADD KEY `messageType` (`messageType`);
  
--
-- 表的索引 `Payment`
--
ALTER TABLE `Payment`
  ADD PRIMARY KEY (`paymentId`),
  ADD KEY `mId` (`mId`);

-- --------------------------------------------------------

--
-- 表的索引 `WithdrawalRequest`
--
ALTER TABLE `WithdrawalRequest`
  ADD PRIMARY KEY (`requestId`),
  ADD KEY `teacherId` (`teacherId`);

-- --------------------------------------------------------

--
-- 表的索引 `WithdrawalApproval`
--
ALTER TABLE `WithdrawalApproval`
  ADD PRIMARY KEY (`approvalId`),
  ADD KEY `requestId` (`requestId`),
  ADD KEY `processedBy` (`processedBy`);

-- --------------------------------------------------------

--
-- 表的索引 `ReportReason`
--
ALTER TABLE `ReportReason`
  ADD PRIMARY KEY (`reasonId`);

-- --------------------------------------------------------

--
-- 表的索引 `MemberReport`
--
ALTER TABLE `MemberReport`
  ADD PRIMARY KEY (`reportId`),
  ADD KEY `reporterId` (`reporterId`),
  ADD KEY `reportedId` (`reportedId`),
  ADD KEY `reasonId` (`reasonId`),
  ADD KEY `handledBy` (`handledBy`);

-- --------------------------------------------------------

--
-- 表的索引 `TutorSubject`
--
ALTER TABLE `TutorSubject`
  ADD PRIMARY KEY (`tsId`),
  ADD KEY `tutorId` (`tutorId`),
  ADD KEY `cateId` (`cateId`);

--
-- 表的索引 `TutorBookmark`
--
ALTER TABLE `TutorBookmark`
  ADD PRIMARY KEY (`tbId`),
  ADD KEY `mId` (`mId`),
  ADD KEY `tutorId` (`tutorId`);

--
-- 表的索引 `CourseBookmark`
--
ALTER TABLE `CourseBookmark`
  ADD PRIMARY KEY (`cbId`),
  ADD KEY `mId` (`mId`),
  ADD KEY `cId` (`cId`);

--
-- 表的索引 `TutorReview`
--
ALTER TABLE `TutorReview`
  ADD PRIMARY KEY (`trId`),
  ADD KEY `mId` (`mId`),
  ADD KEY `cId` (`cId`);

--
-- 表的索引 `test`
--
ALTER TABLE `test`
  ADD PRIMARY KEY (`id`);

--
-- 在导出的表使用AUTO_INCREMENT
--

--
-- 使用表AUTO_INCREMENT `test`
--
ALTER TABLE `test`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

-- --------------------------------------------------------

--
-- 表的结构 `HeyGenJob`
--

CREATE TABLE IF NOT EXISTS HeyGenJob ( 
     jobId         VARCHAR(20)   NOT NULL PRIMARY KEY, 
     mId           VARCHAR(10)   NOT NULL, 
     lId           VARCHAR(10)   DEFAULT NULL, 
     cId           VARCHAR(10)   DEFAULT NULL, 
     audioS3Url    TEXT          NOT NULL, 
     avatarId      VARCHAR(100)  NOT NULL, 
     heygenVideoId VARCHAR(100)  DEFAULT NULL, 
     status        ENUM('processing','heygen_done','error') DEFAULT 'processing', 
     progress      INT           DEFAULT 5, 
     resultVideoUrl TEXT         DEFAULT NULL, 
     errorMsg      TEXT          DEFAULT NULL, 
     createdAt     DATETIME      DEFAULT CURRENT_TIMESTAMP, 
     updatedAt     DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, 
     INDEX idx_mId (mId), 
     INDEX idx_status (status), 
     INDEX idx_createdAt (createdAt) 
 ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 表的结构 `BannerAd`
--

CREATE TABLE `BannerAd` (
  `adId` varchar(10) NOT NULL COMMENT '廣告ID',
  `mId` varchar(10) NOT NULL COMMENT '教師ID',
  `cId` varchar(10) DEFAULT NULL COMMENT '課程ID',
  `purchaseDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '購買日期',
  `endDate` timestamp NOT NULL COMMENT '投放結束時間',
  `adContent` text DEFAULT NULL COMMENT '廣告內容'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `BannerAd`
--

INSERT INTO `BannerAd` (`adId`, `mId`, `cId`, `purchaseDate`, `endDate`, `adContent`) VALUES
('BA000001', 'M0000002', 'C0000001', '2025-08-01 10:00:00', '2025-08-06 10:00:00', '歡迎參加我的廣東話課程！'),
('BA000002', 'M0000004', 'C0000003', '2025-08-04 09:15:00', '2025-08-09 09:15:00', '基礎科學實驗課程，歡迎報名！');

-- --------------------------------------------------------

--
-- 表的结构 `FullPageAd`
--

CREATE TABLE `FullPageAd` (
  `adId` varchar(10) NOT NULL COMMENT '廣告ID',
  `mId` varchar(10) NOT NULL COMMENT '教師ID',
  `cId` varchar(10) DEFAULT NULL COMMENT '課程ID',
  `purchaseDate` timestamp NOT NULL DEFAULT current_timestamp() COMMENT '購買日期',
  `endDate` timestamp NOT NULL COMMENT '投放結束時間',
  `adContent` text DEFAULT NULL COMMENT '廣告內容',
  `adImage` varchar(200) DEFAULT NULL COMMENT '廣告圖片路徑'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- 转存表中的数据 `FullPageAd`
--

INSERT INTO `FullPageAd` (`adId`, `mId`, `cId`, `purchaseDate`, `endDate`, `adContent`, `adImage`) VALUES
('FA000001', 'M0000004', 'C0000003', '2025-08-04 09:15:00', '2025-08-09 09:15:00', '基礎科學實驗課程，培養科學思維！', 'fullpage002.jpg');

--
-- 表的索引 `BannerAd`
--
ALTER TABLE `BannerAd`
  ADD PRIMARY KEY (`adId`),
  ADD KEY `mId` (`mId`),
  ADD KEY `cId` (`cId`);

--
-- 表的索引 `FullPageAd`
--
ALTER TABLE `FullPageAd`
  ADD PRIMARY KEY (`adId`),
  ADD KEY `mId` (`mId`),
  ADD KEY `cId` (`cId`);

--
-- 添加外鍵約束
--

--
-- 外鍵約束 for table `AdminRolePermission`
--
ALTER TABLE `AdminRolePermission`
  ADD CONSTRAINT `AdminRolePermission_ibfk_1` FOREIGN KEY (`roleId`) REFERENCES `AdminRole` (`roleId`),
  ADD CONSTRAINT `AdminRolePermission_ibfk_2` FOREIGN KEY (`permissionId`) REFERENCES `AdminPermission` (`permissionId`);

--
-- 外鍵約束 for table `MemberRelation`
--
ALTER TABLE `MemberRelation`
  ADD CONSTRAINT `MemberRelation_ibfk_1` FOREIGN KEY (`studentId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `MemberRelation_ibfk_2` FOREIGN KEY (`teacherId`) REFERENCES `Member` (`mId`);

--
-- 外鍵約束 for table `Admin`
--
ALTER TABLE `Admin`
  ADD CONSTRAINT `Admin_ibfk_1` FOREIGN KEY (`langId`) REFERENCES `Language` (`langId`),
  ADD CONSTRAINT `Admin_ibfk_2` FOREIGN KEY (`roleId`) REFERENCES `AdminRole` (`roleId`);

-- 外鍵約束 for table `Member`
ALTER TABLE `Member`
  ADD CONSTRAINT `Member_ibfk_1` FOREIGN KEY (`langId`) REFERENCES `Language` (`langId`);

-- 外鍵約束 for table `Course`
--
ALTER TABLE `Course`
  ADD CONSTRAINT `Course_ibfk_1` FOREIGN KEY (`cateId`) REFERENCES `Category` (`cateId`),
  ADD CONSTRAINT `Course_ibfk_2` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `Course_ibfk_3` FOREIGN KEY (`langId`) REFERENCES `Language` (`langId`);

--
-- 限制导出的表 `CourseSearch`
--
ALTER TABLE `CourseSearch`
  ADD CONSTRAINT `CourseSearch_ibfk_1` FOREIGN KEY (`cId`) REFERENCES `Course` (`cId`);

--
-- 外鍵約束 for table `Lesson`
--
ALTER TABLE `Lesson`
  ADD CONSTRAINT `Lesson_ibfk_1` FOREIGN KEY (`cId`) REFERENCES `Course` (`cId`);

--
-- 外鍵約束 for table `LessonResource`
--
ALTER TABLE `LessonResource`
  ADD CONSTRAINT `LessonResource_ibfk_1` FOREIGN KEY (`lId`) REFERENCES `Lesson` (`lId`);

--
-- 外鍵約束 for table `MemberCourse`
--
ALTER TABLE `MemberCourse`
  ADD CONSTRAINT `MemberCourse_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `MemberCourse_ibfk_2` FOREIGN KEY (`cId`) REFERENCES `Course` (`cId`);

--
-- 外鍵約束 for table `MemberLesson`
--
ALTER TABLE `MemberLesson`
  ADD CONSTRAINT `MemberLesson_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `MemberLesson_ibfk_2` FOREIGN KEY (`lId`) REFERENCES `Lesson` (`lId`);

--
-- 外鍵約束 for table `History`
--
ALTER TABLE `History`
  ADD CONSTRAINT `History_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`);

--
-- 外鍵約束 for table `ACoinTransaction`
--
ALTER TABLE `ACoinTransaction`
  ADD CONSTRAINT `ACoinTransaction_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `ACoinTransaction_ibfk_2` FOREIGN KEY (`actTypeId`) REFERENCES `ACoinTransType` (`actTypeId`);

--
-- 外鍵約束 for table `ACoinTransType`
--
ALTER TABLE `ACoinTransType`
  ADD CONSTRAINT `ACoinTransType_ibfk_1` FOREIGN KEY (`conId`) REFERENCES `Conversion` (`conId`);


--
-- 外鍵約束 for table `Chatroom`
--
ALTER TABLE `Chatroom`
  ADD CONSTRAINT `Chatroom_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`);

--
-- 外鍵約束 for table `ChatroomMSG`
--
ALTER TABLE `ChatroomMSG`
  ADD CONSTRAINT `ChatroomMSG_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `ChatroomMSG_ibfk_2` FOREIGN KEY (`crId`) REFERENCES `Chatroom` (`crId`);

--
-- 外鍵約束 for table `Payment`
--
ALTER TABLE `Payment`
  ADD CONSTRAINT `Payment_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`);

--
-- 外鍵約束 for table `WithdrawalRequest`
--
ALTER TABLE `WithdrawalRequest`
  ADD CONSTRAINT `WithdrawalRequest_ibfk_1` FOREIGN KEY (`teacherId`) REFERENCES `Member` (`mId`);

--
-- 外鍵約束 for table `WithdrawalApproval`
--
ALTER TABLE `WithdrawalApproval`
  ADD CONSTRAINT `WithdrawalApproval_ibfk_1` FOREIGN KEY (`requestId`) REFERENCES `WithdrawalRequest` (`requestId`),
  ADD CONSTRAINT `WithdrawalApproval_ibfk_2` FOREIGN KEY (`processedBy`) REFERENCES `Admin` (`adminID`);

--
-- 外鍵約束 for table `MemberReport`
--
ALTER TABLE `MemberReport`
  ADD CONSTRAINT `MemberReport_ibfk_1` FOREIGN KEY (`reporterId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `MemberReport_ibfk_2` FOREIGN KEY (`reportedId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `MemberReport_ibfk_3` FOREIGN KEY (`reasonId`) REFERENCES `ReportReason` (`reasonId`),
  ADD CONSTRAINT `MemberReport_ibfk_4` FOREIGN KEY (`handledBy`) REFERENCES `Admin` (`adminID`);

--
-- 外鍵約束 for table `TutorSubject`
--
ALTER TABLE `TutorSubject`
  ADD CONSTRAINT `TutorSubject_ibfk_1` FOREIGN KEY (`tutorId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `TutorSubject_ibfk_2` FOREIGN KEY (`cateId`) REFERENCES `Category` (`cateId`);

--
-- 外鍵約束 for table `TutorBookmark`
--
ALTER TABLE `TutorBookmark`
  ADD CONSTRAINT `TutorBookmark_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `TutorBookmark_ibfk_2` FOREIGN KEY (`tutorId`) REFERENCES `Member` (`mId`);

--
-- 外鍵約束 for table `CourseBookmark`
--
ALTER TABLE `CourseBookmark`
  ADD CONSTRAINT `CourseBookmark_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `CourseBookmark_ibfk_2` FOREIGN KEY (`cId`) REFERENCES `Course` (`cId`);

--
-- 外鍵約束 for table `TutorReview`
--
ALTER TABLE `TutorReview`
  ADD CONSTRAINT `TutorReview_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `TutorReview_ibfk_2` FOREIGN KEY (`cId`) REFERENCES `Course` (`cId`);

--
-- 外鍵約束 for table `Message`
--
ALTER TABLE `Message`
  ADD CONSTRAINT `Message_ibfk_1` FOREIGN KEY (`senderId`) REFERENCES `Admin` (`adminID`),
  ADD CONSTRAINT `Message_ibfk_2` FOREIGN KEY (`recipientId`) REFERENCES `Member` (`mId`);

--
-- 外鍵約束 for table `BannerAd`
--
ALTER TABLE `BannerAd`
  ADD CONSTRAINT `BannerAd_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `BannerAd_ibfk_2` FOREIGN KEY (`cId`) REFERENCES `Course` (`cId`);

--
-- 外鍵約束 for table `FullPageAd`
--
ALTER TABLE `FullPageAd`
  ADD CONSTRAINT `FullPageAd_ibfk_1` FOREIGN KEY (`mId`) REFERENCES `Member` (`mId`),
  ADD CONSTRAINT `FullPageAd_ibfk_2` FOREIGN KEY (`cId`) REFERENCES `Course` (`cId`);

COMMIT;


/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
