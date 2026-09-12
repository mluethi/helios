# Fedora Server 44 - HELIOS
#
# DURCHGANG 2. Erst benutzen, wenn Durchgang 1 steht und die Werte unten
# bekannt sind. Vorher pruefen:
#
#   ksvalidator -v F44 kickstart/helios.ks
#
# Die Platzhalter in spitzen Klammern kommen aus Durchgang 1:
#   <IP> <GATEWAY> <DNS>  - aus der OPNsense
#   <PLATTE>              - aus "lsblk", z. B. nvme0n1 oder sda
#   <DEIN-KEY>            - oeffentlicher SSH-Key vom Mac

cdrom
lang de_CH.UTF-8
keyboard ch
timezone Europe/Zurich --utc
timesource --ntp-server=ch.pool.ntp.org
reboot --eject

# Sicherheit
selinux --enforcing
firewall --enabled --service=ssh --service=cockpit

# Netzwerk
# "link" nimmt das erste verbundene Interface. Sobald die MAC-Adresse des
# ProDesk notiert ist, darauf umstellen: --device=aa:bb:cc:dd:ee:ff
# Kickstart kennt KEINE Zeilenfortsetzung mit Backslash - die Zeile muss
# in einem Stueck stehen, so lang sie auch wird.
network --bootproto=static --device=link --activate --ip=<IP> --netmask=255.255.255.0 --gateway=<GATEWAY> --nameserver=<DNS> --hostname=helios.rubi

# Benutzer
# Kein Passwort-Hash auf dem Stick - ein SHA-512-Hash in der Schublade ist
# offline angreifbar. Anmeldung nur per Schluessel, Passwort danach mit
# "sudo passwd marcello" setzen.
rootpw --lock
user --name=marcello --gecos="Marcello" --groups=wheel --lock
sshkey --username=marcello "ssh-ed25519 AAAA<DEIN-KEY>"

# Platten
# ACHTUNG: clearpart loescht die angegebene Platte vollstaendig.
# ignoredisk ist die Versicherung gegen die falsche Platte.
# In einer Test-VM heisst die Platte "vda", nicht wie auf dem Blech.
ignoredisk --only-use=<PLATTE>
clearpart --all --initlabel --drives=<PLATTE>
# --nohome: sonst frisst /home den Platz, den /var/lib/containers braucht.
autopart --type=lvm --nohome

# Kein "bootloader": Der ProDesk bootet per UEFI, dort ist --location=mbr
# gegenstandslos. Anaconda macht das Richtige von allein.

# Dienste
services --enabled=cockpit.socket,sshd

# Kein %post-Abschnitt: "systemctl --now" funktioniert in der chroot des
# Installers nicht, und "services" oben erledigt dasselbe zuverlaessig.
# Alles Weitere macht das Ansible-Playbook.

%packages
@^server-product-environment
podman
ansible-core
git-core
policycoreutils-python-utils
tmux
%end
