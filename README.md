# Minecraft Java Auto-Installer

This script provides an automated installation process for multiple Java versions on Debian-based Linux systems, optimized for running Minecraft servers. You can install several JDKs side by side and choose which one is used system-wide (`java`, `javac`, `JAVA_HOME`, `PATH`).

**Author:** JOTIBI, Cursor AI
*(Yes, I used AI, but I don't care because if something gets the job done for you, it doesn't matter whether AI wrote the code or not.)*

---

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/I3I61SOC0C)

## Features

- Interactive main menu: install, set default Java, show status, exit
- Interactive selection of Java versions to install (multi-select)
- Supports Java **8** and **25** (Temurin/Adoptium, manual install to `/opt`) and Java **11**, **17**, **21** (OpenJDK via APT)
- Skips versions that are already registered in `update-alternatives`
- **Set system-wide default Java** without installing anything new (menu option 2 or `--set-default`)
- Writes `JAVA_HOME` and `PATH` to `/etc/profile.d/minecraft-java.sh`
- Registers OpenJDK packages with `update-alternatives` after APT install
- Checks for required tools (`curl`, `sudo`, `tar`, `update-alternatives`, etc.)
- Optional logging of all output to `install_java.log` (`--log`)
- Displays installed Java versions with active default marked (★)
- CLI mode for automation (`--install`, `--yes`, `--default`, `--status`)

## Supported Java Versions

| Option | Java Version | Source              | Minecraft Version Range   |
|--------|--------------|---------------------|---------------------------|
| 1      | Java 8       | Adoptium → `/opt/java-8`  | Minecraft 1.8 – 1.16.x    |
| 2      | Java 11      | `openjdk-11-jdk`    | Minecraft 1.17 – 1.18.x   |
| 3      | Java 17      | `openjdk-17-jdk`    | Minecraft 1.18.2 – 1.20.4 |
| 4      | Java 21      | `openjdk-21-jdk`    | Minecraft 1.20.5 – 1.21.x   |
| 5      | Java 25      | Adoptium → `/opt/java-25` | Newer / future versions, testing |

Extra symlinks: `/usr/local/bin/java8`, `/usr/local/bin/java25`

## Requirements

- Debian/Ubuntu-based system (with `apt` or `apt-get`)
- Shell access with `sudo` privileges
- Internet access
- x64 Linux

## How to Use

1. Download the script: `Java.sh`
2. Make it executable:

   ```bash
   chmod +x Java.sh
   ```

3. Run the script:

   ```bash
   ./Java.sh
   ```

4. Follow the on-screen menu:

   | Choice | Action                                      |
   |--------|---------------------------------------------|
   | 1      | Install Java version(s)                     |
   | 2      | Set system-wide default Java (PATH / JAVA_HOME) |
   | 3      | Show installed versions                     |
   | 4      | Exit                                        |

5. After installation you can optionally set the system-wide default Java immediately.

**Reload `JAVA_HOME` in an existing shell:**

```bash
source /etc/profile.d/minecraft-java.sh
```

## Command-line options

```bash
./Java.sh [OPTIONS]
```

| Option            | Description                                      |
|-------------------|--------------------------------------------------|
| `--help`, `-h`    | Show help                                        |
| `--log`           | Log output to `install_java.log`                 |
| `--yes`, `-y`     | Skip confirmations                               |
| `--install 1 3 5` | Install versions 1–5 without menu                |
| `--set-default`   | Choose default Java only (interactive)           |
| `--default N`     | Default by list index                            |
| `--status`        | Show installed versions and exit                 |

Examples:

```bash
./Java.sh --install 4 --yes
./Java.sh --set-default
./Java.sh --install 3 --yes --default 2
./Java.sh --status
```

## Optional Logging

To log all output to `install_java.log`, run:

```bash
./Java.sh --log
```

Combine with other options, e.g. `./Java.sh --log --install 1 5 --yes`

## License

Copyright (c) 2026 JOTIBI

Permission is hereby granted to use this software on any Minecraft server
(private or public) and within modpacks.

The following conditions apply:

1. This software may NOT be sold, sublicensed, or monetized in any way,
   either alone or as part of a bundle.

2. Modification of the software is permitted for own server operation,
   including public servers.

3. Modified versions may NOT be published, distributed, uploaded, or
   shared in any form.

4. Redistribution of the original software is NOT permitted.

5. When this software is used in modpacks, visible credit to the original
   author must be provided (e.g. in the modpack listing, description,
   or a README file).

6. This copyright and license notice must not be removed or altered.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED.
