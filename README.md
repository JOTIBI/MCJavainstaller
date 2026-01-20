# Minecraft Server Auto-Installer (JOTIBI)

Ein **vollständig automatisiertes Bash-Script** zum Installieren, Starten und Verwalten von Minecraft-Servern unter Linux (Debian/Ubuntu).  
Der Fokus liegt auf **Korrektheit, Transparenz, Debugbarkeit und Kontrolle**.

---

## Inhaltsverzeichnis

- Überblick
- Features
- Unterstützte Server-Typen
- Voraussetzungen
- Installation
- Start & Nutzung
- Java-Auswahl & Empfehlung
- Fabric-Logik (wichtig)
- Debug-Modus
- Uninstaller
- Verzeichnisstruktur
- Typische Fehler & Lösungen
- Hinweise für Produktivbetrieb

---

## Überblick

Dieses Script installiert Minecraft-Server **interaktiv** und startet sie **immer in einer `screen`-Session**.  
Du wählst:

- Server-Typ
- Minecraft-Version
- RAM & Port
- **konkrete Java-Version**, die der Server nutzen soll

Das Script **ändert nicht dein System-Java**, sondern speichert die gewählte Java-Binary serverlokal.

---

## Features

- ✅ Server-Typen:
  - Vanilla
  - Forge
  - Fabric
  - Spigot
  - Paper
  - Bungeecord
- ✅ Automatische Installation aller Voraussetzungen (`apt`)
- ✅ Server läuft immer in `screen`
- ✅ Auswahl einer installierten Java-Version (`update-alternatives`)
- ✅ Java-Empfehlung passend zur Minecraft-Version
- ✅ `--debug` Modus mit sauberem Script-Logging
- ✅ `--uninstall` Modus (inkl. screen-Session Cleanup)
- ❌ Kein Python
- ❌ Kein hartcodiertes Java
- ❌ Kein kaputtes JSON-Parsen

---

## Unterstützte Server-Typen

| Typ        | Quelle / Methode |
|-----------|------------------|
| Vanilla   | Mojang Version Manifest |
| Forge     | Offizieller Forge Installer (`--installServer`) |
| Fabric    | Fabric Meta API (Loader + Installer) |
| Spigot   | BuildTools (rechtlich korrekt) |
| Paper    | PaperMC REST API |
| Bungeecord | Offizielles BungeeCord Artifact |

---

## Voraussetzungen

### Betriebssystem
- Debian / Ubuntu
- Root oder sudo-Rechte

### Automatisch installiert:
- `curl`
- `jq`
- `screen`
- `ca-certificates`
- `default-jre`
- je nach Typ zusätzlich:
  - Spigot → `git`, `default-jdk`
  - Forge → `default-jdk`

Du musst **nichts manuell vorbereiten**.

---

## Installation

```bash
chmod +x mc-installer.sh
./mc-installer.sh


[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/I3I61SOC0C)
