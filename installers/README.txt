# How to Build the Installer

1. Build Release:
   Open a terminal in the root project directory and run:
   ```powershell
   flutter build windows --release
   dart compile exe bin/locknkey.dart -o build/windows/x64/runner/Release/locknkey.exe
   ```

2. Download Inno Setup:
   Download and install Inno Setup 6+ from:
   https://jrsoftware.org/isdl.php

3. Visual C++ Redistributable:
   Ensure `VC_redist.x64.exe` is present in this `installers` folder (bundled for end users).

4. Compile Installer:
   - Open `installers/lock_n_key.iss` in Inno Setup Compiler.
   - Click "Build" -> "Compile" (or press Ctrl+F9).
   - The compiled installer `lock_n_key_setup.exe` will be generated in this directory.

