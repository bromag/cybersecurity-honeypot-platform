#!/usr/bin/env bash

# Interaktive Live-Demo fuer die Cybersecurity-Honeypot-Plattform.
# Das Skript wird auf dem Host (macOS) im Projektverzeichnis gestartet.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="${ROOT_DIR}/honeypot-vm"
GRAFANA_URL="http://localhost:3000/d/cowrie-overview/cowrie-honeypot-overview?orgId=1&from=now-15m&to=now&refresh=5s"
LOKI_READY_URL="http://localhost:3100/ready"
PARALLELS_VM_NAME="honeypot-server"
VM_BACKEND="vagrant"
VAGRANT_PROVIDER=""

if [[ -f "${VM_DIR}/.vagrant/machines/default/parallels/id" ]]; then
  VAGRANT_PROVIDER="parallels"
elif [[ -f "${VM_DIR}/.vagrant/machines/default/virtualbox/id" ]]; then
  VAGRANT_PROVIDER="virtualbox"
elif command -v prlctl >/dev/null 2>&1 \
  && prlctl list -a --no-header -o name 2>/dev/null | awk '{$1=$1};1' | grep -Fxq "${PARALLELS_VM_NAME}"; then
  # Die VM existiert noch in Parallels, aber Vagrants lokale ID-Datei fehlt.
  # In diesem Fall kann die Praesentation die VM weiterhin sicher direkt lesen.
  VM_BACKEND="parallels-direct"
fi

if [[ -t 1 ]]; then
  RESET=$'\033[0m'
  BOLD=$'\033[1m'
  BLUE=$'\033[34m'
  CYAN=$'\033[36m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  RED=$'\033[31m'
else
  RESET="" BOLD="" BLUE="" CYAN="" GREEN="" YELLOW="" RED=""
fi

line() {
  printf '%s\n' "------------------------------------------------------------"
}

title() {
  printf '\n%s%s%s\n' "${BOLD}${BLUE}" "$1" "${RESET}"
  line
}

say() {
  printf '\n%sSprechhinweis:%s\n%s\n' "${YELLOW}${BOLD}" "${RESET}" "$1"
}

info() {
  printf '%s%s%s\n' "${CYAN}" "$1" "${RESET}"
}

ok() {
  printf '%s✓ %s%s\n' "${GREEN}" "$1" "${RESET}"
}

warn() {
  printf '%s! %s%s\n' "${YELLOW}" "$1" "${RESET}"
}

fail() {
  printf '%s✗ %s%s\n' "${RED}" "$1" "${RESET}"
}

pause_demo() {
  printf '\n%s' "${BOLD}Weiter mit Enter …${RESET}"
  IFS= read -r _
}

confirm() {
  local answer
  printf '\n%s [j/N] ' "$1"
  IFS= read -r answer
  [[ "${answer}" =~ ^[jJyY]$ ]]
}

run_vm() {
  if [[ "${VM_BACKEND}" == "parallels-direct" ]]; then
    prlctl exec "${PARALLELS_VM_NAME}" bash -lc "$1"
  else
    (cd "${VM_DIR}" && VAGRANT_DEFAULT_PROVIDER="${VAGRANT_PROVIDER}" vagrant ssh -c "$1")
  fi
}

show_vm_status() {
  if [[ "${VM_BACKEND}" == "parallels-direct" ]]; then
    printf 'Parallels VM: %s\n' "${PARALLELS_VM_NAME}"
    prlctl list "${PARALLELS_VM_NAME}" -o status --no-header
  else
    (cd "${VM_DIR}" && VAGRANT_DEFAULT_PROVIDER="${VAGRANT_PROVIDER}" vagrant status)
  fi
}

open_url() {
  local url="$1"
  if command -v open >/dev/null 2>&1; then
    open "$url"
  else
    info "Bitte im Browser öffnen: ${url}"
  fi
}

open_grafana_in_vscode() {
  local url="$1"

  if [[ "$(uname -s)" != "Darwin" ]] \
    || [[ ! -d "/Applications/Visual Studio Code.app" ]] \
    || ! command -v osascript >/dev/null 2>&1; then
    return 1
  fi

  GRAFANA_TARGET_URL="${url}" osascript >/dev/null 2>&1 <<'APPLESCRIPT'
set dashboardUrl to system attribute "GRAFANA_TARGET_URL"

tell application "Visual Studio Code" to activate
delay 0.8

tell application "System Events"
  tell process "Code"
    keystroke "p" using {command down, shift down}
    delay 0.5
    keystroke "Browser: Open Integrated Browser"
    delay 0.5
    key code 36
    delay 1
    keystroke dashboardUrl
    key code 36
  end tell
end tell
APPLESCRIPT
}

open_grafana() {
  if open_grafana_in_vscode "${GRAFANA_URL}"; then
    ok "Grafana wurde im integrierten Browser von VS Code geöffnet"
  else
    warn "VS Code konnte nicht automatisch bedient werden; Grafana wird im Standardbrowser geöffnet."
    open_url "${GRAFANA_URL}"
  fi
}

clear_screen() {
  if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
    clear
  fi
}

preflight() {
  title "Vorbereitung – ist die Demo bereit?"

  local errors=0

  if [[ -f "${ROOT_DIR}/docker-compose.yml" ]]; then
    ok "Projektverzeichnis erkannt"
  else
    fail "docker-compose.yml fehlt neben diesem Skript"
    errors=$((errors + 1))
  fi

  if [[ "${VM_BACKEND}" == "parallels-direct" ]]; then
    ok "Bestehende Parallels-VM wurde erkannt"
  elif command -v vagrant >/dev/null 2>&1; then
    ok "Vagrant ist verfügbar (${VAGRANT_PROVIDER:-Standard-Provider})"
  else
    fail "Vagrant wurde nicht gefunden"
    errors=$((errors + 1))
  fi

  if command -v ssh >/dev/null 2>&1; then
    ok "SSH-Client ist verfügbar"
  else
    fail "SSH-Client wurde nicht gefunden"
    errors=$((errors + 1))
  fi

  if (( errors > 0 )); then
    warn "Bitte die fehlenden Voraussetzungen beheben."
    return 1
  fi

  printf '\n%sVM-Status:%s\n' "${BOLD}" "${RESET}"
  show_vm_status || {
    fail "Der VM-Status konnte nicht gelesen werden."
    return 1
  }

  printf '\n%sContainer:%s\n' "${BOLD}" "${RESET}"
  if run_vm 'cd /project && docker compose ps'; then
    ok "Die VM ist erreichbar"
  else
    fail "Die VM ist nicht erreichbar oder /project fehlt"
    return 1
  fi

  if curl --silent --fail --max-time 3 "${LOKI_READY_URL}" >/dev/null 2>&1; then
    ok "Loki meldet ready"
  else
    warn "Loki ist über localhost:3100 noch nicht bereit"
  fi

  if curl --silent --fail --max-time 3 http://localhost:3000/api/health >/dev/null 2>&1; then
    ok "Grafana ist erreichbar"
  else
    warn "Grafana ist über localhost:3000 noch nicht erreichbar"
  fi
}

intro() {
  clear_screen
  title "Cybersecurity-Honeypot-Plattform"

  cat <<'TEXT'
Ziel der Demonstration

  • Einen simulierten SSH-Dienst bereitstellen
  • Verbindungen, Login-Versuche und Befehle erfassen
  • Ereignisse zentral sammeln und auswerten
  • Den vollständigen Datenweg sichtbar machen
TEXT

  pause_demo
}

project_overview() {
  clear_screen
  title "1 – Projektstruktur und Betriebsbasis"

  cat <<'TEXT'
Projekt
├── honeypot-vm/       reproduzierbare Ubuntu-VM mit Vagrant
├── cowrie/            simulierter SSH-Dienst
├── promtail/          liest Cowrie-Protokolle
├── loki/              speichert und durchsucht Logs
├── grafana/           Dashboard und Analyse
└── docker-compose.yml startet die vier Container
TEXT

  pause_demo
}

architecture() {
  clear_screen
  title "2 – Architektur und Datenfluss"

  cat <<'TEXT'
  Testperson / Angreifer
            │ SSH auf Port 2222
            ▼
       ┌──────────┐    JSON-Ereignisse    ┌──────────┐
       │  Cowrie  │ ────────────────────▶ │ Promtail │
       └──────────┘                       └────┬─────┘
                                              │ Push
                                              ▼
                                         ┌────────┐
                                         │  Loki  │
                                         └───┬────┘
                                             │ LogQL
                                             ▼
                                        ┌─────────┐
                                        │ Grafana │
                                        └─────────┘
TEXT

  say "Cowrie ist kein echter Produktivserver. Es imitiert einen SSH-Server und zeichnet Interaktionen strukturiert auf. Promtail liest die JSON-Datei fortlaufend, Loki speichert die Ereignisse und Grafana stellt sie verständlich dar."

  if confirm "Architekturbild zusätzlich öffnen?"; then
    open_url "file://${ROOT_DIR}/docs/phase-2-architektur.drawio.png"
  fi
  pause_demo
}

services() {
  clear_screen
  title "3 – Laufende Plattform"

  say "Alle vier Container sollten den Status Up besitzen."
  printf '\n%s$ docker compose ps%s\n\n' "${CYAN}" "${RESET}"
  run_vm 'cd /project && docker compose ps' || warn "Containerstatus konnte nicht gelesen werden."

  printf '\n%sErreichbare Schnittstellen%s\n' "${BOLD}" "${RESET}"
  printf '  Cowrie   SSH   localhost:2222\n'
  printf '  Grafana  HTTP  localhost:3000\n'
  printf '  Loki     HTTP  localhost:3100\n'
  pause_demo
}

show_recent_events() {
  title "Neueste Cowrie-Ereignisse"
  info "Passwörter werden in dieser Präsentationsansicht bewusst ausgeblendet."

  run_vm 'volume_name=$(docker volume ls --filter label=com.docker.compose.volume=cowrie-data --format "{{.Name}}" | head -n 1); mountpoint=$(docker volume inspect "$volume_name" --format "{{.Mountpoint}}"); sudo tail -n 25 "$mountpoint/log/cowrie/cowrie.json" | jq -c "{timestamp,eventid,src_ip,username,input,message}"' \
    || warn "Cowrie-Log konnte nicht gelesen werden. Erzeuge zuerst eine SSH-Verbindung."
}

phase_one() {
  clear_screen
  title "4 – Phase 1: Cowrie live testen"

  cat <<'TEXT'
Geplanter Ablauf in der simulierten SSH-Sitzung:

  1. Bei der Passwortabfrage zuerst: falsch123
  2. Danach als korrektes Demo-Passwort: toor
  3. In der Cowrie-Shell eingeben:

       whoami
       uname -a
       echo TEKO-LIVE-DEMO
       echo TEKO-LIVE-payload-DEMO
       exit

Das Wort "payload" ist nur eine harmlose Markierung für den Dashboard-Filter.
TEXT

  say "Ich verbinde mich jetzt wie ein externer Benutzer mit Port 2222. Die Shell sieht echt aus, wird aber von Cowrie simuliert. Jeder Login-Versuch und jeder eingegebene Befehl wird protokolliert."

  if confirm "Interaktive SSH-Demo jetzt starten?"; then
    ssh \
      -o PreferredAuthentications=password \
      -o PubkeyAuthentication=no \
      -o StrictHostKeyChecking=accept-new \
      -p 2222 root@127.0.0.1 || true
  else
    info "SSH-Demo übersprungen."
  fi

  printf '\n'
  show_recent_events
  say "Phase 1: Cowrie hat Verbindung, Anmeldung und Befehle als strukturierte Ereignisse gespeichert."
  pause_demo
}

phase_two() {
  clear_screen
  title "5 – Phase 2: Vom Ereignis zur Visualisierung"

  cat <<'TEXT'
Nachweis der Pipeline

  Cowrie-JSON  →  Promtail  →  Loki  →  Grafana

In Grafana:
  1. Zeitraum auf "Letzte 15 Minuten" setzen
  2. Dashboard aktualisieren
  3. "Executed Commands" kontrollieren
  4. "Suspicious Commands" kontrollieren
TEXT

  if curl --silent --fail --max-time 3 "${LOKI_READY_URL}" >/dev/null 2>&1; then
    ok "Loki ist bereit und kann Abfragen beantworten"
  else
    warn "Loki ist derzeit nicht über ${LOKI_READY_URL} erreichbar"
  fi

  say "Promtail übernimmt die Ereignisse automatisch. Loki macht sie mit LogQL durchsuchbar. Im Dashboard sollte derselbe markierte Befehl TEKO-LIVE-payload-DEMO erscheinen. Damit ist die gesamte Pipeline nachgewiesen."

  if confirm "Grafana-Dashboard jetzt in VS Code öffnen?"; then
    open_grafana
  fi
  pause_demo
}

logql() {
  clear_screen
  title "6 – Gezielte Analyse mit LogQL"

  cat <<'TEXT'
Alle eingegebenen Befehle:

  {job="cowrie", eventid="cowrie.command.input"}

Nur Ereignisse dieser Live-Demo:

  {job="cowrie", eventid="cowrie.command.input"} |= "TEKO-LIVE"

Als verdächtig markierte Befehle:

  {job="cowrie", eventid="cowrie.command.input"}
    | json
    | input =~ "(?i).*(wget|curl|chmod|payload).*"
TEXT

  say "LogQL filtert nicht nur Text, sondern auch die von Promtail übernommenen Labels. Der Filter mit verdächtigen Begriffen ist eine einfache Demonstrationsregel und noch kein Beweis für einen echten Angriff."
  pause_demo
}

conclusion() {
  clear_screen
  title "7 – Fazit"

  cat <<'TEXT'
Was wurde gezeigt?

  ✓ Isolierter, reproduzierbarer Honeypot
  ✓ Simulierter SSH-Dienst statt eines echten Zielsystems
  ✓ Erfassung von Verbindungen, Logins und Befehlen
  ✓ Automatische zentrale Log-Weiterleitung
  ✓ Suche und Visualisierung in Grafana

Mögliche Weiterentwicklungen

  • Alarmierung bei auffälligen Ereignissen
  • GeoIP-Anreicherung von Quelladressen
  • Integration einer SIEM-Lösung wie Wazuh
TEXT

  say "Die Plattform macht einen Angriff nicht nur sichtbar. Sie zeigt nachvollziehbar den gesamten Weg vom ersten Netzwerkereignis bis zur zentralen Analyse. Die Umgebung bleibt bewusst ein isoliertes Schulungs- und Testlabor."
  pause_demo
}

full_demo() {
  intro
  project_overview
  architecture
  preflight || {
    warn "Die Präsentation kann fortgesetzt werden, aber die Live-Teile funktionieren möglicherweise nicht."
    pause_demo
  }
  services
  phase_one
  phase_two
  logql
  conclusion
}

menu() {
  while true; do
    clear_screen
    title "Honeypot – interaktive Präsentation"
    cat <<'TEXT'
  1  Komplette Präsentation starten
  2  Vorbereitung prüfen
  3  Projektstruktur zeigen
  4  Architektur zeigen
  5  Containerstatus zeigen
  6  Cowrie-SSH-Demo durchführen
  7  Monitoring und Grafana zeigen
  8  LogQL-Abfragen erklären
  9  Fazit zeigen
  0  Beenden
TEXT
    printf '\nAuswahl: '
    IFS= read -r choice

    case "${choice}" in
      1) full_demo ;;
      2) preflight; pause_demo ;;
      3) project_overview ;;
      4) architecture ;;
      5) services ;;
      6) phase_one ;;
      7) phase_two ;;
      8) logql ;;
      9) conclusion ;;
      0) printf '\nDemo beendet.\n'; return 0 ;;
      *) warn "Ungültige Auswahl"; pause_demo ;;
    esac
  done
}

if [[ ! -d "${VM_DIR}" ]]; then
  fail "honeypot-vm wurde nicht gefunden: ${VM_DIR}"
  exit 1
fi

case "${1:-}" in
  --check) preflight ;;
  --full) full_demo ;;
  --help|-h)
    printf 'Verwendung: %s [--check|--full|--help]\n' "$0"
    ;;
  "") menu ;;
  *) fail "Unbekannte Option: $1"; exit 2 ;;
esac
