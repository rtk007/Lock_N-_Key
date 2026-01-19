# Lock N' Key: The Developer's Vault

![Lock N' Key Logo](assets/images/logo.png)

**The vault that never connects.**

Lock N' Key is a developer-first password manager built with a radical approach: **Zero Trust Networking**. We store your data exclusively on your machine, encrypted with AES-256-GCM. No "sync servers", no "master keys" on our end, and absolutely no outgoing internet requests from the core vault.

It's the digital equivalent of a physical safe in your home office.

---

## The Intuition

Every time you paste an API key, you’re taking a risk. Cloud-based password managers are convenient, but they are also massive targets for hackers.

I built Lock N' Key because I was tired of wondering if my clipboard manager was sending my API keys to the cloud. This tool is my answer to the balance between extreme security and developer velocity.

**Core Philosophy:**
*   **Local-Only:** No data ever leaves your device.
*   **0% Trust:** We don't ask you to trust our servers, because we don't have any.
*   **Developer Velocity:** Access your secrets without breaking flow.

---

## Features

*   **🔒 Ironclad & Offline:** AES-256 encryption with a locally managed key. No external servers. Your vault file is portable and yours to control.
*   **⚡ Instant Global Search:** Hit `Alt + Space` to trigger the Quick Access bar. Find and paste secrets into any IDE without lifting your fingers from the keyboard.
*   **👆 Biometric Unlocking:** Native Windows Hello support. Authenticate with your fingerprint or face login for split-second access.
*   **🔄 Cross-Device:** Securely transfer your vault between devices using our encrypted `.lnk` backup format.
*   **🧩 Browser Extension:** Seamlessly save credentials from your browser (Chrome/Edge) directly to your local vault.

---

## Installation

This repository contains the Windows installer.

1.  Navigate to the `installers` folder in this repository.
2.  Locate `lock_n_key_setup.exe`.
3.  Run the installer and follow the on-screen instructions.
4.  Once installed, launch **Lock N' Key** from your desktop or start menu.

> **Note:** Since this is a self-signed application, Windows SmartScreen may prompt a warning. This is expected for new open-source software not signed by a major certificate authority. You can safely proceed by clicking "More Info" > "Run Anyway".

---

## How to Use

### 1. Setup Master Password
On first launch, you will be asked to create a **Master Password**. This password encrypts your vault.
*   **Warning:** There is no "Forgot Password" link. If you lose this password, your data is lost forever. We cannot recover it for you.

### 2. Dashboard & Adding Secrets
*   Use the **Dashboard** to view your secrets.
*   Click **"Add Secret"** to store a new credential (API Key, Database URL, Password, etc.).
*   Assign names and optional shortcuts for easy retrieval.

### 3. Quick Access (The Power Move)
*   Press **`Alt + Space`** anywhere in Windows to open the Quick Access bar.
*   Type the name of your secret.
*   Press **Enter** to copy it to your clipboard (or auto-paste if configured).
*   Use Biometrics (Fingerprint) to authenticate the action instantly.

### 4. Browser Extension
To install the companion extension:
1.  Go to `Settings` > `Extension` in the desktop app.
2.  Follow the instructions to load the extension in functionality in Chrome/Edge Developer Mode.

---

## Cross-Device Restoration (.lnk)

Lock N' Key allows you to securely transfer your vault between devices using our encrypted `.lnk` backup format.

### How to Transfer
1.  **Export:** On your source machine, go to `Settings` > `Export Vault` > `Encrypted Backup (.lnk)`.
2.  **Encrypt:** You will be asked to set a **Backup Password**. This is separate from your Master Password and is required to decrypt the file on the new machine.
3.  **Transfer:** Move the generated `.lnk` file to your new machine (via USB, Cloud, etc.). The file is AES-256 encrypted, so it is safe to transfer.
4.  **Import:** On your new machine, go to `Settings` > `Import Backup` and select the file. Enter the **Backup Password** to restore your secrets.


---

## About the Creator

**Ratik Krishna** - Lead Developer & Security Enthusiast

Built with ❤️ using Flutter Desktop.
