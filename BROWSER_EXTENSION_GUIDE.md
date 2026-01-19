# Browser Extension Architecture for "Lock N' Key"

Creating a browser extension for a secure desktop password manager requires a specific architecture to ensure communication between the isolated Browser environment and the Desktop application.

## 1. The Core Components
A modern (Manifest V3) extension consists of:

*   **`manifest.json`**: The configuration file (permissions, version, entry points).
*   **`background.js`** (Service Worker): Handles events and runs in the background.
*   **`content.js`**: JavaScript that runs *inside* web pages (to read URL, find username/password fields, and inject values).
*   **`popup.html` / `popup.js`**: The UI when you click the extension icon.

## 2. Connecting to Desktop (The Hard Part)
Browser extensions **cannot** directly read files or generic TCP ports (usually blocked or insecure). To talk to "Lock N' Key" (Flutter Desktop), we must use **Native Messaging**.

### How Native Messaging Works
1.  **Registry Key**: You must add a Registry Entry (Windows) telling Chrome/Edge where your "Native Host" executable is.
2.  **Native Host**: A lightweight executable (C++, Rust, or C#) that reads from `stdin` and writes to `stdout`.
    *   *Chrome starts this process automatically when the extension sends a message.*
3.  **Communication Chain**:
    `Extension` -> `Native Host` -> `Lock N' Key Flutter App`

### Integration Flow
1.  **User visits `google.com`**.
2.  **Extension** detects URL.
3.  **Extension** asks **Native Host**: "Do we have credentials for google.com?"
4.  **Native Host** asks **Flutter App** (via IPC/Named Pipe).
5.  **Flutter App** checks DB (and might prompt Biometric Auth on desktop).
6.  **Flutter App** returns credentials (encrypted or plaintext depending on security model) to Native Host.
7.  **Native Host** sends to **Extension**.
8.  **Extension** autofills the inputs.

## 3. Comparison with Current Solution

| Feature | **Keystroke Injection** (Current) | **Browser Extension** (Proposed) |
| :--- | :--- | :--- |
| **Security** | **High** (No Clipboard, No DOM access) | **Medium** (Vulnerable to DOM XSS) |
| **Universal?** | **Yes** (Works in VS Code, Notepad, Terminal) | **No** (Browser only) |
| **Autofill?** | Manual (User searches & selects) | **Automatic** (Can detect URL) |
| **Complexity** | Low (Single App) | **High** (App + Host + Ext + Registry) |

## 4. "Hello World" Steps (If you want to build one)

1.  Create `manifest.json`:
    ```json
    {
      "name": "Lock N Key Ext",
      "version": "1.0",
      "manifest_version": 3,
      "permissions": ["activeTab", "scripting"],
      "action": { "default_popup": "popup.html" }
    }
    ```
2.  Load Unpacked in `chrome://extensions`.
