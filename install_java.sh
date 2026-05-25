#!/bin/bash

# Minecraft Java Auto-Installer – Created by JOTIBI
# Debian/Ubuntu: install JDKs, update-alternatives, system-wide JAVA_HOME/PATH

set -uo pipefail

# ========== CONFIGURATION ==========
readonly JAVA_8_DIR="/opt/java-8"
readonly JAVA_8_BIN="$JAVA_8_DIR/bin/java"
readonly JAVA_8_URL="https://api.adoptium.net/v3/binary/latest/8/ga/linux/x64/jdk/hotspot/normal/eclipse"

readonly JAVA_25_DIR="/opt/java-25"
readonly JAVA_25_BIN="$JAVA_25_DIR/bin/java"
readonly JAVA_25_URL="https://api.adoptium.net/v3/binary/latest/25/ga/linux/x64/jdk/hotspot/normal/eclipse"

readonly JAVA_HOME_PROFILE="/etc/profile.d/minecraft-java.sh"
readonly LOG_FILE="install_java.log"

JAVA11_CANDIDATES=(
  "/usr/lib/jvm/java-11-openjdk-amd64/bin/java"
  "/usr/lib/jvm/java-11-openjdk/bin/java"
)
JAVA17_CANDIDATES=(
  "/usr/lib/jvm/java-17-openjdk-amd64/bin/java"
  "/usr/lib/jvm/java-17-openjdk/bin/java"
)
JAVA21_CANDIDATES=(
  "/usr/lib/jvm/java-21-openjdk-amd64/bin/java"
  "/usr/lib/jvm/java-21-openjdk/bin/java"
)

declare -A JAVA_MAP=(
  [1]="java8_manual"
  [2]="openjdk-11-jdk"
  [3]="openjdk-17-jdk"
  [4]="openjdk-21-jdk"
  [5]="java25_manual"
)

LOGGING=false
AUTO_YES=false
ACTION=""
CLI_INSTALL_CHOICES=()
CLI_DEFAULT_INDEX=""

# ========== UI ==========
show_banner() {
  clear
  cat << "BANNER"
  __  __  _____     _                  _____           _        _ _           
 |  \/  |/ ____|   | |                |_   _|         | |      | | |          
 | \  / | |        | | __ ___   ____ _  | |  _ __  ___| |_ __ _| | | ___ _ __ 
 | |\/| | |    _   | |/ _` \ \ / / _` | | | | '_ \/ __| __/ _` | | |/ _ \ '__|
 | |  | | |___| |__| | (_| |\ V / (_| |_| |_| | | \__ \ || (_| | | |  __/ |   
 |_|  |_|\_____|\____/ \__,_| \_/ \__,_|_____|_| |_|___/\__\__,_|_|_|\___|_|   

==== Minecraft Java Auto-Installer - Created by JOTIBI ====
BANNER
}

show_help() {
  cat << 'HELP'
Usage: ./Java.sh [OPTIONS]

Menu (no options):
  1  Install Java versions
  2  Set system-wide default Java (PATH / JAVA_HOME)
  3  Show installed versions
  4  Exit

Options:
  --log              Write output to install_java.log
  --yes, -y          Skip confirmations
  --install 1 3 5    Install versions (1–5)
  --set-default      Choose default Java only (interactive)
  --default N        Default by list index (with --set-default or after --install)
  --status           Show status and exit
  --help, -h         Show this help

Versions:
  1  Java 8   (Minecraft 1.8–1.16.x)
  2  Java 11  (Minecraft 1.17–1.18.x)
  3  Java 17  (Minecraft 1.18.2–1.20.4)
  4  Java 21  (Minecraft 1.20.5–1.21.x)
  5  Java 25  (newer / future versions, testing)
HELP
}

# ========== LOGGING ==========
log() {
  if [[ "$LOGGING" == true ]]; then
    echo -e "$1" | tee -a "$LOG_FILE"
  else
    echo -e "$1"
  fi
}

run_cmd() {
  if [[ "$LOGGING" == true ]]; then
    "$@" 2>&1 | tee -a "$LOG_FILE"
    return "${PIPESTATUS[0]}"
  fi
  "$@"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --log)
        LOGGING=true
        echo "==== Log started at $(date) ====" > "$LOG_FILE"
        log "📝 Logging enabled → $LOG_FILE"
        ;;
      --yes|-y) AUTO_YES=true ;;
      --install)
        ACTION="install"
        shift
        while [[ $# -gt 0 && "$1" =~ ^[1-5]$ ]]; do
          CLI_INSTALL_CHOICES+=("$1")
          shift
        done
        continue
        ;;
      --set-default) ACTION="set-default" ;;
      --default)
        shift
        CLI_DEFAULT_INDEX="${1:-}"
        ACTION="set-default"
        ;;
      --status) ACTION="status" ;;
      --help|-h)
        show_banner
        show_help
        exit 0
        ;;
      *)
        echo "❌ Unknown option: $1 (use --help)"
        exit 1
        ;;
    esac
    shift
  done
}

# ========== PREREQUISITES ==========
require_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "❌ sudo is not installed."
    exit 1
  fi
  if ! sudo -n true >/dev/null 2>&1; then
    log "🔐 sudo privileges are required."
    sudo true || exit 1
  fi
}

require_commands() {
  local required=(curl sudo tar grep awk sed mktemp update-alternatives)
  local missing=()
  local cmd
  for cmd in "${required[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -ne 0 ]]; then
    log "❌ Missing programs: ${missing[*]}"
    exit 1
  fi
  if command -v apt-get >/dev/null 2>&1; then
    APT_BIN="apt-get"
  elif command -v apt >/dev/null 2>&1; then
    APT_BIN="apt"
  else
    log "❌ No apt/apt-get found – Debian/Ubuntu only."
    exit 1
  fi
}

confirm() {
  local prompt="$1"
  if [[ "$AUTO_YES" == true ]]; then
    return 0
  fi
  local answer
  read -r -p "$prompt" answer
  [[ "${answer:-n}" =~ ^[Yy]$ ]]
}

# ========== JAVA DETECTION ==========
is_java_registered() {
  local java_bin="$1"
  [[ -x "$java_bin" ]] && update-alternatives --list java 2>/dev/null | grep -Fxq "$java_bin"
}

find_existing_candidate() {
  local candidate
  for candidate in "$@"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

is_any_candidate_registered() {
  local candidate
  for candidate in "$@"; do
    if is_java_registered "$candidate"; then
      return 0
    fi
  done
  return 1
}

java_version_line() {
  local bin="$1"
  if [[ -x "$bin" ]]; then
    "$bin" -version 2>&1 | head -n 1
  else
    echo "(not executable)"
  fi
}

resolve_java_home() {
  local java_bin="$1"
  local bin_dir home_dir
  bin_dir=$(dirname "$java_bin")
  home_dir=$(dirname "$bin_dir")
  if [[ "$(basename "$home_dir")" == "bin" ]]; then
    dirname "$home_dir"
  else
    echo "$home_dir"
  fi
}

matching_javac_for_java() {
  local java_bin="$1"
  local javac_bin
  javac_bin="$(dirname "$java_bin")/javac"
  if [[ -x "$javac_bin" ]]; then
    echo "$javac_bin"
    return 0
  fi
  return 1
}

alternative_priority_for() {
  local alt_name="$1" alt_path="$2"
  local prio
  prio=$(update-alternatives --display "$alt_name" 2>/dev/null | grep -F "$alt_path" | awk '{print $1; exit}')
  if [[ -n "$prio" && "$prio" =~ ^[0-9]+$ ]]; then
    echo "$prio"
  else
    echo "100"
  fi
}

list_registered_javas() {
  update-alternatives --list java 2>/dev/null || true
}

load_java_array() {
  JAVA_ARRAY=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && JAVA_ARRAY+=("$line")
  done < <(list_registered_javas)
}

load_javac_array() {
  JAVAC_ARRAY=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && JAVAC_ARRAY+=("$line")
  done < <(update-alternatives --list javac 2>/dev/null || true)
}

show_java_status() {
  log ""
  log "📋 Installed Java versions (update-alternatives):"
  load_java_array
  if [[ ${#JAVA_ARRAY[@]} -eq 0 ]]; then
    log "   (none registered)"
    return 1
  fi
  local i current resolved
  current=$(readlink -f "$(command -v java 2>/dev/null || echo "")" 2>/dev/null || true)
  for i in "${!JAVA_ARRAY[@]}"; do
    resolved=$(readlink -f "${JAVA_ARRAY[$i]}" 2>/dev/null || echo "${JAVA_ARRAY[$i]}")
    if [[ "$resolved" == "$current" ]]; then
      log " $((i + 1))) ★ ${JAVA_ARRAY[$i]}"
    else
      log " $((i + 1)))   ${JAVA_ARRAY[$i]}"
    fi
    log "      $(java_version_line "${JAVA_ARRAY[$i]}")"
  done
  log ""
  log "Currently active:"
  log "  java   → $(command -v java 2>/dev/null || echo '—') → ${current:-—}"
  if [[ -f "$JAVA_HOME_PROFILE" ]]; then
    log "  JAVA_HOME (profile) → $(grep '^export JAVA_HOME=' "$JAVA_HOME_PROFILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo '—')"
  else
    log "  JAVA_HOME (profile) → not set"
  fi
  return 0
}

register_java_alternative() {
  local java_bin="$1" priority="$2"
  local javac_bin
  if ! is_java_registered "$java_bin"; then
    run_cmd sudo update-alternatives --install /usr/bin/java java "$java_bin" "$priority" || return 1
  fi
  if javac_bin=$(matching_javac_for_java "$java_bin"); then
    if ! update-alternatives --list javac 2>/dev/null | grep -Fxq "$javac_bin"; then
      run_cmd sudo update-alternatives --install /usr/bin/javac javac "$javac_bin" "$priority" || return 1
    fi
  fi
  return 0
}

register_openjdk_from_package() {
  local package="$1"
  local candidates=() priority label
  case "$package" in
    openjdk-11-jdk)
      candidates=("${JAVA11_CANDIDATES[@]}")
      priority=1110
      label="11"
      ;;
    openjdk-17-jdk)
      candidates=("${JAVA17_CANDIDATES[@]}")
      priority=1170
      label="17"
      ;;
    openjdk-21-jdk)
      candidates=("${JAVA21_CANDIDATES[@]}")
      priority=1210
      label="21"
      ;;
    *)
      return 1
      ;;
  esac
  local java_bin
  if ! java_bin=$(find_existing_candidate "${candidates[@]}"); then
    log "⚠️  OpenJDK $label not found on the filesystem."
    return 1
  fi
  register_java_alternative "$java_bin" "$priority"
}

install_manual_java() {
  local version_label="$1" url="$2" target_dir="$3" java_bin="$4"
  local priority="$5" link_name="$6"
  local tmpfile

  if [[ -x "$java_bin" ]]; then
    log "ℹ️  Java $version_label already present – skipping download."
  else
    tmpfile=$(mktemp "/tmp/java${version_label}.XXXXXX.tar.gz")
    log "⬇️  Downloading Java $version_label ..."
    if ! run_cmd curl -fsSL "$url" -o "$tmpfile"; then
      log "❌ Download failed (Java $version_label)."
      rm -f "$tmpfile"
      return 1
    fi
    log "📦 Extracting to $target_dir ..."
    run_cmd sudo mkdir -p "$target_dir" || { rm -f "$tmpfile"; return 1; }
    if ! run_cmd sudo tar -xzf "$tmpfile" -C "$target_dir" --strip-components=1; then
      log "❌ Extraction failed."
      rm -f "$tmpfile"
      return 1
    fi
    rm -f "$tmpfile"
  fi

  if [[ ! -x "$java_bin" ]]; then
    log "❌ Java $version_label was not installed correctly."
    return 1
  fi

  run_cmd sudo ln -sf "$java_bin" "/usr/local/bin/$link_name"
  register_java_alternative "$java_bin" "$priority"
}

install_apt_java() {
  local package="$1"
  run_cmd sudo "$APT_BIN" install -y "$package"
}

apply_java_home_profile() {
  local java_bin="$1"
  local java_home
  java_home=$(resolve_java_home "$java_bin")
  log "🌐 Setting system-wide JAVA_HOME → $java_home"
  run_cmd sudo tee "$JAVA_HOME_PROFILE" >/dev/null <<EOF
# Set by Minecraft Java Auto-Installer (JOTIBI)
export JAVA_HOME="$java_home"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF
  run_cmd sudo chmod 644 "$JAVA_HOME_PROFILE"
}

set_matching_javac() {
  local java_bin="$1"
  local javac_bin
  if ! javac_bin=$(matching_javac_for_java "$java_bin"); then
    log "ℹ️  No matching javac found – only java was set."
    return 0
  fi
  load_javac_array
  local entry
  for entry in "${JAVAC_ARRAY[@]}"; do
    if [[ "$entry" == "$javac_bin" ]]; then
      run_cmd sudo update-alternatives --set javac "$javac_bin"
      return 0
    fi
  done
  local prio
  prio=$(alternative_priority_for java "$java_bin")
  log "ℹ️  javac $javac_bin not in alternatives – registering (priority $prio) ..."
  if ! update-alternatives --list javac 2>/dev/null | grep -Fxq "$javac_bin"; then
    run_cmd sudo update-alternatives --install /usr/bin/javac javac "$javac_bin" "$prio"
  fi
  run_cmd sudo update-alternatives --set javac "$javac_bin" || true
}

set_system_default_java() {
  local preset_index="${1:-}"

  load_java_array
  if [[ ${#JAVA_ARRAY[@]} -eq 0 ]]; then
    log "❌ No Java version registered. Please install one first."
    return 1
  fi

  log ""
  log "📋 Choose the system-wide default Java version:"
  log "   (★ = currently active; applies to java, javac, JAVA_HOME, and PATH)"
  show_java_status

  local choice index java_bin
  if [[ -n "$preset_index" ]]; then
    choice="$preset_index"
  elif [[ "$AUTO_YES" == true && ${#JAVA_ARRAY[@]} -eq 1 ]]; then
    choice=1
  else
    while true; do
      read -r -p "Number (1-${#JAVA_ARRAY[@]}, s = cancel): " choice
      [[ "$choice" == "s" ]] && return 0
      if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#JAVA_ARRAY[@]} )); then
        break
      fi
      log "⚠️  Invalid input."
    done
  fi

  index=$((choice - 1))
  java_bin="${JAVA_ARRAY[$index]}"

  log ""
  log "🔧 Setting default to:"
  log "   $(java_version_line "$java_bin")"
  log "   $java_bin"

  if ! run_cmd sudo update-alternatives --set java "$java_bin"; then
    log "❌ update-alternatives --set java failed."
    return 1
  fi
  set_matching_javac "$java_bin"
  apply_java_home_profile "$java_bin"

  log ""
  log "✅ System-wide default Java is active."
  log "   java  → $(readlink -f "$(command -v java)" 2>/dev/null || command -v java)"
  log "   Version: $(java_version_line "$(command -v java)")"
  log ""
  log "ℹ️  New shells/sessions will load JAVA_HOME from $JAVA_HOME_PROFILE"
  log "   Existing sessions: source $JAVA_HOME_PROFILE or log in again."
  return 0
}

# ========== INSTALLATION ==========
collect_install_options() {
  AVAILABLE_OPTIONS=()
  if ! is_java_registered "$JAVA_8_BIN"; then
    AVAILABLE_OPTIONS+=(1)
    log "1) Java 8     – Minecraft 1.8 to 1.16.x"
  fi
  if ! is_any_candidate_registered "${JAVA11_CANDIDATES[@]}"; then
    AVAILABLE_OPTIONS+=(2)
    log "2) Java 11    – Minecraft 1.17 to 1.18.x"
  fi
  if ! is_any_candidate_registered "${JAVA17_CANDIDATES[@]}"; then
    AVAILABLE_OPTIONS+=(3)
    log "3) Java 17    – Minecraft 1.18.2 to 1.20.4"
  fi
  if ! is_any_candidate_registered "${JAVA21_CANDIDATES[@]}"; then
    AVAILABLE_OPTIONS+=(4)
    log "4) Java 21    – Minecraft 1.20.5 to 1.21.x"
  fi
  if ! is_java_registered "$JAVA_25_BIN"; then
    AVAILABLE_OPTIONS+=(5)
    log "5) Java 25    – newer / future versions"
  fi
}

resolve_install_choices() {
  local choices=("$@")
  SELECTED_PACKAGES=()
  local choice
  for choice in "${choices[@]}"; do
    if [[ -n "${JAVA_MAP[$choice]:-}" ]]; then
      SELECTED_PACKAGES+=("${JAVA_MAP[$choice]}")
    else
      log "⚠️  Invalid selection: $choice"
    fi
  done
}

run_installation() {
  local choices_input=("$@")
  local choice_line
  local installed=() failed=()

  log ""
  collect_install_options

  if [[ ${#AVAILABLE_OPTIONS[@]} -eq 0 ]]; then
    log "✅ All supported versions are already installed."
    return 0
  fi

  if [[ ${#choices_input[@]} -gt 0 ]]; then
    resolve_install_choices "${choices_input[@]}"
  else
    log ""
    log "Multiple selection with spaces (e.g. ${AVAILABLE_OPTIONS[*]}):"
    read -r -p "Which version(s)? " choice_line
    choices_input=($(echo "$choice_line" | tr ' ' '\n' | sed '/^$/d' | sort -u))
    resolve_install_choices "${choices_input[@]}"
  fi

  if [[ ${#SELECTED_PACKAGES[@]} -eq 0 ]]; then
    log "❌ No valid version selected."
    return 1
  fi

  log ""
  log "➡️  Packages: ${SELECTED_PACKAGES[*]}"
  if ! confirm "Start installation? (y/n): "; then
    log "Cancelled."
    return 0
  fi

  log ""
  log "📦 Running apt update ..."
  if ! run_cmd sudo "$APT_BIN" update; then
    log "❌ apt update failed."
    return 1
  fi

  local package
  for package in "${SELECTED_PACKAGES[@]}"; do
    log ""
    log "🔧 $package ..."
    case "$package" in
      java8_manual)
        if install_manual_java "8" "$JAVA_8_URL" "$JAVA_8_DIR" "$JAVA_8_BIN" 1080 "java8"; then
          installed+=("Java 8")
        else
          failed+=("Java 8")
        fi
        ;;
      java25_manual)
        if install_manual_java "25" "$JAVA_25_URL" "$JAVA_25_DIR" "$JAVA_25_BIN" 1250 "java25"; then
          installed+=("Java 25")
        else
          failed+=("Java 25")
        fi
        ;;
      openjdk-11-jdk|openjdk-17-jdk|openjdk-21-jdk)
        if install_apt_java "$package" && register_openjdk_from_package "$package"; then
          installed+=("$package")
        else
          failed+=("$package")
        fi
        ;;
      *)
        failed+=("$package")
        ;;
    esac
  done

  log ""
  if [[ ${#installed[@]} -gt 0 ]]; then
    log "✅ Installed: ${installed[*]}"
  fi
  if [[ ${#failed[@]} -gt 0 ]]; then
    log "❌ Failed: ${failed[*]}"
    return 1
  fi
  return 0
}

offer_set_default_after_install() {
  if [[ "$AUTO_YES" == true ]]; then
    [[ -n "$CLI_DEFAULT_INDEX" ]] && set_system_default_java "$CLI_DEFAULT_INDEX"
    return 0
  fi
  log ""
  if confirm "Set system-wide default Java now? (y/n): "; then
    set_system_default_java ""
  fi
}

# ========== MAIN MENU ==========
show_main_menu() {
  log ""
  log "What would you like to do?"
  log "  1) Install Java versions"
  log "  2) Set system-wide default Java (PATH / JAVA_HOME)"
  log "  3) Show installed versions"
  log "  4) Exit"
  log ""
}

handle_menu_choice() {
  local choice="$1"
  case "$choice" in
    1)
      run_installation && offer_set_default_after_install
      ;;
    2)
      set_system_default_java "" || true
      ;;
    3)
      show_java_status || true
      ;;
    4)
      log "Goodbye!"
      exit 0
      ;;
    *)
      log "⚠️  Please choose 1–4."
      ;;
  esac
}

run_interactive_menu() {
  while true; do
    show_banner
    require_sudo
    show_main_menu
    read -r -p "Choice (1-4): " menu_choice
    handle_menu_choice "$menu_choice"
    log ""
    read -r -p "Press Enter for main menu ..." _
  done
}

run_cli_action() {
  show_banner
  require_sudo
  case "$ACTION" in
    install)
      run_installation "${CLI_INSTALL_CHOICES[@]}" || exit 1
      offer_set_default_after_install
      ;;
    set-default)
      set_system_default_java "$CLI_DEFAULT_INDEX" || exit 1
      ;;
    status)
      show_java_status || exit 1
      ;;
  esac
}

# ========== START ==========
main() {
  parse_args "$@"
  require_commands

  if [[ -n "$ACTION" ]]; then
    run_cli_action
    exit 0
  fi

  if [[ "$LOGGING" == true && ! -f "$LOG_FILE" ]]; then
    echo "==== Log started at $(date) ====" > "$LOG_FILE"
  fi

  run_interactive_menu
}

main "$@"
