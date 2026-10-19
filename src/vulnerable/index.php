<?php
session_start();
$conn = mysqli_connect("localhost", "depi_admin", "Pioneer@2026_Pass!", "depi_portal");
$error = "";
$waf_alert = "";

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $raw_user = $_POST['username'] ?? '';
    $raw_pass = $_POST['password'] ?? '';

    if (strpos($raw_user, '--') !== false) {
        $waf_alert = "Security Filter Alert: Comment sequence (--) is blocked!";
    } else {
        $sanitized_user = str_ireplace(["OR", "AND", "UNION", "SELECT"], "", $raw_user);
        $sanitized_user = str_replace(" ", "", $sanitized_user);

        $sql = "SELECT * FROM users WHERE username = '$sanitized_user' AND password = '$raw_pass'";
        $result = mysqli_query($conn, $sql);

        if ($result && mysqli_num_rows($result) > 0) {
            $_SESSION['loggedin'] = true;
            header("Location: upload.php");
            exit();
        } else {
            $error = "Authentication Failed: Invalid corporate credentials.";
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>DEPI Internal Admin Portal</title>
    <style>
        body { background: #0d1117; color: #c9d1d9; font-family: Arial, sans-serif; text-align: center; padding-top: 80px; }
        .login-box { background: #161b22; padding: 30px; width: 380px; margin: auto; border-radius: 8px; border: 1px solid #30363d; }
        input { width: 90%; padding: 10px; margin: 10px 0; background: #0d1117; border: 1px solid #30363d; color: #fff; border-radius: 4px; }
        button { width: 95%; padding: 10px; background: #238636; color: white; border: none; cursor: pointer; font-weight: bold; border-radius: 4px; }
        .err { color: #f85149; font-size: 14px; }
        .waf { color: #d29922; background: rgba(210,153,34,0.1); padding: 8px; border: 1px solid #d29922; border-radius: 4px; font-size: 13px; }
    </style>
</head>
<body>
    <div class="login-box">
        <h2>Employee Administration</h2>
        <p style="font-size: 12px; color: #8b949e;">Protected by Custom Input Sanitizer v1.2</p>
        <?php if($waf_alert) echo "<p class='waf'>$waf_alert</p>"; ?>
        <?php if($error) echo "<p class='err'>$error</p>"; ?>
        <form method="POST">
            <input type="text" name="username" placeholder="Corporate Username" maxlength="50" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Secure Login</button>
        </form>
    </div>
    <!-- Dev Note: Input Sanitizer v1.2 strips (OR, AND, UNION, SELECT) once and removes spaces. -->
</body>
</html>
