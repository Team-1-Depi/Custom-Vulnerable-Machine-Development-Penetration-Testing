<?php
// ==============================================================================
// PATCHED VERSION (Blue Team Remediation) - src/patched/upload.php
// Security Fixes Applied:
// 1. Strict Extension Whitelisting (only .jpg, .jpeg, .png, .gif allowed).
// 2. Server-side MIME inspection using finfo_file() instead of HTTP Header $_FILES['type'].
// 3. Structural image validation using getimagesize() instead of 6-byte magic header check.
// 4. Randomized cryptographic filename generation (bin2hex) to prevent direct shell naming.
// (Note: Paired with Apache 'php_admin_flag engine off' on the /uploads directory).
// ==============================================================================

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
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

    // FIX 1: Strict Extension Whitelist (Blocks .phtml, .php5, .phar, etc.)
    $allowed_exts = ['jpg', 'jpeg', 'png', 'gif'];

    // FIX 2: Server-side binary MIME inspection via libmagic (ignores spoofed Burp headers)
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $real_mime = finfo_file($finfo, $tmp_name);
    finfo_close($finfo);
    $allowed_mimes = ['image/jpeg', 'image/png', 'image/gif'];

    // FIX 3: Full image structure verification (ensures valid width/height pixel matrix)
    $img_info = @getimagesize($tmp_name);

    if (!in_array($ext, $allowed_exts, true)) {
        $status_msg = "Security Policy Block: Only strict image extensions (.jpg, .png, .gif) are permitted.";
        $status_class = "err";
    } elseif (!in_array($real_mime, $allowed_mimes, true) || $img_info === false) {
        $status_msg = "Security Policy Block: File failed deep server-side binary image structure validation.";
        $status_class = "err";
    } else {
        // FIX 4: Rename uploaded file to a random cryptographic hash so attacker cannot execute scripts
        $safe_filename = bin2hex(random_bytes(12)) . "." . $ext;
        $target_path = "uploads/" . $safe_filename;

        if (move_uploaded_file($tmp_name, $target_path)) {
            $status_msg = "Verified image securely stored as: <a style='color:#58a6ff' href='" . htmlspecialchars($target_path, ENT_QUOTES, 'UTF-8') . "'>" . htmlspecialchars($safe_filename, ENT_QUOTES, 'UTF-8') . "</a>";
            $status_class = "ok";
        } else {
            $status_msg = "System Error: Could not save file.";
            $status_class = "err";
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>DEPI Avatar Uploader (HARDENED)</title>
    <style>
        body { background: #0d1117; color: #c9d1d9; font-family: Arial, sans-serif; text-align: center; padding-top: 70px; }
        .box { background: #161b22; padding: 30px; width: 460px; margin: auto; border-radius: 8px; border: 1px solid #238636; }
        input[type="file"] { margin: 15px 0; padding: 10px; background: #0d1117; border: 1px solid #30363d; color: #c9d1d9; width: 85%; border-radius: 4px; }
        button { width: 90%; padding: 10px; background: #238636; color: #fff; border: none; cursor: pointer; font-weight: bold; border-radius: 4px; }
        .err { color: #f85149; background: rgba(248,81,73,0.1); padding: 10px; border: 1px solid #f85149; border-radius: 4px; margin-top: 15px; font-size: 13px; }
        .ok { color: #3fb950; background: rgba(63,185,80,0.1); padding: 10px; border: 1px solid #3fb950; border-radius: 4px; margin-top: 15px; font-size: 13px; }
        .badge { color: #3fb950; font-size: 12px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="box">
        <h2>Corporate Profile Image Uploader</h2>
        <p class="badge">🛡️ Protected by Strict Whitelist + finfo() + PHP Engine Disabled</p>
        <form method="POST" enctype="multipart/form-data">
            <input type="file" name="file" required><br>
            <button type="submit">Upload Verified Image</button>
        </form>
        <?php if($status_msg) echo "<div class='$status_class'>$status_msg</div>"; ?>
    </div>
</body>
</html>
