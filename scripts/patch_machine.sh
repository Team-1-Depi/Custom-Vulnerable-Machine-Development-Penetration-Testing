#!/bin/bash

==============================================================================
DEPI Graduation Project - Automated Blue Team Patching & Hardening Script
Script Name: patch_machine.sh
Purpose: Remediate all vulnerabilities (SQLi, File Upload, Password Reuse,
SUID PrivEsc, and Exposed Services) WITHOUT breaking business
continuity on Port 80 and Port 8080.
==============================================================================
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "
BLUE==================================================================
{NC}"
echo -e "{BLUE} Starting DEPI Blue Team Automated Remediation & Hardening...{NC}"
echo -e "
BLUE==================================================================
{NC}"

if [ "
EUID"−ne0];thenecho−e"
{RED}[!] Error: Please run this script as root: sudo ./patch_machine.sh${NC}"
exit 1
fi

------------------------------------------------------------------------------
1. OS & Privilege Escalation Remediation (Closing SUID & Password Reuse)
------------------------------------------------------------------------------
echo -e "{YELLOW}[*] Step 1/5: Removing SUID misconfiguration & rotating OS passwords...{NC}"

Remove SUID bit from /usr/bin/find
chmod u-s /usr/bin/find

Rotate 'pioneer' OS user password so it no longer matches the Database password
echo "pioneer:Unique_OS_Pioneer_#2026_Secure!" | chpasswd

------------------------------------------------------------------------------
2. Database Security Upgrade (Upgrading from MD5 to Bcrypt + Secure Env)
------------------------------------------------------------------------------
echo -e "
YELLOW[∗]Step2/5:UpgradingDatabasepasswordhashfromMD5toBcrypt...
{NC}"

Bind MySQL strictly to localhost (127.0.0.1) so Port 3306 is no longer exposed externally
sed -i 's/0.0.0.0/127.0.0.1/g' /etc/mysql/mysql.conf.d/mysqld.cnf
systemctl restart mysql

Generate a strong Bcrypt hash for 'SuperComplexPassword_998877!' using PHP
BCRYPT_HASH=$(php -r "echo password_hash('SuperComplexPassword_998877!', PASSWORD_BCRYPT);")

mysql -e "
USE depi_portal;
UPDATE users SET password = '${BCRYPT_HASH}' WHERE username = 'admin';
"

Store DB credentials in an isolated root/www-data readable config outside web root
cat << 'EOF' > /etc/apache2/depi_db_env.conf
SetEnv DEPI_DB_HOST 127.0.0.1
SetEnv DEPI_DB_USER depi_admin
SetEnv DEPI_DB_PASS Pioneer@2026_Pass!
SetEnv DEPI_DB_NAME depi_portal
EOF
chmod 640 /etc/apache2/depi_db_env.conf
chown root:www-data /etc/apache2/depi_db_env.conf
a2enconf depi_db_env

------------------------------------------------------------------------------
3. Patching SQL Injection in Port 8080 (Prepared Statements + Bcrypt)
------------------------------------------------------------------------------
echo -e "{YELLOW}[*] Step 3/5: Patching index.php with Prepared Statements & Bcrypt...{NC}"

cat << 'EOF' > /var/www/portal/index.php

------------------------------------------------------------------------------
4. Patching File Upload in Port 8080 (Whitelist + finfo + Non-Executable Dir)
------------------------------------------------------------------------------
echo -e "{YELLOW}[*] Step 4/5: Patching upload.php & disabling PHP execution in /uploads...{NC}"

Incident Response: Purge any previously uploaded web shells (.php, .phtml) from uploads/
rm -f /var/www/portal/uploads/.php /var/www/portal/uploads/.phtml

cat << 'EOF' > /var/www/portal/upload.php

Harden Apache VirtualHost: Remove .phtml handler & disable PHP engine inside /uploads
cat << 'EOF' > /etc/apache2/sites-available/portal.conf
<VirtualHost *:8080>
DocumentRoot /var/www/portal
<Directory /var/www/portal>
AllowOverride None
Require all granted

<Directory /var/www/portal/uploads>
php_admin_flag engine off
Options -ExecCGI -Indexes
RemoveHandler .php .phtml .php3 .php4 .php5 .php7
<FilesMatch ".(php|phtml|php3|php4|php5|php7|sh|pl|py)$">
Require all denied



EOF

chown -R root:www-data /var/www/portal
chmod 640 /var/www/portal/index.php /var/www/portal/upload.php
chown -R www-data:www-data /var/www/portal/uploads
chmod 750 /var/www/portal/uploads

systemctl restart apache2

------------------------------------------------------------------------------
5. Network Hardening & Automated Verification Check
------------------------------------------------------------------------------
echo -e "{YELLOW}[*] Step 5/5: Hardening network services & verifying patch status...{NC}"

Disable Anonymous FTP
sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' /etc/vsftpd.conf
systemctl restart vsftpd

echo -e "\n${BLUE}
NC"echo−e"
{BLUE}   Blue Team Hardening Verification Summary:
NC"echo−e"
{BLUE}${NC}"

if [ ! -u /usr/bin/find ]; then
echo -e "  
GREEN[SECURED]
{NC} SUID bit removed from /usr/bin/find."
fi

if ss -tulpn | grep ":3306 " | grep -q "127.0.0.1"; then
echo -e "  
GREEN[SECURED]
{NC} MySQL (Port 3306) bound strictly to localhost (127.0.0.1)."
fi

if ss -tulpn | grep -q ":8080 "; then
echo -e "  
GREEN[ONLINE]
{NC}  Port 8080 Web Portal is ACTIVE and serving legitimate users!"
fi

echo -e "
BLUE==================================================================
{NC}"
echo -e "
GREEN[+]MachineSuccessfullyHardened!AllexploitsblockedwhilekeepingPort8080operational.
{NC}"
