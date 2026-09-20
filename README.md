# HELIOS

Der zentrale Setup-Server des Rubitopia-Homelabs: **Fedora Server, Podman
rootless, Dienste als Quadlets.**

Dieses Repository enthält den *Code*. Warum es so gebaut ist, in welcher
Reihenfolge und was noch offen ist, steht im Planungsrepository:
[mluethi/homelab → projekte/30-server/installation-helios.md](https://github.com/mluethi/homelab/blob/main/projekte/30-server/installation-helios.md)

> **Versuchsballon.** Nichts hier ist produktiv erprobt. Der Server darf
> weggeworfen werden; der Zweck sind die Erkenntnisse, nicht der Betrieb.

> **Nichts davon ist je gelaufen.** Das Playbook ist geschrieben, aber auf
> keiner Maschine ausgeführt worden. Beim ersten Durchgang mit Fehlern rechnen
> und sie ins Journal eintragen.

## Die Maschine

HP ProDesk 400 G6, i3, 32 GB RAM, rund 1,3 TB Platte. Hostname `helios.rubi`,
feste IP über die OPNsense.

## Aufbau in zwei Durchgängen

**Durchgang 1 – von Hand.** Fedora Server 44 ganz normal installieren, dann
dieses Playbook laufen lassen. Hier liegt der Wert.

**Durchgang 2 – Kickstart.** Erst danach, und nur wenn sich der Weg bewährt
hat. `kickstart/helios.ks` wird dann mit den echten Werten gefüllt und in einer
VM auf HELIOS selbst durchgespielt.

## Bootstrap

Nach der Installation von Fedora, angemeldet als `marcello`:

```bash
sudo dnf install -y ansible-core git-core
ansible-pull -U https://github.com/mluethi/helios.git bootstrap.yml -K
```

`-K` fragt nach dem `sudo`-Passwort; das Playbook braucht es für Pakete, sysctl
und die Cockpit-Konfiguration. Alles rund um Podman läuft **ohne** `sudo`, weil
die Container rootless unter `marcello` laufen.

**Ein Vault-Passwort braucht es in Welle 1 noch nicht** – es gibt noch keine
Geheimnisse. Ab Welle 2 (Forgejo, VaultWarden) kommt `--ask-vault-pass` dazu.

## Was das Playbook tut

| Rolle | läuft als | Inhalt |
|---|---|---|
| `basis` | root | Pakete, `net.ipv4.ip_unprivileged_port_start=80`, `loginctl enable-linger`, `podman.socket`, Cockpit hinter dem Proxy |
| `caddy` | marcello | Podman-Netzwerk, Caddy-Quadlet, Caddyfile mit `tls internal` |
| `homepage` | marcello | Startseite als Quadlet, erreichbar über `home.rubi` |
| `backup` | beide | Platte nach `/data`, restic-Repository, täglicher Timer |
| `cli_tools` | root | `mc`, `bat`, `fzf`, `zoxide`, `chezmoi`, `direnv` |

Das ist **Welle 1**, seit dem 20.09.2026 vollständig – einschliesslich Backup
und `ansible-vault`, die beide zuerst gefehlt hatten. Aus **Welle 2** läuft
Homepage; Forgejo und VaultWarden folgen. Semaphore und der Pi-Agent sind
Welle 3.

**Arcane ist entfallen** (F-11 im Planungsrepository): Es spricht die
Docker-API und sieht keine Quadlets – damit zeigt es dauerhaft ein
unvollständiges Bild. `cockpit-podman` deckt den Bedarf, ist paketiert und
pflegt sich mit dem System.

**Das Backup** sichert, was dieses Playbook *nicht* wiederherstellen kann: die
Podman-Volumes mit Caddys Zertifizierungsstelle und die Konfiguration von
Homepage. Alles Übrige liegt in Git. Ziel ist vorerst die zweite Platte im
Gerät – kein richtiges Backup, aber das Ziel, an dem die Mechanik entstand und
der Rückholtest geprobt wurde. Eine externe Platte ist eine Zeile in
`group_vars` (F-15).

## Grundsätze

**Nur `ansible-core`.** Keine Collections aus der Galaxy, kein `ansible.posix`,
kein `containers.podman`. Ein Bootstrap, der zusätzliche Abhängigkeiten
nachladen muss, ist ein Bootstrap, der beim Wiederherstellen scheitert. Dafür
wird die sysctl-Datei von Hand geschrieben statt über ein Modul.

**Quadlets sind die Wahrheit.** Container werden ausschliesslich über die
`.container`-Dateien in diesem Repo verwaltet. Wer in Cockpit einen Container
startet, erzeugt ihn *neben* dieser Welt – ohne systemd-Unit, ohne Git, ohne
Neustart-Überleben, und beim nächsten `ansible-pull` weiss niemand davon.

**`cockpit-podman` ist ein Fenster, kein Werkzeug.** Draufschauen ja, damit
arbeiten nein. Dieselbe Regel galt für Arcane, bevor es entfiel – sie hängt
nicht am Werkzeug, sondern daran, dass es zwei Wege gäbe, dasselbe zu tun, und
nur einer davon im Git steht.

**Keine Geheimnisse im Klartext.** Dieses Repo ist öffentlich. Passwörter,
Token und Schlüssel gehören in `ansible-vault`, nichts davon unverschlüsselt in
eine Datei.

**Dieses Repo bleibt auf GitHub**, auch wenn Forgejo auf HELIOS läuft. Stirbt
HELIOS, stirbt sonst das Repo mit, aus dem HELIOS wiederhergestellt wird.
Forgejo bekommt eine Spiegelung, nicht das Original.

## Nach einer Änderung an einem Quadlet

```bash
systemctl --user daemon-reload
systemctl --user restart caddy
```

## Die Zertifikate

Caddy betreibt eine eigene CA auf HELIOS (`tls internal`). Damit der Mac keine
Warnung zeigt, muss deren Wurzelzertifikat einmal importiert werden:

```bash
podman volume inspect caddy-data     # Pfad des Volumes
# darin: caddy/pki/authorities/local/root.crt
```

Datei auf den Mac holen, in die Schlüsselbundverwaltung importieren, auf „Immer
vertrauen" stellen.

## Struktur

```
bootstrap.yml          Einstieg, ruft die Rollen
inventory.yml          nur localhost
ansible.cfg
group_vars/all.yml     Variablen (Hostname, Benutzer, Ports)
roles/basis/           System: Pakete, sysctl, linger, Cockpit
roles/caddy/           Reverse Proxy als Quadlet
roles/cli_tools/       Werkzeuge fuer die Kommandozeile
kickstart/helios.ks    Durchgang 2 – noch mit Platzhaltern
```
