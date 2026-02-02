#!/bin/bash

# ========== STARTBILD ========== #
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
  echo "📝 Logging aktiviert. Alle Ausgaben werden in $LOG_FILE geschrieben."
  echo "==== Log gestartet am $(date) ====" > "$LOG_FILE"
fi

log() {
  if [ "$LOGGING" = true ]; then
    echo -e "$1" | tee -a "$LOG_FILE"
  else
    echo -e "$1"
  fi
}

# ========== PRÜFUNGEN ==========
REQUIRED_CMDS=(curl sudo tar)
MISSING=()

for CMD in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$CMD" &>/dev/null; then
    MISSING+=("$CMD")
  fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
  log "❌ Fehlende Programme: ${MISSING[*]}"
  log "Bitte installiere sie und starte das Script neu."
  exit 1
fi

JAVA_8_MANUAL_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u402-b06/OpenJDK8U-jdk_x64_linux_hotspot_8u402b06.tar.gz"
JAVA_8_DIR="/opt/java-8"
JAVA_8_BIN="$JAVA_8_DIR/bin/java"

# ========== JAVA-VERSIONEN AUSWÄHLEN ==========
AVAILABLE_OPTIONS=()
log "
Gib die gewünschten Java-Versionen (Mehrfachauswahl möglich) durch Leerzeichen getrennt ein:"

if ! update-alternatives --list java 2>/dev/null | grep -q "$JAVA_8_BIN"; then
  AVAILABLE_OPTIONS+=(1)
  log "1) Java 8     – Für Minecraft 1.8 bis 1.16.x"
fi
if ! update-alternatives --list java 2>/dev/null | grep -q "/usr/lib/jvm/java-11-openjdk"; then
  AVAILABLE_OPTIONS+=(2)
  log "2) Java 11    – Für Minecraft 1.17 bis 1.18.x"
fi
if ! update-alternatives --list java 2>/dev/null | grep -q "/usr/lib/jvm/java-17-openjdk"; then
  AVAILABLE_OPTIONS+=(3)
  log "3) Java 17    – Für Minecraft 1.18.2 bis 1.20.4"
fi
if ! update-alternatives --list java 2>/dev/null | grep -q "/usr/lib/jvm/java-19-openjdk"; then
  AVAILABLE_OPTIONS+=(4)
  log "4) Java 19    – Experimentell (z. B. Snapshots)"
fi
if ! update-alternatives --list java 2>/dev/null | grep -q "/usr/lib/jvm/default-java"; then
  AVAILABLE_OPTIONS+=(5)
  log "5) Neueste    – Für zukünftige Versionen (z. B. 1.21+)"
fi

if [ ${#AVAILABLE_OPTIONS[@]} -eq 0 ]; then
  log "✅ Alle Java-Versionen sind bereits installiert."
  exit 0
fi

read -p "Welche Version(en) installieren? (z. B. ${AVAILABLE_OPTIONS[*]}): " JAVA_CHOICES
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
    log "⚠️  Ungültige Eingabe: $CHOICE"
  fi
done

if [ ${#SELECTED_PACKAGES[@]} -eq 0 ]; then
  log "❌ Keine gültige Java-Version gewählt. Beende."
  exit 1
fi

log "\n➡️  Gewählte Pakete: ${SELECTED_PACKAGES[*]}"
read -p "Möchtest du die Installation starten? (y/n): " CONFIRM
CONFIRM=${CONFIRM:-n}

INSTALLED_LIST=()
FAILED_LIST=()

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  log "\n📦 Starte Installation..."
  sudo apt update 2>&1 | tee -a "$LOG_FILE"
  for PACKAGE in "${SELECTED_PACKAGES[@]}"; do
    log "\n🔧 Installiere $PACKAGE ..."
    if [[ "$PACKAGE" == "openjdk-8-jdk" ]]; then
      if [ -f "$JAVA_8_BIN" ]; then
        log "ℹ️  Java 8 ist bereits vorhanden – überspringe manuelle Installation."
        INSTALLED_LIST+=("$PACKAGE (bereits vorhanden)")
      else
        log "⚠️  Paket $PACKAGE nicht verfügbar. Führe manuelle Installation durch..."
        mkdir -p "$JAVA_8_DIR"
        if ! curl -L "$JAVA_8_MANUAL_URL" -o /tmp/java8.tar.gz 2>&1 | tee -a "$LOG_FILE"; then
          log "❌ Fehler beim Herunterladen von Java 8."
          FAILED_LIST+=("$PACKAGE")
          continue
        fi
        if ! tar -xzf /tmp/java8.tar.gz -C "$JAVA_8_DIR" --strip-components=1; then
          log "❌ Fehler beim Entpacken von Java 8."
          FAILED_LIST+=("$PACKAGE")
          continue
        fi
        if [ -f "$JAVA_8_BIN" ]; then
          ln -sf "$JAVA_8_BIN" /usr/local/bin/java8
          if ! update-alternatives --list java | grep -q "$JAVA_8_BIN"; then
            sudo update-alternatives --install /usr/bin/java java "$JAVA_8_BIN" 1080
            sudo update-alternatives --install /usr/bin/javac javac "$JAVA_8_DIR/bin/javac" 1080
          fi
          INSTALLED_LIST+=("$PACKAGE (manuell installiert)")
        else
          log "❌ Fehler bei Java 8 Installation."
          FAILED_LIST+=("$PACKAGE")
        fi
      fi
    elif sudo apt install -y "$PACKAGE" 2>&1 | tee -a "$LOG_FILE"; then
      log "✅ $PACKAGE erfolgreich installiert."
      INSTALLED_LIST+=("$PACKAGE")
    else
      log "❌ $PACKAGE konnte nicht installiert werden."
      FAILED_LIST+=("$PACKAGE")
    fi
  done
else
  log "❌ Installation abgebrochen."
  exit 0
fi

# ========== JAVA-VERSION TEST ==========
if [ ${#FAILED_LIST[@]} -eq 0 ] && [ ${#INSTALLED_LIST[@]} -gt 0 ]; then
  JAVA_PATH=$(command -v java)
  JAVA_VERSION_STR=$($JAVA_PATH -version 2>&1 | head -n 1)

  log "\n✅ Alle Java-Versionen installiert!"
  log "Pfad: $JAVA_PATH"
  log "Version: $JAVA_VERSION_STR"
else
  log "\n⚠️  Fehler bei: ${FAILED_LIST[*]}"
  if [ ${#INSTALLED_LIST[@]} -gt 0 ]; then
    JAVA_PATH=$(command -v java)
    JAVA_VERSION_STR=$($JAVA_PATH -version 2>&1 | head -n 1)
    log "\n✅ Installiert: ${INSTALLED_LIST[*]}"
    log "Pfad: $JAVA_PATH"
    log "Version: $JAVA_VERSION_STR"
  else
    log "❌ Keine Version installiert. Beende."
    exit 1
  fi
fi

# ========== DEFAULT-VERSION FESTLEGEN ==========
log "\n📋 Aktuell gesetzte Versionen:"
CURRENT_JAVA=$(readlink -f $(which java))
CURRENT_JAVAC=$(readlink -f $(which javac))
log "java  →  $CURRENT_JAVA"
log "javac →  $CURRENT_JAVAC"

AVAILABLE_JAVAS=$(update-alternatives --list java)
IFS=$'\n' read -rd '' -a JAVA_ARRAY <<<"$AVAILABLE_JAVAS"
if [ ${#JAVA_ARRAY[@]} -gt 0 ]; then
  for i in "${!JAVA_ARRAY[@]}"; do
    log "$((i+1))) ${JAVA_ARRAY[$i]}"
  done
  while true; do
    read -p "Standard für 'java'? (1-${#JAVA_ARRAY[@]}, s = überspringen): " JAVA_DEFAULT
    [[ "$JAVA_DEFAULT" == "s" ]] && break
    JAVA_INDEX=$((JAVA_DEFAULT - 1))
    if [[ "$JAVA_DEFAULT" =~ ^[0-9]+$ ]] && [ "${JAVA_ARRAY[$JAVA_INDEX]}" ]; then
      sudo update-alternatives --set java "${JAVA_ARRAY[$JAVA_INDEX]}"
      break
    fi
  done
fi

# ========== FERTIG ==========
log "\n✅ Fertig! Java wurde installiert und eingerichtet."
