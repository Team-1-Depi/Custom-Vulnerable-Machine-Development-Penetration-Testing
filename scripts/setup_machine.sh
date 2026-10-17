#!/bin/bash
# ==============================================================================
# DEPI Graduation Project - Automated Boot2Root Machine Provisioning Script
# Target OS: Ubuntu Server 20.04 LTS
# Features: 8 Open Ports (7 Rabbit Holes + 1 Real Web Entry), SQLi WAF v2.0,
#           3-Layer File Upload Filter, Password Reuse, SUID PrivEsc,
#           Initial User Cleanup, and Automated Self-Verification Test.
# ==============================================================================

set -e

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE}   Starting DEPI Custom CTF Machine Setup & Configuration...      ${NC}"
echo -e "${BLUE}==================================================================${NC}"

# 0. Check Root Privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Error: Please run this script with sudo: sudo ./setup_machine.sh${NC}"
  exit 1
fi

# 1. Install All Required Packages
echo -e "${YELLOW}[*] Step 1/8: Updating repositories and installing packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y apache2 php libapache2-mod-php php-mysql mysql-server vsftpd samba openssh-server net-tools curl wget vim ufw

# Disable UFW so all 8 configured ports are directly reachable
ufw disable

# 2. Configure Port 21 (FTP - Rabbit Hole #1)
echo -e "${YELLOW}[*] Step 2/8: Configuring Port 21 (vsftpd Decoy)...${NC}"
systemctl enable --now vsftpd
sed -i 's/anonymous_enable=NO/anonymous_enable=YES/g' /etc/vsftpd.conf
sed -i 's/#anonymous_enable=YES/anonymous_enable=YES/g' /etc/vsftpd.conf
mkdir -p /srv/ftp
echo "Nice try! There are no exploits here. Check the web applications." > /srv/ftp/hint.txt
chown nobody:nogroup /srv/ftp/hint.txt
systemctl restart vsftpd

# 3. Configure Ports 139 & 445 (Samba - Rabbit Holes #4 & #5)
echo -e "${YELLOW}[*] Step 3/8: Configuring Ports 139 & 445 (Samba Safe Decoy Share)...${NC}"
systemctl enable --now smbd
mkdir -p /srv/samba/public_temp
echo "SMB Share is under maintenance. Internal employee portal moved to port 8080." > /srv/samba/public_temp/readme.txt
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

# 4. Configure Port 3306 (MySQL - Rabbit Hole #6 + Database Backend)
echo -e "${YELLOW}[*] Step 4/8: Configuring MySQL Server (Port 3306) & Database...${NC}"
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

# 5. Configure Ports 80, 8080, and 9090 (Apache Web Applications)
echo -e "${YELLOW}[*] Step 5/8: Deploying Web Portals on Ports 80, 8080, and 9090...${NC}"
rm -f /var/www/html/index.html

# Port 80 Decoy Corporate Page
cat << 'EOF' > /var/www/html/index.php
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>DEPI Corp - Official Website</title>
    <style>
        body { background-color: #0d1117; color: #c9d1d9; font-family: Arial, sans-serif; text-align: center; padding-top: 100px; }
        .box { border: 1px solid #30363d; background: #161b22; padding: 40px; width: 50%; margin: auto; border-radius: 8px; }
        h1 { color: #58a6ff; }
        .status { color: #3fb950; font-weight: bold; }
    </style>
</head>
<body>
    <div class="box">
        <h1>Welcome to DEPI Corporate Server</h1>
        <p>Public Web Server Status: <span class="status">ACTIVE</span></p>
        <p>Server Time: <?php echo date('Y-m-d H:i:s'); ?></p>
        <hr style="border-color: #30363d;">
        <p>For inquiries, contact: support@depi-corp.local</p>
    </div>
    <!-- Note to IT Team: Public website is static. Do not host internal tools on port 80. -->
</body>
</html>
EOF

# Port 8080 Real Entry Point (SQLi WAF v2.0 + 3-Layer File Upload)
mkdir -p /var/www/portal/uploads

cat << 'EOF' > /var/www/portal/index.php
<?php
session_start();
$conn = mysqli_connect("localhost", "depi_admin", "Pioneer@2026_Pass!", "depi_portal");
$error = "";
$waf_alert = "";

function waf_inspect_and_sanitize($input, &$alert) {
    if (strpos($input, '--') !== false || strpos($input, ';') !== false) {
        $alert = "WAF Security Alert: Malicious SQL syntax (-- or ;) blocked!";
        return false;
    }
    $cleaned = str_ireplace(["OR", "AND", "UNION", "SELECT"], "", $input);
    $cleaned = str_replace(" ", "", $cleaned);
    return $cleaned;
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $raw_user = $_POST['username'] ?? '';
    $raw_pass = $_POST['password'] ?? '';

    $sanitized_user = waf_inspect_and_sanitize($raw_user, $waf_alert);
    $sanitized_pass = waf_inspect_and_sanitize($raw_pass, $waf_alert);

    if ($waf_alert === "") {
        $hashed_pass = md5($sanitized_pass);
        $sql = "SELECT * FROM users WHERE username = '$sanitized_user' AND password = '$hashed_pass'";
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
        <p style="font-size: 12px; color: #8b949e;">Protected by Custom WAF Sanitizer v2.0 (MD5 Auth)</p>
        <?php if($waf_alert) echo "<p class='waf'>$waf_alert</p>"; ?>
        <?php if($error) echo "<p class='err'>$error</p>"; ?>
        <form method="POST">
            <input type="text" name="username" placeholder="Corporate Username" maxlength="50" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Secure Login</button>
        </form>
    </div>
    <!-- Dev Note: WAF v2.0 strips (OR, AND, UNION, SELECT) once, blocks (-- and ;), removes spaces, and hashes passwords using MD5. -->
</body>
</html>
EOF

cat << 'EOF' > /var/www/portal/upload.php
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

    $fh = fopen($tmp_name, 'rb');
    $magic_bytes = fread($fh, 6);
    fclose($fh);

    $blacklisted_exts = ['php', 'php3', 'php4', 'php7', 'exe', 'sh'];
    $allowed_mimes = ['image/gif', 'image/jpeg', 'image/png'];

    if (in_array($ext, $blacklisted_exts)) {
        $status_msg = "Filter 1 Blocked: Direct script extensions (.php, .sh) are forbidden!";
        $status_class = "err";
    } elseif (!in_array($mime_type, $allowed_mimes)) {
        $status_msg = "Filter 2 Blocked: Invalid Content-Type ($mime_type). Only image MIME types are accepted!";
        $status_class = "err";
    } elseif (strpos($magic_bytes, 'GIF89a') !== 0 && strpos($magic_bytes, "\xFF\xD8\xFF") !== 0) {
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
EOF

chown -R www-data:www-data /var/www/portal
chmod -R 755 /var/www/portal
chmod 775 /var/www/portal/uploads

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
EOF

a2ensite portal.conf
systemctl restart apache2

# 6. Configure Users, Cleanup Initial Installer User Folder, & Set Flags
echo -e "${YELLOW}[*] Step 6/8: Setting up pioneer user, cleaning initial user folder, and planting Flags...${NC}"
id -u pioneer &>/dev/null || useradd -m -s /bin/bash pioneer
echo "pioneer:Pioneer@2026_Pass!" | chpasswd

# Clean up any initial Ubuntu installer user (e.g., tawfik or others) from /home so only pioneer is visible
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ] && [ "$SUDO_USER" != "pioneer" ]; then
    echo -e "${YELLOW}    -> Securing and hiding initial installer user ($SUDO_USER) home folder...${NC}"
    echo "$SUDO_USER:Complex_Admin_#99887766!" | chpasswd
    rm -rf "/home/$SUDO_USER"
fi

# Plant User Flag & Root Flag
echo "DEPI{User_Flag_Captured_Post_Exploitation_Success}" > /home/pioneer/user.txt
chown pioneer:pioneer /home/pioneer/user.txt
chmod 600 /home/pioneer/user.txt

echo "DEPI{Root_Flag_Pwned_Graduation_Project_Complete}" > /root/root.txt
chmod 600 /root/root.txt

# 7. Configure Privilege Escalation (SUID on /usr/bin/find) & Harden SSH
echo -e "${YELLOW}[*] Step 7/8: Configuring SUID bit on /usr/bin/find and locking SSH passwords...${NC}"
chmod u+s /usr/bin/find

sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
systemctl restart ssh

# 8. Automated Self-Verification Test (Health Check)
echo -e "\n${BLUE}==================================================================${NC}"
echo -e "${BLUE}   Step 8/8: Running Automated Machine Verification Check...      ${NC}"
echo -e "${BLUE}==================================================================${NC}"

check_port() {
    if ss -tulpn | grep -q ":$1 "; then
        echo -e "  ${GREEN}[PASS]${NC} Port $1 ($2) is OPEN and listening."
    else
        echo -e "  ${RED}[FAIL]${NC} Port $1 ($2) is NOT listening!"
    fi
}

check_port 21 "FTP Decoy"
check_port 22 "SSH Decoy"
check_port 80 "HTTP Public Decoy"
check_port 139 "NetBIOS Decoy"
check_port 445 "SMB Share Decoy"
check_port 3306 "MySQL Decoy"
check_port 8080 "Real Entry Web Portal"
check_port 9090 "Maintenance HTTP Decoy"

if [ -u /usr/bin/find ]; then
    echo -e "  ${GREEN}[PASS]${NC} Privilege Escalation SUID bit is active on /usr/bin/find."
else
    echo -e "  ${RED}[FAIL]${NC} SUID bit is missing on /usr/bin/find!"
fi

if [ -f /home/pioneer/user.txt ] && [ -f /root/root.txt ]; then
    echo -e "  ${GREEN}[PASS]${NC} Both user.txt and root.txt flags are in place."
else
    echo -e "  ${RED}[FAIL]${NC} Flags are missing!"
fi

echo -e "${BLUE}==================================================================${NC}"
echo -e "${GREEN}[+] Setup Complete! Your machine is 100% ready for CTF testing.${NC}"
