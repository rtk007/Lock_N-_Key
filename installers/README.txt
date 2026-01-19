# How to Build the Installer

1.  **Build Release**:
    Open a terminal in the `d:\lock_n_key` directory and run:
    ```
    flutter build windows --release
    ```

2.  **Download Inno Setup**:
    If you haven't already, download and install Inno Setup from:
    [https://jrsoftware.org/isdl.php](https://jrsoftware.org/isdl.php)

3.  **Compile Script**:
    -   Double-click `d:\lock_n_key\installers\lock_n_key.iss`.
    -   In Inno Setup, click the **Build** menu -> **Compile** (or press Ctrl+F9).

4.  **Result**:
    The installer `lock_n_key_setup.exe` will be created in `d:\lock_n_key\installers`.
