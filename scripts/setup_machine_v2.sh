#!/bin/bash
# ==============================================================================
# DEPI Graduation Project - Automated Boot2Root Machine (Production-Like CTF)
# Target OS: Ubuntu Server 20.04 LTS
# Project: NexusHR Enterprise Environment
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[*] Step 1: Installing Packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y apache2 php libapache2-mod-php php-mysql mysql-server vsftpd samba openssh-server net-tools curl ufw

ufw disable

echo -e "${YELLOW}[*] Step 2: Configuring Port 21 (FTP - Decoy 1)...${NC}"
systemctl enable --now vsftpd
sed -i 's/anonymous_enable=NO/anonymous_enable=YES/g' /etc/vsftpd.conf
sed -i 's/#anonymous_enable=YES/anonymous_enable=YES/g' /etc/vsftpd.conf
mkdir -p /srv/ftp
cat << 'EOF' > /srv/ftp/maintenance_log.txt
[LOG - 2026-10-15]
Routine automated backup completed successfully. 
Warning: Legacy management interfaces on port 9090 are scheduled for deprecation.
Ensure all sync scripts use the new secure API endpoints.
- IT Operations Team
EOF
chown nobody:nogroup /srv/ftp/maintenance_log.txt
systemctl restart vsftpd

echo -e "${YELLOW}[*] Step 3: Configuring Ports 139 & 445 (Samba - Decoys 2 & 3)...${NC}"
systemctl enable --now smbd
mkdir -p /srv/samba/public_temp
cat << 'EOF' > /srv/samba/public_temp/printer_drivers_info.txt
Instructions for Network Printers (Lexmark Series):
Please do not store personal files in this public share. This directory is periodically cleared.
To install the drivers, map this network drive and run the installer silently via GPO.
EOF
chmod -R 755 /srv/samba/public_temp

if ! grep -q "\[Public_Temp\]" /etc/samba/smb.conf; then
cat << 'EOF' >> /etc/samba/smb.conf

[Public_Temp]
   path = /srv/samba/public_temp
   browseable = yes
   read only = yes
   guest ok = yes
EOF
fi
systemctl restart smbd

echo -e "${YELLOW}[*] Step 4: Configuring MySQL (Port 3306 - Decoy 4 & Backend)...${NC}"
systemctl enable --now mysql
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
systemctl restart mysql

mysql -e "
CREATE DATABASE IF NOT EXISTS depi_portal;
CREATE USER IF NOT EXISTS 'depi_admin'@'localhost' IDENTIFIED BY 'Pioneer@2026_Pass!';
GRANT ALL PRIVILEGES ON depi_portal.* TO 'depi_admin'@'localhost';
FLUSH PRIVILEGES;
USE depi_portal;
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50),
    password VARCHAR(100)
);
TRUNCATE TABLE users;
INSERT INTO users (username, password) VALUES ('admin', MD5('SuperComplexPassword_998877!'));
"

echo -e "${YELLOW}[*] Step 5: Deploying Web Portals (Ports 80, 8080, 9090)...${NC}"
rm -f /var/www/html/index.html

# PORT 80: Professional Corporate Landing Page
cat << 'EOF' > /var/www/html/index.php
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Nexus Global Solutions</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; color: #333; background: #fafafa; }
        header { background: #2c3e50; color: #fff; padding: 20px 50px; display: flex; justify-content: space-between; align-items: center; }
        header h1 { margin: 0; font-size: 24px; letter-spacing: 1px; }
        header h1 span { color: #3498db; }
        .hero { background: #ecf0f1; padding: 100px 20px; text-align: center; border-bottom: 1px solid #ddd; }
        .hero h2 { font-size: 36px; color: #2c3e50; margin-bottom: 20px; }
        .hero p { font-size: 18px; color: #7f8c8d; max-width: 600px; margin: 0 auto; line-height: 1.6; }
        .footer { text-align: center; padding: 20px; font-size: 12px; color: #999; margin-top: 50px; }
    </style>
</head>
<body>
    <header>
        <h1>Nexus<span>Global</span></h1>
        <div>Enterprise Software & Infrastructure</div>
    </header>
    <div class="hero">
        <h2>Driving Digital Transformation</h2>
        <p>At Nexus Global, we build robust, scalable, and secure enterprise solutions for the modern workforce. Our cloud infrastructure empowers businesses to operate at peak efficiency.</p>
    </div>
    <div class="footer">
        &copy; <?php echo date('Y'); ?> Nexus Global Inc. All rights reserved. <br>
        Public infrastructure node: Active.
    </div>
</body>
</html>
EOF

mkdir -p /var/www/portal/uploads

# 8080 Login Page (NexusHR)
cat << 'EOF' > /var/www/portal/index.php
<?php
session_start();
error_reporting(0); 
$conn = @mysqli_connect("localhost", "depi_admin", "Pioneer@2026_Pass!", "depi_portal");
if (!$conn) { die("System Error: Database connection failed."); }

$error_msg = "";

function waf_inspect_and_sanitize($input) {
    if (strpos($input, '--') !== false || strpos($input, ';') !== false) { return ""; }
    $cleaned = str_ireplace(["OR", "AND", "UNION", "SELECT"], "", $input);
    $cleaned = str_replace(" ", "", $cleaned);
    return $cleaned;
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $raw_user = $_POST['username'] ?? '';
    $raw_pass = $_POST['password'] ?? '';
    $sanitized_user = waf_inspect_and_sanitize($raw_user);
    $sanitized_pass = waf_inspect_and_sanitize($raw_pass);

    if (empty($sanitized_user) && !empty($raw_user)) {
         $error_msg = "Invalid username or password.";
    } else {
        $hashed_pass = md5($sanitized_pass);
        $sql = "SELECT * FROM users WHERE username = '$sanitized_user' AND password = '$hashed_pass'";
        $result = @mysqli_query($conn, $sql);
        if ($result && mysqli_num_rows($result) > 0) {
            $_SESSION['loggedin'] = true;
            header("Location: profile.php");
            exit();
        } else {
            $error_msg = "Invalid username or password.";
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>NexusHR - Login</title>
    <style>
        body { background: #f4f7f6; color: #333; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .login-box { background: #fff; padding: 40px; width: 100%; max-width: 350px; border-radius: 8px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); text-align: center; }
        .logo { font-size: 24px; font-weight: bold; color: #2c3e50; margin-bottom: 30px; }
        .logo span { color: #3498db; }
        input { width: 100%; padding: 12px; margin: 10px 0; background: #ecf0f1; border: 1px solid #bdc3c7; color: #333; border-radius: 4px; box-sizing: border-box; }
        button { width: 100%; padding: 12px; background: #2980b9; color: white; border: none; cursor: pointer; font-weight: bold; border-radius: 4px; font-size: 16px; margin-top: 15px; }
        .err { color: #e74c3c; font-size: 14px; margin-top: 15px; }
        .footer { font-size: 12px; color: #7f8c8d; margin-top: 30px; }
    </style>
</head>
<body>
    <div class="login-box">
        <div class="logo">Nexus<span>HR</span></div>
        <p style="color: #7f8c8d; margin-bottom: 20px;">Employee Portal Access</p>
        <form method="POST">
            <input type="text" name="username" placeholder="Employee ID / Username" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Sign In</button>
        </form>
        <?php if($error_msg) echo "<p class='err'>$error_msg</p>"; ?>
        <div class="footer">Secure Portal v2.4.1 | NexusHR Inc.</div>
    </div>
</body>
</html>
EOF

# 8080 Profile Page
cat << 'EOF' > /var/www/portal/profile.php
<?php
session_start();
error_reporting(0);

if (!isset($_SESSION['loggedin']) || $_SESSION['loggedin'] !== true) {
    header("Location: index.php");
    exit();
}

$status_msg = "";
$status_class = "";
$avatar_url = "uploads/default-avatar.png"; 

if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_FILES['file'])) {
    $filename = basename($_FILES['file']['name']);
    $tmp_name = $_FILES['file']['tmp_name'];
    
    if(empty($tmp_name) || !file_exists($tmp_name)){
        $status_msg = "Please select a valid image.";
        $status_class = "err";
    } else {
        $mime_type = $_FILES['file']['type'];
        $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
        $fh = fopen($tmp_name, 'rb');
        $magic_bytes = fread($fh, 6);
        fclose($fh);

        $blacklisted_exts = ['php', 'php3', 'php4', 'php7', 'exe', 'sh', 'pht'];
        $allowed_mimes = ['image/gif', 'image/jpeg', 'image/png'];

        if (in_array($ext, $blacklisted_exts) || !in_array($mime_type, $allowed_mimes)) {
            $status_msg = "Upload failed. Invalid file format.";
            $status_class = "err";
        } elseif (strpos($magic_bytes, 'GIF89a') !== 0 && strpos($magic_bytes, "\xFF\xD8\xFF") !== 0 && strpos($magic_bytes, "\x89PNG") !== 0) {
            $status_msg = "Upload failed. Corrupted image file.";
            $status_class = "err";
        } else {
            $target_path = "uploads/" . $filename;
            if (move_uploaded_file($tmp_name, $target_path)) {
                $status_msg = "Profile picture updated successfully.";
                $status_class = "ok";
                $avatar_url = $target_path;
            } else {
                $status_msg = "System Error: Could not save the file.";
                $status_class = "err";
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>NexusHR - Employee Profile</title>
    <style>
        body { background: #f4f7f6; color: #333; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; }
        .header { background: #2c3e50; color: white; padding: 15px 30px; display: flex; justify-content: space-between; align-items: center; }
        .header .logo { font-size: 20px; font-weight: bold; }
        .header .logo span { color: #3498db; }
        .header .user-info { font-size: 14px; }
        .container { max-width: 700px; margin: 40px auto; background: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); }
        .profile-section { display: flex; gap: 30px; }
        .avatar-box { text-align: center; flex: 1; }
        .avatar-preview { width: 140px; height: 140px; border-radius: 50%; background-color: #ecf0f1; margin: 0 auto 20px auto; overflow: hidden; border: 3px solid #bdc3c7; display: flex; justify-content: center; align-items: center; color: #7f8c8d; font-size: 12px;}
        .avatar-preview img { width: 100%; height: 100%; object-fit: cover; }
        .details-box { flex: 2; }
        .details-box h3 { border-bottom: 1px solid #ecf0f1; padding-bottom: 10px; margin-top: 0; color: #2c3e50; }
        .details-row { margin-bottom: 15px; font-size: 15px;}
        .details-row strong { color: #7f8c8d; display: inline-block; width: 110px; }
        input[type="file"] { margin: 10px 0; font-size: 13px; }
        button { padding: 8px 16px; background: #27ae60; color: white; border: none; cursor: pointer; font-weight: bold; border-radius: 4px; }
        .err { color: #e74c3c; background: #fdedec; padding: 10px; border-radius: 4px; margin-top: 15px; font-size: 13px; border: 1px solid #e74c3c; }
        .ok { color: #27ae60; background: #eaaf4; padding: 10px; border-radius: 4px; margin-top: 15px; font-size: 13px; border: 1px solid #27ae60; }
        .logout { color: #e74c3c; text-decoration: none; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <div class="logo">Nexus<span>HR</span></div>
        <div class="user-info">Logged in as: Administrator | <a href="index.php" class="logout">Logout</a></div>
    </div>
    <div class="container">
        <div class="profile-section">
            <div class="avatar-box">
                <div class="avatar-preview">
                    <img src="<?php echo htmlspecialchars($avatar_url); ?>" alt="Avatar" onerror="this.style.display='none'; this.parentNode.innerHTML='No Avatar';">
                </div>
                <form method="POST" enctype="multipart/form-data">
                    <input type="file" name="file" required><br>
                    <button type="submit">Update Avatar</button>
                </form>
                <?php if($status_msg) echo "<div class='$status_class'>$status_msg</div>"; ?>
            </div>
            <div class="details-box">
                <h3>Employee Details</h3>
                <div class="details-row"><strong>Full Name:</strong> System Administrator</div>
                <div class="details-row"><strong>Department:</strong> IT Operations</div>
                <div class="details-row"><strong>Role:</strong> Super Admin</div>
                <div class="details-row"><strong>Email:</strong> admin@nexushr.local</div>
                <div class="details-row"><strong>Status:</strong> <span style="color: #27ae60; font-weight: bold;">Active</span></div>
            </div>
        </div>
    </div>
</body>
</html>
EOF

chown -R www-data:www-data /var/www/portal
chmod -R 755 /var/www/portal
chmod 775 /var/www/portal/uploads

# Configure Apache Ports and VirtualHosts
grep -q "Listen 8080" /etc/apache2/ports.conf || echo "Listen 8080" >> /etc/apache2/ports.conf
grep -q "Listen 9090" /etc/apache2/ports.conf || echo "Listen 9090" >> /etc/apache2/ports.conf

cat << 'EOF' > /etc/apache2/sites-available/portal.conf
<VirtualHost *:8080>
    DocumentRoot /var/www/portal
    <Directory /var/www/portal>
        AllowOverride All
        Require all granted
        AddType application/x-httpd-php .php .phtml
    </Directory>
</VirtualHost>

<VirtualHost *:9090>
    DocumentRoot /var/www/html
    ErrorDocument 403 "<h1>Service Unavailable</h1><p>Legacy Admin Console is currently offline for scheduled maintenance.</p>"
    Redirect 403 /
</VirtualHost>
EOF

a2ensite portal.conf
systemctl restart apache2

echo -e "${YELLOW}[*] Step 6: Setting up PrivEsc (SUID) and locking SSH...${NC}"
id -u pioneer &>/dev/null || useradd -m -s /bin/bash pioneer
echo "pioneer:Pioneer@2026_Pass!" | chpasswd

echo "DEPI{User_Flag_Captured_Post_Exploitation_Success}" > /home/pioneer/user.txt
chown pioneer:pioneer /home/pioneer/user.txt
chmod 600 /home/pioneer/user.txt

echo "DEPI{Root_Flag_Pwned_Graduation_Project_Complete}" > /root/root.txt
chmod 600 /root/root.txt

chmod u+s /usr/bin/find

# Bulletproof SSH Lockdown
echo "PasswordAuthentication no" | sudo tee /etc/ssh/sshd_config.d/99-depi-lock.conf
systemctl restart ssh

echo -e "${GREEN}[+] Setup Complete! Machine is fully hardened and ready.${NC}"
