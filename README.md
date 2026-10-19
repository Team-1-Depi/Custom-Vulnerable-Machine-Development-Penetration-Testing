# 🛡️ Custom-Vulnerable-Machine-Development-Penetration-Testing

**Initiative:** Digital Egypt Pioneers Initiative (DEPI) — Graduation Project  
**Track:** Cybersecurity & Ethical Hacking  
**Project Title:** Custom Vulnerable Machine Development & Penetration Testing  
**Base OS:** Ubuntu Server 20.04 LTS  
**Architecture:** 8 Open Ports (7 Decoy Rabbit Holes + 1 Chained Web-to-Root Entry Point)

---

##  1. Project Overview
This project demonstrates the full lifecycle of **Offensive & Defensive Security Engineering** through two core phases:
1. **Red Team / Lab Development:** Designing and building a custom Boot2Root CTF machine from scratch using *Reverse Hardening* techniques, featuring realistic web filter bypasses, custom WAF evasion, payload delivery (`msfvenom`), lateral movement, and Linux privilege escalation.
2. **Blue Team / Automated Remediation:** Developing an automated hardening script (`patch_machine.sh`) and patched source code (`src/patched/`) that eliminate all security vulnerabilities while maintaining **100% service availability** for legitimate corporate users.

---

##  2. Download Ready-to-Use Virtual Machine (.OVA)
Because the exported virtual appliance exceeds GitHub's 100 MB file limit, the ready-to-import `.ova` machine is hosted on Google Drive:

###  **[Download Custom-Vulnerable-Machine.ova (Google Drive)]**
https://drive.google.com/file/d/1EQRs67g06htNCYEeiYF0aew-eL3XcMdk/view?usp=sharing

**Import Instructions:**
1. Download the `.ova` file from the link above.
2. Open **VMware Workstation** or **VirtualBox** -> `File` -> `Import Appliance` (or `Open`).
3. Set the Network Adapter to **NAT** or **Host-Only** (on the same subnet as your Kali Linux attacker machine).
4. Power on the machine (Discover the target IP using `sudo arp-scan -l`).

---

##  3. Automated Provisioning & Remediation Scripts
Instead of manual configuration, the entire infrastructure is codified into two automated Bash scripts inside the `scripts/` directory:

* **Build Vulnerable Lab (`scripts/setup_machine.sh`):** Converts a fresh Ubuntu Server 20.04 installation into the vulnerable CTF environment and runs an automated self-check.
  ```bash
  wget  https://raw.githubusercontent.com/Team-1-Depi/Custom-Vulnerable-Machine-Development-Penetration-Testing/main/scripts/setup_machine.sh
  chmod +x scripts/setup_machine.sh
  sudo ./scripts/setup_machine.sh
  
* **Apply Blue Team Fixes (scripts/patch_machine.sh): Remediates SQLi (via Prepared Statements), secures File Upload (via Whitelisting & finfo), removes the SUID bit, isolates credentials, and disables PHP execution in /uploads without taking Port 8080 offline.

  ```bash
  wget https://raw.githubusercontent.com/Team-1-Depi/Custom-Vulnerable-Machine-Development-Penetration-Testing/refs/heads/main/scripts/patch_machine.sh
  chmod +x scripts/patch_machine.sh
  sudo ./scripts/patch_machine.sh

---

##  3. Port Topology & Scenario Design
When scanned with `nmap -sC -sV -p- <TARGET_IP>`, the machine exposes **exact 8 open ports**:

| Port | Service | Role in CTF | Technical Configuration |
| :--- | :--- | :--- | :--- |
| **21/tcp** | FTP (`vsftpd 3.0.5`) | **Rabbit Hole #1** | Anonymous read-only access enabled (write_enable=NO); contains decoy hint.txt inside chroot. |
| **22/tcp** | SSH (`OpenSSH 8.2p1`) | **Rabbit Hole #2** | `PasswordAuthentication no` enforced to prevent brute-forcing. |
| **80/tcp** | HTTP (`Apache 2.4.41`) | **Rabbit Hole #3** | Static corporate portal (`DEPI Corp`) with no RCE vectors. |
| **139/tcp** | NetBIOS (`Samba`) | **Rabbit Hole #4** | Patched Samba daemon; immune to legacy RCE exploits. |
| **445/tcp** | SMB (`Samba`) | **Rabbit Hole #5** | Read-only guest share (Public_Temp) isolated in `/srv/samba/public_temp.` |
| **3306/tcp** | MySQL (`MySQL 8.0`) | **Rabbit Hole #6** | Bound to `0.0.0.0` for visibility, but rejects external host connections. |
| **8080/tcp** | HTTP (`Apache VHost`) | **🎯 Real Entry Point** | Custom WAF Login (`SQLi`) chaining into a 3-Layer `File Upload` filter. |
| **9090/tcp** | HTTP-Alt (`Apache`) | **Rabbit Hole #7** | Secondary maintenance listener on Apache. |

---

## 5. Red Team Exploitation Kill Chain
**Reconnaissance (Nmap):** Discover the 8 open ports and inspect the 7 decoy services.

**Stage 1 — SQLi WAF Bypass (Port 8080):**

   * *Filter:* Blocks `--` and `;`, removes spaces, strips `OR/AND/UNION/SELECT` once (`str_ireplace`), and hashes passwords via `MD5`.
   * *Bypass:* `admin'/**/oorr/**/'1'='1'#`

**Stage 2 — 3-Layer File Upload Bypass (Burp Suite Pro + msfvenom):**

   * *Filter 1 (Extension Blacklist):* Bypassed by renaming `shell.php` to `shell.phtml`.
   * *Filter 2 (MIME Type Check):* Bypassed in Burp Suite by changing `Content-Type` to `image/gif`.
   * *Filter 3 (Magic Bytes Check):* Bypassed by prepending `GIF89a;` to the payload body.

**Stage 3 — Post-Exploitation & Lateral Movement (www-data -> pioneer):**

   * Receive Meterpreter session via `msfconsole` (`exploit/multi/handler`).
   * Extract database credentials (`Pioneer@2026_Pass!`) from `/var/www/portal/index.php` and leverage **Password Reuse (CWE-521)** to switch to OS user `pioneer` and capture `/home/pioneer/user.txt`.

**Stage 4 — Privilege Escalation (`pioneer` -> `root`):**

   * Enumerate SUID binaries (`find / -perm -4000 -type f 2>/dev/null`).
   * Exploit misconfigured SUID bit on `/usr/bin/find` via `/usr/bin/find . -exec /bin/sh -p \; -quit` to achieve `euid=0(root)` and capture `/root/root.txt`.


---


## 6. Repository Directory Structure

```text
Custom-Vulnerable-Machine-Development-Penetration-Testing/
├── README.md
├── scripts/
│   ├── setup_machine.sh            # Automated vulnerable lab builder
│   └── patch_machine.sh            # Automated Blue Team remediation script
├── src/
│   ├── vulnerable/
│   │   ├── index.php               # Vulnerable login (Flawed WAF + SQLi)
│   │   └── upload.php              # Vulnerable uploader (Blacklist + Header MIME + 6-byte Magic)
│   └── patched/
│       ├── index.php               # Patched login (Prepared Statements + Bcrypt)
│       └── upload.php              # Patched uploader (Strict Whitelist + finfo + UUID)
└── docs/
    ├── Project plan.pdf            # Project Plan
    └── OFFICIAL_PROJECT_REPORT.md  # Full technical documentation & walkthrough
```



