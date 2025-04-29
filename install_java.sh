#!/bin/bash

# ========== START SCREEN ========== #
clear
cat << "EOF"
  __  __  _____     _                  _____           _        _ _           
 |  \/  |/ ____|   | |                |_   _|         | |      | | |          
 | \  / | |        | | __ ___   ____ _  | |  _ __  ___| |_ __ _| | | ___ _ __ 
 | |\/| | |    _   | |/ _` \ \ / / _` | | | | '_ \/ __| __/ _` | | |/ _ \ '__|
 | |  | | |___| |__| | (_| |\ V / (_| |_| |_| | | \__ \ || (_| | | |  __/ |   
 |_|  |_|\_____|\____/ \__,_| \_/ \__,_|_____|_| |_|___/\__\__,_|_|_|\___|_|   
                                                                              
==== Minecraft Java Auto-Installer - Created by JOTIBI ====
EOF

# ========== LOGGING ==========
LOGGING=false
LOG_FILE="install_java.log"
LOG_OPENED=false

if [[ "$1" == "--log" ]]; then
  LOGGING=true
  LOG_OPENED=true
  echo "📝 Logging enabled. All outputs will be saved in $LOG_FILE."
  echo "==== Log started at $(date) ====" > "$LOG_FILE"
fi

log() {
  if [ "$LOGGING" = true ]; then
    echo -e "$1" | tee -a "$LOG_FILE"
  else
    echo -e "$1"
  fi
}

# ========== PREREQUISITES ==========
REQUIRED_CMDS=(curl sudo tar)
MISSING=()

for CMD in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$CMD" &>/dev/null; then
    MISSING+=("$CMD")
  fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
  log "❌ Missing required tools: ${MISSING[*]}"
  read -p "Do you want to install them now? (y/n): " INSTALL_CHOICE
  INSTALL_CHOICE=${INSTALL_CHOICE:-n}
  if [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then
    sudo apt update && sudo apt install -y "${MISSING[@]}"
  else
    log "Please install them manually and rerun the script."
    exit 1
  fi
fi




JAVA_8_MANUAL_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u402-b06/OpenJDK8U-jdk_x64_linux_hotspot_8u402b06.tar.gz"
JAVA_8_DIR="/opt/java-8"
JAVA_8_BIN="$JAVA_8_DIR/bin/java"

# ========== SELECT JAVA VERSIONS ==========
AVAILABLE_OPTIONS=()
log "\nSelect the Java versions you want to install (multiple selection possible, separated by space):"

if ! update-alternatives --list java 2>/dev/null | grep -q "$JAVA_8_BIN"; then
  AVAILABLE_OPTIONS+=(1)
  log "1) Java 8     – For Minecraft 1.8 to 1.16.x"
fi
if ! update-alternatives --list java 2>/dev/null | grep -q "/usr/lib/jvm/java-11-openjdk"; then
  AVAILABLE_OPTIONS+=(2)
  log "2) Java 11    – For Minecraft 1.17 to 1.18.x"
fi
if ! update-alternatives --list java 2>/dev/null | grep -q "/usr/lib/jvm/java-17-openjdk"; then
  AVAILABLE_OPTIONS+=(3)
  log "3) Java 17    – For Minecraft 1.18.2 to 1.20.4"
fi
if ! update-alternatives --list java 2>/dev/null | grep -q "/usr/lib/jvm/java-19-openjdk"; then
  AVAILABLE_OPTIONS+=(4)
  log "4) Java 19    – Experimental (e.g. Snapshots)"
fi
if ! update-alternatives --list java 2>/dev/null | grep -q "/usr/lib/jvm/default-java"; then
  AVAILABLE_OPTIONS+=(5)
  log "5) Latest     – For future versions (e.g. 1.21+)"
fi

if [ ${#AVAILABLE_OPTIONS[@]} -eq 0 ]; then
  log "✅ All Java versions are already installed."
  exit 0
fi

read -p "Which versions to install? (e.g., ${AVAILABLE_OPTIONS[*]}): " JAVA_CHOICES
JAVA_CHOICES=$(echo "$JAVA_CHOICES" | tr ' ' '\n' | sort -u | tr '\n' ' ')

declare -A JAVA_MAP=(
  [1]="openjdk-8-jdk"
  [2]="openjdk-11-jdk"
  [3]="openjdk-17-jdk"
  [4]="openjdk-19-jdk"
  [5]="default-jdk"
)

SELECTED_PACKAGES=()
for CHOICE in $JAVA_CHOICES; do
  if [[ -n "${JAVA_MAP[$CHOICE]}" ]]; then
    SELECTED_PACKAGES+=("${JAVA_MAP[$CHOICE]}")
  else
    log "⚠️  Invalid choice: $CHOICE"
  fi
done

if [ ${#SELECTED_PACKAGES[@]} -eq 0 ]; then
  log "❌ No valid Java versions selected. Exiting."
  exit 1
fi

log "\n➡️  Selected packages: ${SELECTED_PACKAGES[*]}"
read -p "Do you want to start installation? (y/n): " CONFIRM
CONFIRM=${CONFIRM:-n}

INSTALLED_LIST=()
FAILED_LIST=()

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  log "\n📦 Starting installation..."
  sudo apt update 2>&1 | tee -a "$LOG_FILE"
  for PACKAGE in "${SELECTED_PACKAGES[@]}"; do
    log "\n🔧 Installing $PACKAGE ..."
    if [[ "$PACKAGE" == "openjdk-8-jdk" ]]; then
      if [ -f "$JAVA_8_BIN" ]; then
        log "ℹ️  Java 8 already exists – skipping manual installation."
        INSTALLED_LIST+=("$PACKAGE (already exists)")
      else
        log "⚠️  $PACKAGE not available via apt. Performing manual installation..."
        mkdir -p "$JAVA_8_DIR"
        if ! curl -L "$JAVA_8_MANUAL_URL" -o /tmp/java8.tar.gz 2>&1 | tee -a "$LOG_FILE"; then
          log "❌ Failed to download Java 8. Check your internet connection or URL."
          FAILED_LIST+=("$PACKAGE")
          continue
        fi
        if ! tar -xzf /tmp/java8.tar.gz -C "$JAVA_8_DIR" --strip-components=1; then
          log "❌ Failed to extract Java 8."
          FAILED_LIST+=("$PACKAGE")
          continue
        fi
        if [ -f "$JAVA_8_BIN" ]; then
          ln -sf "$JAVA_8_BIN" /usr/local/bin/java8
          if ! update-alternatives --list java 2>/dev/null | grep -q "$JAVA_8_BIN"; then
            sudo update-alternatives --install /usr/bin/java java "$JAVA_8_BIN" 1080
            sudo update-alternatives --install /usr/bin/javac javac "$JAVA_8_DIR/bin/javac" 1080
          fi
          INSTALLED_LIST+=("$PACKAGE (manually installed)")
        else
          log "❌ Java 8 installation failed."
          FAILED_LIST+=("$PACKAGE")
        fi
      fi
    elif sudo apt install -y "$PACKAGE" 2>&1 | tee -a "$LOG_FILE"; then
      log "✅ $PACKAGE installed successfully."
      INSTALLED_LIST+=("$PACKAGE")
    else
      log "❌ $PACKAGE could not be installed."
      FAILED_LIST+=("$PACKAGE")
    fi
  done
else
  log "❌ Installation aborted."
  exit 0
fi

# ========== JAVA INSTALLATION CHECK ==========
if [ ${#FAILED_LIST[@]} -eq 0 ] && [ ${#INSTALLED_LIST[@]} -gt 0 ]; then
  JAVA_PATH=$(command -v java)
  JAVA_VERSION_STR=$($JAVA_PATH -version 2>&1 | head -n 1)

  log "
✅ All selected Java versions installed successfully!"
  log "Path: $JAVA_PATH"
  log "Version: $JAVA_VERSION_STR"
else
  log "
⚠️ Some Java packages failed to install: ${FAILED_LIST[*]}"
  if [ ${#INSTALLED_LIST[@]} -eq 0 ]; then
    log "❌ No Java version was installed. Exiting."
    exit 1
  fi
fi

# ========== SET DEFAULT JAVA VERSION ==========
AVAILABLE_JAVAS=$(update-alternatives --list java 2>/dev/null)
AVAILABLE_JAVACS=$(update-alternatives --list javac 2>/dev/null)

log "
📋 Current default Java versions:"
CURRENT_JAVA=$(readlink -f $(which java) 2>/dev/null)
CURRENT_JAVAC=$(readlink -f $(which javac) 2>/dev/null)
log "java  →  $CURRENT_JAVA"
log "javac →  $CURRENT_JAVAC"

if [ -n "$AVAILABLE_JAVAS" ]; then
  log "
Available Java alternatives:"
  IFS=$'
'; JAVA_ARRAY=($AVAILABLE_JAVAS)
  for i in "${!JAVA_ARRAY[@]}"; do
    log "$((i+1))) ${JAVA_ARRAY[$i]}"
  done
  unset IFS

  while true; do
    read -p "Which version should be the default for 'java'? (1-${#JAVA_ARRAY[@]}, or 's' to skip): " JAVA_DEFAULT
    if [[ "$JAVA_DEFAULT" == "s" ]]; then
      log "⏭️ Skipped setting default for 'java'."
      break
    fi
    JAVA_INDEX=$((JAVA_DEFAULT-1))
    if [[ "$JAVA_DEFAULT" =~ ^[0-9]+$ ]] && [ -n "${JAVA_ARRAY[$JAVA_INDEX]}" ]; then
      sudo update-alternatives --set java "${JAVA_ARRAY[$JAVA_INDEX]}"
      log "➡️ Default 'java' set to: ${JAVA_ARRAY[$JAVA_INDEX]}"
      break
    else
      log "❌ Invalid choice. Please try again."
    fi
  done
fi

if [ -n "$AVAILABLE_JAVACS" ]; then
  log "
Available Javac alternatives:"
  IFS=$'
'; JAVAC_ARRAY=($AVAILABLE_JAVACS)
  for i in "${!JAVAC_ARRAY[@]}"; do
    log "$((i+1))) ${JAVAC_ARRAY[$i]}"
  done
  unset IFS

  while true; do
    read -p "Which version should be the default for 'javac'? (1-${#JAVAC_ARRAY[@]}, or 's' to skip): " JAVAC_DEFAULT
    if [[ "$JAVAC_DEFAULT" == "s" ]]; then
      log "⏭️ Skipped setting default for 'javac'."
      break
    fi
    JAVAC_INDEX=$((JAVAC_DEFAULT-1))
    if [[ "$JAVAC_DEFAULT" =~ ^[0-9]+$ ]] && [ -n "${JAVAC_ARRAY[$JAVAC_INDEX]}" ]; then
      sudo update-alternatives --set javac "${JAVAC_ARRAY[$JAVAC_INDEX]}"
      log "➡️ Default 'javac' set to: ${JAVAC_ARRAY[$JAVAC_INDEX]}"
      break
    else
      log "❌ Invalid choice. Please try again."
    fi
  done
fi

# ========== LIST INSTALLED JAVA VERSIONS ==========
log "
📦 Installed Java versions (java -version):"
for JAVA_BIN in $(update-alternatives --list java 2>/dev/null); do
  VERSION_OUTPUT=$($JAVA_BIN -version 2>&1 | head -n 1)
  log "- $JAVA_BIN → $VERSION_OUTPUT"
  done

# ========== LOG FINISH ==========
if [ "$LOGGING" = true ] && [ "$LOG_OPENED" = true ]; then
  echo -e "
==== Log finished at $(date) ====" >> "$LOG_FILE"
  log "📝 Log file saved: $LOG_FILE"
fi

log "====================================="
