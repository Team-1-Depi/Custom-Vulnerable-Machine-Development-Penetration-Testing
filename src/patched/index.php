<?php
// ==============================================================================
// PATCHED VERSION (Blue Team Remediation) - src/patched/index.php
// Security Fixes Applied:
// 1. Replaced String Concatenation with Parameterized Queries (Prepared Statements).
// 2. Replaced weak MD5 hashing with strong Bcrypt (password_verify).
// 3. Isolated database credentials into an external environment configuration file.
// 4. Added session_regenerate_id(true) to prevent Session Fixation attacks.
// ==============================================================================

session_start();
require_once '/etc/depi_portal/db_credentials.php';

$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    die("Database connection error.");
}

$error = "";

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $raw_user = trim($_POST['username'] ?? '');
    $raw_pass = $_POST['password'] ?? '';

    // FIX 1: Prepared Statement separates SQL query structure from user data
    $stmt = $conn->prepare("SELECT id, username, password FROM users WHERE username = ? LIMIT 1");
    $stmt->bind_param("s", $raw_user);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($row = $result->fetch_assoc()) {
        // FIX 2: Verify salted Bcrypt hash instead of vulnerable MD5 comparison in SQL
        if (password_verify($raw_pass, $row['password'])) {
            session_regenerate_id(true);
            $_SESSION['loggedin'] = true;
            $_SESSION['user'] = $row['username'];
            header("Location: upload.php");
            exit();
        } else {
            $error = "Authentication Failed: Invalid corporate credentials.";
        }
    } else {
        $error = "Authentication Failed: Invalid corporate credentials.";
    }
    $stmt->close();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>DEPI Internal Admin Portal (HARDENED)</title>
    <style>
        body { background: #0d1117; color: #c9d1d9; font-family: Arial, sans-serif; text-align: center; padding-top: 80px; }
        .login-box { background: #161b22; padding: 30px; width: 380px; margin: auto; border-radius: 8px; border: 1px solid #238636; }
        input { width: 90%; padding: 10px; margin: 10px 0; background: #0d1117; border: 1px solid #30363d; color: #fff; border-radius: 4px; }
        button { width: 95%; padding: 10px; background: #238636; color: white; border: none; cursor: pointer; font-weight: bold; border-radius: 4px; }
        .err { color: #f85149; font-size: 14px; }
        .badge { color: #3fb950; font-size: 12px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="login-box">
        <h2>Employee Administration</h2>
        <p class="badge">🛡️ Protected by Prepared Statements & Bcrypt Auth</p>
        <?php if($error) echo "<p class='err'>" . htmlspecialchars($error, ENT_QUOTES, 'UTF-8') . "</p>"; ?>
        <form method="POST">
            <input type="text" name="username" placeholder="Corporate Username" maxlength="50" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Secure Login</button>
        </form>
    </div>
</body>
</html>
