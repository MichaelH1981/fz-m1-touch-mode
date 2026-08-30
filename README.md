# Panasonic FZ-M1 MK3: Touch- und Stiftmodi unter Linux

[English version](README.en.md)

> **Urheberschaft:** Recherche, statische Analyse, Protokollrekonstruktion,
> Implementierung, Tests und Dokumentation wurden von **OpenAI Codex** im Auftrag
> des Repository-Inhabers **MichaelH1981** durchgeführt. Der Inhaber stellte die
> Testhardware bereit und autorisierte und begleitete die Arbeiten am Gerät.

Diese Lösung schaltet den Sharp-Touchcontroller `04dd:9762` des Panasonic Toughpad
FZ-M1 MK3 ohne Windows in Panasonics originalen **Pen/Touch-Modus**. Finger und der
passive Originalstift werden dabei vom Controller gemeinsam über das vorhandene
Touch-Eingabegerät gemeldet. Zusätzlich sind Touch-, Pen-, Handschuh- und Regenmodus
umschaltbar.

## Ursache

Der Linux-Treiber `hid-multitouch` arbeitet für die normalen Multitouch-Reports
korrekt. Der HID-Deskriptor stellt jedoch keine eigene Stylus-Collection bereit. Der
passive Panasonic-Stift wird deshalb nicht durch einen fehlenden Linux-Pen-Treiber
verhindert, sondern durch den im Sharp-Controller gespeicherten Betriebsmodus. Bei
der Untersuchung stand das Gerät zunächst im Panasonic-Water-Modus (`0x0a`).

Panasonics Windows-Software sendet dokumentierbare herstellerspezifische HID-Reports,
um Modus und Schwellenwerte zu ändern. Das kleine Linux-Werkzeug reproduziert nur die
statisch aus den originalen Panasonic-Dateien ermittelten Befehle. Es führt kein
Windows-Programm aus, installiert keine Firmware und verändert weder Kernel noch
Bootkette.

## Benutzung

Status und relevante Register anzeigen:

```sh
sudo /usr/local/sbin/fz-m1-touch-mode status
sudo /usr/local/sbin/fz-m1-touch-mode registers
```

Profile umschalten:

```sh
sudo /usr/local/sbin/fz-m1-touch-mode touch
sudo /usr/local/sbin/fz-m1-touch-mode pen
sudo /usr/local/sbin/fz-m1-touch-mode pen-touch
sudo /usr/local/sbin/fz-m1-touch-mode glove
sudo /usr/local/sbin/fz-m1-touch-mode water
```

`glove` ist Panasonics Handschuhmodus mit erhöhter Berührungsempfindlichkeit.
`water` entspricht dem Regen-/Wassermodus und reduziert Fehlauslösungen durch Wasser.
Nach jedem Schreiben werden Modus und alle betroffenen Register zurückgelesen. Bei
einem Fehler versucht das Werkzeug, den vorherigen Zustand wiederherzustellen.

## Statusleisten-Widget für KDE Plasma und XFCE

Das gemeinsame Ayatana-StatusNotifier-Widget zeigt das zuletzt vom Controller
bestätigte Profil und bietet alle fünf Modi direkt im Panelmenü an. Es funktioniert
mit Plasma und XFCE; zwei getrennte Panel-Plugins sind nicht erforderlich.

Das Widget läuft ohne Root-Rechte. Nur das eng begrenzte CLI wird beim Aktualisieren
oder Umschalten über Polkit privilegiert gestartet. Die Polkit-Regel akzeptiert nur
den festen Pfad `/usr/local/sbin/fz-m1-touch-mode`; das CLI selbst akzeptiert nur die
dokumentierten Kommandos. Der beim Boot verifizierte Status liegt lesbar unter
`/run/fz-m1-touch-mode/status.json`, sodass beim Anmelden kein Passwortdialog nötig
ist.

Installation unter Debian 13:

```sh
sudo apt install python3-gi gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 pkexec
sudo install -o root -g root -m 0755 gui/fz-m1-touch-tray /usr/local/bin/
sudo install -o root -g root -m 0644 gui/io.github.michaelh1981.fz-m1-touch-mode.policy /usr/share/polkit-1/actions/
sudo install -o root -g root -m 0644 gui/fz-m1-touch-mode-tray.desktop /etc/xdg/autostart/
```

Zum sofortigen Test kann `fz-m1-touch-tray` in einer grafischen Sitzung gestartet
werden. Beim nächsten Plasma-/XFCE-Login startet es automatisch. „Aktualisieren“ und
Modusänderungen können eine Administrator-Authentifizierung anfordern; Polkit hält
eine erfolgreiche Autorisierung kurzzeitig vor.

## Automatik

Die udev-Regel erkennt ausschließlich HID-Geräte mit VID/PID `04dd:9762`; sie hängt
daher nicht am veränderlichen Namen `/dev/hidraw0`. Sobald das Gerät erscheint,
startet systemd die passende Instanz und setzt `pen-touch`:

- `/etc/udev/rules.d/99-fz-m1-touch-mode.rules`
- `/etc/systemd/system/fz-m1-touch-mode@.service`
- `/usr/local/sbin/fz-m1-touch-mode`
- `/usr/local/bin/fz-m1-touch-tray` (bei installierter GUI)
- `/usr/share/polkit-1/actions/io.github.michaelh1981.fz-m1-touch-mode.policy` (GUI)
- `/etc/xdg/autostart/fz-m1-touch-mode-tray.desktop` (GUI)

Kontrolle des aktuellen Dienstes (der hidraw-Index kann abweichen):

```sh
systemctl status 'fz-m1-touch-mode@*.service'
journalctl -b -u 'fz-m1-touch-mode@*.service'
```

Der echte Neustarttest war erfolgreich: Das Gerät erschien danach als `/dev/hidraw2`
statt zuvor `/dev/hidraw0`. Die Regel startete dennoch automatisch
`fz-m1-touch-mode@hidraw2.service`; Dienst, Modus `0x01` und alle Pen/Touch-Werte
wurden anschließend erfolgreich kontrolliert.

Ein zweiter unabhängiger Start mit erneut verändertem Gerätenamen (`hidraw4`)
bestätigte die automatische Aktivierung ebenfalls.

## Installation aus diesem Verzeichnis

```sh
sudo install -o root -g root -m 0755 tools/fz-m1-touch-mode /usr/local/sbin/
sudo install -o root -g root -m 0644 systemd/fz-m1-touch-mode@.service /etc/systemd/system/
sudo install -o root -g root -m 0644 udev/99-fz-m1-touch-mode.rules /etc/udev/rules.d/
sudo systemctl daemon-reload
sudo udevadm control --reload
sudo udevadm trigger --action=add --subsystem-match=hidraw
```

## Deinstallation und Wiederherstellung

Vor der Deinstallation kann auf Wunsch auf Touch oder Water zurückgeschaltet werden:

```sh
sudo /usr/local/sbin/fz-m1-touch-mode touch
# alternativ: sudo /usr/local/sbin/fz-m1-touch-mode water
```

Dann die Automatik und Dateien entfernen:

```sh
sudo systemctl stop 'fz-m1-touch-mode@*.service'
sudo rm /etc/udev/rules.d/99-fz-m1-touch-mode.rules
sudo rm /etc/systemd/system/fz-m1-touch-mode@.service
sudo rm -f /etc/xdg/autostart/fz-m1-touch-mode-tray.desktop
sudo rm -f /usr/share/polkit-1/actions/io.github.michaelh1981.fz-m1-touch-mode.policy
sudo rm -f /usr/local/bin/fz-m1-touch-tray
sudo rm /usr/local/sbin/fz-m1-touch-mode
sudo systemctl daemon-reload
sudo udevadm control --reload
```

Das entfernt keine Treiber- oder Firmwarebestandteile. Ein USB-Neuverbinden oder
Neustart lässt den Controller anschließend wieder ohne Linux-Automatik arbeiten.

## Änderungen am System

Neben den oben aufgelisteten Dateien wurden für die Analyse die Debian-Pakete
`unshield` und `libunshield0` installiert. Für das optionale Widget kam ausschließlich
`gir1.2-ayatanaappindicator3-0.1` hinzu; Python-GTK und Polkit waren bereits vorhanden.
Es gab keine Änderung an Firmware, Secure Boot, LUKS, TPM, GRUB, initramfs,
Partitionierung oder Kernel.

## Technische Details und Grenzen

Der vollständige Frameaufbau, die bestätigten Befehle, Register und Werte stehen in
[`NOTES.md`](NOTES.md). Der Controller meldet den passiven Stift voraussichtlich als
Touchkontakt, nicht als separates libinput-Stiftgerät; Druck, Seitentaste und Hover
sind daher nicht zu erwarten. Die elektronische Konfiguration ist bestätigt. Der
abschließende Unterschied zwischen Finger und Originalstift muss durch einen kurzen
physischen Eingabetest am Gerät bestätigt werden.

Die Regel ist bewusst auf das FZ-M1-Gerät `04dd:9762` begrenzt. Das Werkzeug sollte
nicht für andere Sharp-Controller verwendet werden.

## Primärquellen

- [Linux `hid-multitouch.c`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/hid/hid-multitouch.c)
- [Linux HID-Gerätekennungen](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/hid/hid-ids.h)
- [Microsoft: erforderliche HID-Collections für Touchscreens](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/touchscreen-required-hid-top-level-collections)
- [Panasonic FZ-M1 MK3 System Interface Manager](https://global-pc-support.connect.panasonic.com/dldocs/77402)
- [Panasonic FZ-M1 MK3 HID Drivers](https://global-pc-support.connect.panasonic.com/dldocs/77379)
- [Panasonic FZ-M1 MK3 System Interface Device](https://global-pc-support.connect.panasonic.com/dldocs/77368)
- [Panasonic: Touch Screen Mode Setting Utility / System Interface Manager](https://global-pc-support.connect.panasonic.com/dldocs/77277)

Die proprietären Befehle beruhen auf statischer Analyse der zu genau diesem Modell
gehörenden Panasonic-Pakete und anschließendem kontrollierten Readback am Gerät;
Community-Beiträge waren dafür keine Beweisgrundlage.

## Lizenz

[MIT](LICENSE) – Copyright © 2026 MichaelH1981.
