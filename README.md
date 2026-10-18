# 🛡️ DEPI Graduation Project: Custom Vulnerable Machine Development & Penetration Testing

**Initiative:** Digital Egypt Pioneers Initiative (DEPI)  
**Track:** Cybersecurity & Ethical Hacking  
**Base OS:** Ubuntu Server 20.04 LTS  
**Architecture:** 8 Open Ports (7 Decoy Rabbit Holes + 1 Chained Web-to-Root Entry Point)

---

## 📥 1. Download Ready-to-Use Virtual Machine (.OVA)
the complete `.ova` appliance is hosted on Google Drive:

### 👉 **[Download DEPI-CTF.ova (Google Drive)]**
https://drive.google.com/file/d/1EQRs67g06htNCYEeiYF0aew-eL3XcMdk/view?usp=sharing

**How to Import & Run:**
1. Download the `.ova` file from the link above.
2. Open **VMware Workstation** or **VirtualBox** -> Click `File` -> `Import Appliance` (or `Open`).
3. Set the Network Adapter to **NAT** or **Host-Only** (same network segment as your Kali Linux attacker machine).
4. Power on the machine (No login required — discover the IP from Kali using `sudo arp-scan -l`).

---

## ⚡ 2. Automated Build from Scratch (`setup_machine.sh`)
If you prefer to build the machine on a fresh **Ubuntu Server 20.04** installation instead of downloading the `.ova`, run our automated provisioning script which installs all services, configures the 8 ports, builds the MySQL database, deploys the PHP WAF filters, sets up Privilege Escalation, and executes a **Self-Verification Test**:

bash

wget  https://raw.githubusercontent.com/Team-1-Depi/Custom-Vulnerable-Machine-Development-Penetration-Testing/main/scripts/setup_machine.sh
chmod +x setup_machine.sh
sudo ./setup_machine.sh

---

## 🏗️ 3. Port Topology & Scenario Design
When scanned with `nmap -sC -sV -p- <TARGET_IP>`, the machine exposes **exact 8 open ports**:

| Port | Service | Role in CTF | Technical Configuration |
| :--- | :--- | :--- | :--- |
| **21/tcp** | FTP (`vsftpd 3.0.5`) | **Rabbit Hole #1** | Anonymous read-only access enabled; contains decoy `hint.txt`. |
| **22/tcp** | SSH (`OpenSSH 8.2p1`) | **Rabbit Hole #2** | `PasswordAuthentication no` enforced to prevent brute-forcing. |
| **80/tcp** | HTTP (`Apache 2.4.41`) | **Rabbit Hole #3** | Static corporate portal (`DEPI Corp`) with no RCE vectors. |
| **139/tcp** | NetBIOS (`Samba`) | **Rabbit Hole #4** | Patched Samba service; immune to known Metasploit RCEs. |
| **445/tcp** | SMB (`Samba`) | **Rabbit Hole #5** | Isolated guest share (`Public_Temp`) pointing to `/srv/samba/public_temp`. |
| **3306/tcp** | MySQL (`MySQL 8.0`) | **Rabbit Hole #6** | Bound to `0.0.0.0` for visibility, but rejects external host connections. |
| **8080/tcp** | HTTP (`Apache VHost`) | **🎯 Real Entry Point** | Custom WAF Login (`SQLi`) chaining into a 3-Layer `File Upload` filter. |
| **9090/tcp** | HTTP-Alt (`Apache`) | **Rabbit Hole #7** | Secondary listener configured as a maintenance decoy. |

---

## ⚔️ 4. Full Exploitation Kill Chain
1. **Network Enumeration (`Nmap`):** Identify the 8 open ports and eliminate the 7 decoys.
2. **Stage 1 — SQLi WAF Bypass (Port `8080`):**
   * *Filter:* Blocks `--` and `;`, removes spaces, strips `OR/AND/UNION/SELECT` once (`str_ireplace`), and hashes passwords via `MD5`.
   * *Bypass:* `admin'/**/oorr/**/'1'='1'#`
3. **Stage 2 — Unrestricted File Upload Bypass (`Burp Suite Pro` + `msfvenom`):**
   * *Filter 1 (Extension Blacklist):* Bypassed by renaming `shell.php` to `shell.phtml`.
   * *Filter 2 (MIME Type Check):* Bypassed in Burp Suite by changing `Content-Type` to `image/gif`.
   * *Filter 3 (Magic Bytes Check):* Bypassed by prepending `GIF89a;` to the payload body.
4. **Stage 3 — Post-Exploitation & Lateral Movement (`www-data` -> `pioneer`):**
   * Receive Meterpreter session via `msfconsole` (`exploit/multi/handler`).
   * Extract database credentials (`Pioneer@2026_Pass!`) from `/var/www/portal/index.php` and leverage **Password Reuse (CWE-521)** to switch to OS user `pioneer` and capture `/home/pioneer/user.txt`.
5. **Stage 4 — Privilege Escalation (`pioneer` -> `root`):**
   * Enumerate SUID binaries (`find / -perm -4000 -type f 2>/dev/null`).
   * Exploit misconfigured SUID bit on `/usr/bin/find` via `/usr/bin/find . -exec /bin/sh -p \; -quit` to achieve `euid=0(root)` and capture `/root/root.txt`.

---

## 📂 5. Repository Contents
* `scripts/setup_machine.sh` — Full automated build and self-testing bash script.
* `src/index.php` — Vulnerable login portal with custom WAF sanitizer v2.0.
* `src/upload.php` — 3-layer filtered file uploader (Extension, MIME, Magic Bytes).
