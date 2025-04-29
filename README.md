# Minecraft Java Auto-Installer (by JOTIBI)

This Bash script installs one or more Java versions for your Minecraft server.
It automatically detects already installed versions and lets you select and manage the versions you want.

---

## ✨ Features
- Install the following Java versions:
  - Java 8 (manual installation from Adoptium)
  - Java 11, 17, 19, default (via apt)
- Prevents duplicate installations
- Set default version for `java` and `javac`
- List all installed Java versions
- Optional logging

---

## ⚡ Usage

1. Make the script executable:
```bash
chmod +x install_java.sh
```

2. Start it:
```bash
./install_java.sh           # without logging
./install_java.sh --log     # with logging to install_java.log
```

3. Choose the Java version(s) you want to install (e.g. `1 3 5` for Java 8, 17, latest).

4. The script automatically detects if a version is already installed.

5. At the end, you can set the default version for `java` and `javac`.

---

## ✅ Requirements
- Debian/Ubuntu system
- Root or sudo access
- Internet connection

The following tools must be available (will be checked):
- `curl`, `tar`, `sudo`

---

## 📝 Notes
- Java 8 is downloaded manually from Adoptium since it's often missing from modern repositories.
- All versions are registered using `update-alternatives`.
- You can manually switch between installed versions using:
```bash
sudo update-alternatives --config java
```

---

## 📦 Example Output
```
➡️  Selected packages: openjdk-17-jdk
✅ openjdk-17-jdk installed successfully.
➡️  Default Java version set to: /usr/lib/jvm/java-17-openjdk/bin/java
📦 Installed Java versions:
- /usr/lib/jvm/java-17-openjdk/bin/java → openjdk version "17.0.9" ...
```

---

## License
This project is licensed under the CC BY-NC 4.0 License.

