<?php
session_start();

if (!isset($_SESSION['loggedin']) || $_SESSION['loggedin'] !== true) {
    header("Location: index.php");
    exit();
}

$status_msg = "";
$status_class = "";

if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_FILES['file'])) {
    $filename = basename($_FILES['file']['name']);
    $tmp_name = $_FILES['file']['tmp_name'];
    $mime_type = $_FILES['file']['type'];
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

    // (Magic Bytes)
    $fh = fopen($tmp_name, 'rb');
    $magic_bytes = fread($fh, 6);
    fclose($fh);

    // (Extension Blacklist)
    $blacklisted_exts = ['php', 'php3', 'php4', 'php7', 'exe', 'sh'];
    
    // (Content-Type / MIME Check)
    $allowed_mimes = ['image/gif', 'image/jpeg', 'image/png'];

    if (in_array($ext, $blacklisted_exts)) {
        $status_msg = "Filter 1 Blocked: Direct script extensions (.php, .sh) are forbidden!";
        $status_class = "err";
    } elseif (!in_array($mime_type, $allowed_mimes)) {
        $status_msg = "Filter 2 Blocked: Invalid Content-Type ($mime_type). Only image MIME types are accepted!";
        $status_class = "err";
    } elseif (strpos($magic_bytes, 'GIF89a') !== 0 && strpos($magic_bytes, "\xFF\xD8\xFF") !== 0) {
        //  (Magic Bytes Check)
        $status_msg = "Filter 3 Blocked: File signature mismatch! Missing valid image Magic Bytes (e.g., GIF89a).";
        $status_class = "err";
    } else {
        $target_path = "uploads/" . $filename;
        if (move_uploaded_file($tmp_name, $target_path)) {
            $status_msg = "File passed all 3 security filters! Stored at: <a style='color:#58a6ff' href='$target_path'>$target_path</a>";
            $status_class = "ok";
        } else {
            $status_msg = "System Error: Could not move file to uploads directory.";
            $status_class = "err";
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>DEPI Avatar & Asset Uploader</title>
    <style>
        body { background: #0d1117; color: #c9d1d9; font-family: Arial, sans-serif; text-align: center; padding-top: 70px; }
        .box { background: #161b22; padding: 30px; width: 460px; margin: auto; border-radius: 8px; border: 1px solid #30363d; }
        input[type="file"] { margin: 15px 0; padding: 10px; background: #0d1117; border: 1px solid #30363d; color: #c9d1d9; width: 85%; border-radius: 4px; }
        button { width: 90%; padding: 10px; background: #1f6feb; color: #fff; border: none; cursor: pointer; font-weight: bold; border-radius: 4px; }
        .err { color: #f85149; background: rgba(248,81,73,0.1); padding: 10px; border: 1px solid #f85149; border-radius: 4px; margin-top: 15px; font-size: 13px; }
        .ok { color: #3fb950; background: rgba(63,185,80,0.1); padding: 10px; border: 1px solid #3fb950; border-radius: 4px; margin-top: 15px; font-size: 13px; }
    </style>
</head>
<body>
    <div class="box">
        <h2>Corporate Profile Image Uploader</h2>
        <p style="font-size: 12px; color: #8b949e;">Multi-Layer Inspection: Extension Blacklist + MIME Type + Magic Bytes</p>
        <form method="POST" enctype="multipart/form-data">
            <input type="file" name="file" required><br>
            <button type="submit">Upload Image Asset</button>
        </form>
        <?php if($status_msg) echo "<div class='$status_class'>$status_msg</div>"; ?>
    </div>
</body>
</html>
