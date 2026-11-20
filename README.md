# Lock N' Key: The Developer's Vault

<p align="center">
  <img src="assets/images/logo.png" alt="Lock N' Key Logo" width="128"/>
</p>

<p align="center">
  <strong>The vault that never connects. True Security. Zero Trace. Zero Cloud.</strong><br/>
  <em>A local-only, developer-first secrets vault, CLI process injector, git leak guard, and encrypted credential manager for Windows.</em>
</p>

<p align="center">
  <a href="#-installation"><img src="https://img.shields.io/badge/Release-v1.0.2-blue?style=for-the-badge&logo=windows" alt="Release v1.0.2" /></a>
  <a href="#-security-architecture--threat-model"><img src="https://img.shields.io/badge/Security-AES--256--GCM-success?style=for-the-badge&logo=shield" alt="AES-256-GCM" /></a>
  <a href="#-the-zero-trust--zero-trace-philosophy"><img src="https://img.shields.io/badge/Cloud-0%25%20Air--Gapped-orange?style=for-the-badge&logo=icloud" alt="100% Offline" /></a>
  <a href="#windows-hello-biometric-authentication"><img src="https://img.shields.io/badge/Biometrics-Windows%20Hello-9cf?style=for-the-badge&logo=windows" alt="Windows Hello" /></a>
  <a href="#-building-from-source"><img src="https://img.shields.io/badge/Framework-Flutter%203.x%20Desktop-02569B?style=for-the-badge&logo=flutter" alt="Flutter Desktop" /></a>
</p>

---

## 📑 Table of Contents

- [💡 The Zero-Trust & Zero-Trace Philosophy](#-the-zero-trust--zero-trace-philosophy)
- [✨ Core Features Overview](#-core-features-overview)
- [🛠️ Deep Dive: The 5 Major Pillars](#️-deep-dive-the-5-major-pillars)
  - [1. Developer Secret Resolver CLI (`locknkey`)](#1-developer-secret-resolver-cli-locknkey)
  - [2. Git Leak Guard (Pre-Commit & Active Auditing)](#2-git-leak-guard-pre-commit--active-auditing)
  - [3. Encrypted Secret Files & In-Memory Secure Viewer](#3-encrypted-secret-files--in-memory-secure-viewer)
  - [4. 2FA Emergency Backup Codes Tracker](#4-2fa-emergency-backup-codes-tracker)
  - [5. Secret Health, Expiry & Rotation Alerts](#5-secret-health-expiry--rotation-alerts)
- [⚡ Quick Access Overlay (`Alt + Space`)](#-quick-access-overlay-alt--space)
- [🧩 Companion Browser Extension](#-companion-browser-extension)
- [🔄 Cross-Device Encrypted Transfer (`.lnk`)](#-cross-device-encrypted-transfer-lnk)
- [📥 Installation & Verification](#-installation--verification)
  - [Pre-Packaged Windows Setup (v1.0.2)](#pre-packaged-windows-setup-v102)
  - [SHA-256 Integrity Verification](#sha-256-integrity-verification)
  - [Windows Defender SmartScreen Note](#windows-defender-smartscreen-note)
- [🚀 5-Minute Quickstart Guide](#-5-minute-quickstart-guide)
- [🔒 Security Architecture & Threat Model](#-security-architecture--threat-model)
- [🏗️ Building from Source](#️-building-from-source)
- [👤 Author & License](#-author--license)

---

## 💡 The Zero-Trust & Zero-Trace Philosophy

Every time you paste an API key, store credentials in unencrypted `.env` files, or trust a cloud password manager, you are expanding your attack surface. Cloud vaults remain high-value targets for nation-state attacks, and clipboard managers frequently leak sensitive strings across untrusted desktop processes.

**Lock N' Key** was architected to eliminate this entire class of vulnerabilities:

1. **100% Local-Only & Air-Gapped:** Your vault is stored exclusively on your physical drive. No sync servers, no telemetry, no tracking, and zero outbound network connections.
2. **Zero-Clipboard Principle:** Avoids the system clipboard where possible. Secrets can be injected directly into child process environments via the CLI or typed via low-level virtual keystrokes into IDEs and terminals.
3. **Zero Plaintext Disk Traces:** Decrypted files are decoded strictly in volatile system RAM (`Uint8List`). No temporary files are ever dumped to `%TEMP%` or working directories during inspection.
4. **Developer-Native Velocity:** Native Windows integration (`Alt + Space` overlay, system tray daemon, and a high-speed CLI binary) ensures security never compromises your development speed.

---

## ✨ Core Features Overview

| Feature | Description |
| :--- | :--- |
| **🔒 AES-256-GCM Vault** | Locally encrypted at rest with PBKDF2 key derivation and hardware-backed Windows Hello support. |
| **💻 Developer CLI (`locknkey`)** | Full terminal suite (`run`, `list`, `get`, `set`, `delete`, `status`, `hook`, `scan`) for CI/CD and local scripting. |
| **🛡️ Git Leak Guard** | Automatic pre-commit hook that audits staged diffs against your vault to block accidental leaks before they reach git. |
| **📁 Encrypted Secret Files** | Secure file vault for `.pem`, `.key`, `id_ed25519`, `service-account.json`, `.ovpn`, and `.env` files. |
| **👁️ In-Memory Secure File Viewer** | RAM-only viewer with line numbers, JSON formatting, search highlighting, and zoomable images with **zero disk traces**. |
| **📋 2FA Backup Codes Tracker** | Multi-code recovery set manager with interactive strike-through tracking and smart quick-pasting. |
| **⏳ Health, Expiry & Rotation Alerts** | Configurable expiry presets (`30d`, `90d`, `1y`) with live Vault Health scoring and expiration alerts. |
| **⚡ Quick Access Overlay** | Global `Alt + Space` spotlight overlay to search, view, and inject secrets directly into any active application. |
| **👆 Biometric Windows Hello** | Fingerprint and facial recognition unlock for split-second, zero-friction developer authentication. |
| **🧩 Companion Browser Extension** | Manifest V3 extension for Chrome & Edge that securely saves credentials over local loopback (`127.0.0.1:45454`). |
| **🔄 Encrypted Backups (`.lnk`)** | Password-protected standalone archives to migrate vaults across machines without third-party clouds. |

---

## 🛠️ Deep Dive: The 5 Major Pillars

### 1. Developer Secret Resolver CLI (`locknkey`)

Lock N' Key includes a high-speed, native standalone CLI executable (`locknkey.exe`) designed for automated terminal workflows, task runners, and Docker containers.

#### Available Commands:
```bash
locknkey run <command> [args...]    # Inject LNK: aliases into memory and execute child process
locknkey list                       # List all vault secrets, types, and expiry statuses in a table
locknkey get <alias> [-c, --copy]   # Output secret value to stdout (or copy directly to clipboard)
locknkey set <alias> [value]        # Add or update a secret with masked terminal input
locknkey delete <alias>             # Delete a secret from the vault
locknkey status                     # Check local daemon connectivity and vault lock state
locknkey hook [install|uninstall]   # Install or remove Git pre-commit leak guard in current repository
locknkey scan [--staged]            # Audit repository diffs against your actual vault secrets
```

#### Zero-Plaintext Development Workflow:
Instead of committing plaintext tokens in `.env` files or hardcoding them in scripts, reference secrets using the `LNK:` prefix:

```env
# .env or .env.local
PORT=3000
DATABASE_URL=LNK:postgres_prod
STRIPE_SECRET_KEY=LNK:stripe_test_key
OPENAI_API_KEY=LNK:openai_prod_token
AWS_SECRET_ACCESS_KEY=LNK:aws_deploy_secret
```

Then run your project wrapped with `locknkey run`:
```bash
locknkey run npm start
# or
locknkey run python manage.py runserver
# or
locknkey run docker compose up -d
# or
locknkey run go run main.go
```

**How It Works:**
1. The CLI scans environment variables and the local `.env` file for `LNK:<alias>` placeholders.
2. It queries the local Lock N' Key daemon via `127.0.0.1:45454/secrets/resolve`.
3. If the vault is locked, the desktop app automatically requests biometric or master password authentication.
4. Secrets are injected **directly into the child process's in-memory environment table**.
5. The child process runs with full access to the resolved secrets, while **nothing is ever written to disk or recorded in shell command history**.

---

### 2. Git Leak Guard (Pre-Commit & Active Auditing)

Accidentally pushing an API key or private key to a public GitHub or GitLab repository can lead to catastrophic security breaches within seconds. Lock N' Key provides a built-in, automated defense mechanism:

#### 1-Command Pre-Commit Protection:
Navigate to any git repository and run:
```bash
locknkey hook install
```
This automatically writes an executable `.git/hooks/pre-commit` script configured to query your local vault.

#### How It Works:
Whenever you invoke `git commit`, the hook:
1. Extracts all staged diff additions (`git diff --cached`).
2. Transmits the staged diff to the local daemon endpoint `/secrets/audit/check-leak`.
3. The daemon scans the staged changes against all decrypted values stored in your personal vault.
4. If an exact secret match is detected, the commit is **instantly aborted**:

```text
[Lock N' Key Guard] 🚨 CRITICAL: LEAK DETECTED!
Your staged git commit contains credentials currently stored in your vault:
  ❌ Staged Secret: "STRIPE_SECRET_KEY" (Shortcut: "stripe_prod")

Commit aborted. Remove plaintext secrets from staged files before committing!
💡 Protip: Replace plaintext with 'LNK:stripe_prod' in your .env and run with `locknkey run`.
```

You can also manually audit staged changes at any time by running:
```bash
locknkey scan --staged
```

---

### 3. Encrypted Secret Files & In-Memory Secure Viewer

Modern applications require more than just alphanumeric passwords; developers constantly manage SSL certificates, SSH identities, Kubernetes configs, and cloud service account credentials.

#### Drag-and-Drop Encrypted Storage:
- Attach any file (up to several megabytes) including `.pem`, `.key`, `id_ed25519`, `service-account.json`, `.ovpn`, `.jks`, `.p12`, `.env`, and credential certificates.
- The entire file is encoded and sealed inside your local vault using **AES-256-GCM authenticated encryption**.

#### In-Memory Secure File Viewer (`SecureFileViewerDialog`):
To preserve the zero-trace philosophy, Lock N' Key features an advanced built-in file viewer that renders decrypted assets **strictly within volatile application RAM**:

* 🚫 **Zero Disk Footprint:** Avoids writing temporary decrypted files to `%TEMP%`, preventing disk-recovery attacks.
* 📝 **Code & Config Inspector:** Clean syntax display with **line numbers**, **line-wrapping toggles**, and **one-click copy** for `.json`, `.yaml`, `.xml`, `.env`, `.ovpn`, `.sh`, and `.pem` files.
* ✨ **Auto-Pretty-Printing:** Automatically parses and beautifies minified JSON (e.g. Google Cloud service account keys).
* 🔍 **Real-Time Text Search:** Instant text query search with active term highlighting.
* 🖼️ **Zoomable Image Viewer:** For 2FA recovery QR codes or ID cards (`.png`, `.jpg`, `.webp`), inspect images with interactive pinch-to-zoom and pan via `Image.memory`.
* 🛡️ **Binary Keystore Inspector:** For binaries (`.jks`, `.p12`, `.keystore`), displays verified **SHA-256 integrity checksums** and file dimensions rather than corrupt text dumps.
* 💾 **Guarded Export to Disk:** When external command-line compilers (e.g., Android Gradle builds needing a `.jks` path) require a physical file, users can export with a clear security confirmation prompt.

---

### 4. 2FA Emergency Backup Codes Tracker

When setting up two-factor authentication on GitHub, AWS, Google Cloud, or Stripe, services provide 8–16 emergency one-time recovery codes. If you lose your phone or authenticator app, these codes are your only lifeline.

* **Bulk Code Parser:** Paste raw recovery code sheets directly; the parser automatically splits tokens separated by spaces, newlines, commas, or semicolons.
* **Interactive Strike-Through Tracker:** Click on any code chip to mark it as consumed (`used`). The interface displays timestamps for when each code was used.
* **Depletion Warnings:** Visual indicators alert you when an account has only 1 or 2 backup codes remaining, prompting you to generate a fresh set.
* **Smart Quick-Access Typing:** When you activate a 2FA Backup item from the `Alt + Space` overlay, Lock N' Key **automatically selects and types the first remaining unused code**, then marks it as used.

---

### 5. Secret Health, Expiry & Rotation Alerts

Stale credentials and forgotten access tokens represent significant security debt. Lock N' Key actively monitors credential lifecycles:

* **Rotation Presets:** Assign lifespans during secret creation:
  - `30 Days` (Frequent rotation for staging/test tokens)
  - `90 Days` (Industry standard for database and API keys)
  - `1 Year` (Long-lived SSL/TLS certificates and SSH keys)
  - `Custom Date` (Specific contract or project termination dates)
* **Vault Health Score:** Live calculation on the dashboard grading overall vault hygiene based on expired keys, unrotated tokens, and depleted 2FA backup sets.
* **Expiration Badges & Filter Tabs:**
  - `Active` (Green)
  - `Expiring Soon` (Amber, within 7 days)
  - `Expired` (Red, immediate rotation recommended)
  - Filter your secrets list by category: *All*, *API Keys & Passwords*, *Secret Files*, *2FA Backup Codes*, or *Expiring / Expired*.

---

## ⚡ Quick Access Overlay (`Alt + Space`)

Access your credentials without context-switching away from your code editor or terminal:

1. Press **`Alt + Space`** anywhere in Windows.
2. A lightweight, floating spotlight bar appears instantly over your active window.
3. Start typing the name, shortcut alias (e.g., `openai`), or tag.
4. Press **Enter**: Lock N' Key simulates native OS keyboard events to **type the secret directly into your active input field**.
5. **No Clipboard Traces:** Because the secret is typed directly via OS input synthesis, clipboard-sniffing background utilities cannot intercept your credentials.

---

## 🧩 Companion Browser Extension

For seamless web logins, Lock N' Key includes a Manifest V3 browser extension for Google Chrome, Brave, and Microsoft Edge:

* **Local Loopback Communication:** Connects to the desktop app via `http://127.0.0.1:45454`.
* **Zero Cloud Dependence:** Does not send data to external password management servers.
* **Instant Vault Sync:** Capture newly generated passwords and API keys from web dashboards directly into your desktop vault.
* **Install:** Navigate to `Overview` > `Install Extension` inside the desktop app, or load the unpacked directory [`extension/`](extension/) in `chrome://extensions`.

---

## 🔄 Cross-Device Encrypted Transfer (`.lnk`)

When switching laptops or creating an offline air-gapped backup, Lock N' Key provides self-contained encrypted archives:

* **Export:** Go to `Settings` > `Export Vault` > `Encrypted Backup (.lnk)`. Choose a strong secondary backup passphrase.
* **Encryption:** The backup is encrypted using AES-256-GCM with a newly derived PBKDF2 key (100,000 iterations).
* **Import:** On your new machine, launch Lock N' Key, navigate to `Settings` > `Import Backup`, and enter the passphrase. All secrets, shortcuts, files, and metadata are restored seamlessly.

---

## 📥 Installation & Verification

### Pre-Packaged Windows Setup (v1.0.2)
Download the latest Windows installer directly from the repository:
➡️ **[Download `installers/lock_n_key_setup.exe`](installers/lock_n_key_setup.exe)**

The setup wizard will:
1. Install Lock N' Key into your local program directory.
2. Automatically add the `locknkey` CLI executable to your user `PATH`.
3. Register the optional system startup and tray background daemon.

### SHA-256 Integrity Verification
To verify the installer binary has not been modified or corrupted, run in PowerShell:
```powershell
Get-FileHash .\installers\lock_n_key_setup.exe -Algorithm SHA256
```

**Expected SHA-256 Hash:**
```text
BEE3BBF984604E759F753E16E0710DA21DAEB996D44EFD1E7B542C1409DC837D
```

### Windows Defender SmartScreen Note
Because Lock N' Key is an independent open-source project and not signed with an enterprise EV certificate ($400+/year), Windows Defender SmartScreen may display an *"Unrecognized app"* notice on initial launch:
1. Click **"More info"**.
2. Click **"Run anyway"**.
*(You can verify the source code and compile the binary yourself using the instructions below.)*

---

## 🚀 5-Minute Quickstart Guide

### 1. Initialize Master Vault
Launch Lock N' Key for the first time. Set your **Master Password** and configure recovery security questions. If your device supports Windows Hello (Fingerprint or Face Unlock), enable it for instant unlocking.

### 2. Store Your First Secret or File
- Click **"New Secret"** from the Dashboard or Secrets List.
- Select your secret type: **API Key**, **Password**, **Secret File**, or **2FA Backup Codes**.
- Assign a convenient shortcut alias (e.g. `stripe` or `//stripe`).
- Set an optional rotation expiry preset (e.g., `90 Days`).

### 3. Use in Terminal with CLI
Open PowerShell, CMD, or Git Bash and verify connectivity:
```bash
locknkey status
locknkey list
```

### 4. Enable Git Leak Guard in Your Project
```bash
cd C:\path\to\my-git-project
locknkey hook install
```

---

## 🔒 Security Architecture & Threat Model

| Threat / Attack Vector | Cloud Password Managers | Unencrypted `.env` Files | Lock N' Key Defense |
| :--- | :--- | :--- | :--- |
| **Cloud Database Breach** | ⚠️ Vulnerable if master key or server compromised | N/A | 🛡️ **Immune:** 0% cloud presence; strictly air-gapped offline storage. |
| **Accidental Git Commit** | ⚠️ High risk if developers copy keys into `.env` | ❌ High risk; frequently committed to GitHub | 🛡️ **Protected:** `locknkey hook` detects and aborts commits before they leak. |
| **Clipboard Snooping Malware**| ⚠️ Clipboard history exposed to background sniffers | ⚠️ Exposed when copied | 🛡️ **Protected:** Direct process injection (`locknkey run`) & virtual typing overlay. |
| **Forensic Disk Inspection** | ⚠️ Cache/temp files written to disk | ❌ Stored in plaintext on disk | 🛡️ **Protected:** In-Memory Secure Viewer decodes strictly in RAM (`Uint8List`). |
| **Malicious Network Requests**| ⚠️ Software updates / telemetry can leak metadata | N/A | 🛡️ **Immune:** Desktop app has zero outbound sockets; bound strictly to loopback. |

### Technical Specifications:
* **Cipher:** AES-256-GCM (Authenticated Encryption with Associated Data).
* **Key Derivation:** PBKDF2 with SHA-256, 100,000 rounds, unique cryptographic salt.
* **Local Daemon IPC:** Loopback HTTP (`127.0.0.1:45454`) with strict CORS origin verification and biometric challenge authorization.
* **Process Memory Lifespan:** Plaintext values reside solely in process memory during active usage and are cleared upon garbage collection or vault lock.

---

## 🏗️ Building from Source

### Prerequisites
* Windows 10 or 11 (64-bit)
* [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (v3.10.4 or higher)
* Visual Studio 2022 with **"Desktop development with C++"** workload
* [Inno Setup 6+](https://jrsoftware.org/isdl.php) (optional, for compiling the installer)

### Build Commands:
```powershell
# 1. Clone repository
git clone https://github.com/rtk007/Lock_N-_Key.git
cd Lock_N-_Key

# 2. Install dependencies
flutter pub get

# 3. Run in desktop debug mode
flutter run -d windows

# 4. Build release desktop application
flutter build windows --release

# 5. Compile native CLI binary
dart compile exe bin/locknkey.dart -o build/windows/x64/runner/Release/locknkey.exe

# 6. Build Inno Setup installer
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installers/lock_n_key.iss
```

The compiled installer will be available at [`installers/lock_n_key_setup.exe`](installers/lock_n_key_setup.exe).

---

## 👤 Author & License

**Created and Developed by:**  
**Ratik Krishna**  
* GitHub: [@rtk007](https://github.com/rtk007)  
* Repository: [Lock_N-_Key](https://github.com/rtk007/Lock_N-_Key)

*Distributed under the MIT Open Source License. Designed for developers who value absolute privacy and offline security.*
