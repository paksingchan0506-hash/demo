<?php
define("HOST", "localhost") ;
define("USER", "root") ;
define("PWD", "anony1edu2") ;
define("DB", "anonymousEduTest" ) ;

function checkLogin(){

}

/*
   Author: Alvin Lam
   Date: 04-Aug-2025
   Description: This function is to connect Database 
*/
function connectDB(){
   try {
       $conn = mysqli_connect(HOST, USER, PWD, DB);
       
       if (!$conn) {
           throw new Exception("Database connection failed: " . mysqli_connect_error());
       }
       
       mysqli_set_charset($conn, "utf8");
       
       return $conn;
   } catch(Exception $e) {
       throw new Exception("Database connection failed: " . $e->getMessage());
   }
}

/*
   Author: Alvin Lam
   Date: 04-Aug-2025
   Description: This function is to generate ID for different table in Database 
                $connection: Database connection which called by connectDB()
                $prefix: First few character(s) which identify different PK in the table 
                $length: Total number of characters of this fields 
                $col: Field name that store the generated ID 
                $table: Table name 				
*/
function genID($connection, $prefix, $length, $col, $table){ 
	$sql = "SELECT max($col) AS maxNo FROM $table " ; 
	$result = mysqli_query($connection, $sql );
	$rc = mysqli_fetch_assoc($result); 
	$maxno = $rc["maxNo"] ; 
	return $prefix . substr( "00000" . (str_replace($prefix, "", $maxno) + 1 ) , (-1 * $length )+ strlen($prefix))  ;
}


?>