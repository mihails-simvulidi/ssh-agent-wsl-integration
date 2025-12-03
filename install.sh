#!/bin/sh
set -e
repodir=$(dirname "$0")
scriptinstalldir=~/.local
systemddir=~/.config/systemd/user

sudo apt-get install -y socat
winget.exe install -e --id jstarks.npiperelay || true
sudo install "$repodir/set-ssh-agent.sh" /etc/profile.d/
mkdir -p "$scriptinstalldir" "$systemddir"
install "$repodir/relay-ssh-agent.sh" "$scriptinstalldir/"
install "$repodir/relay-ssh-agent.service" "$systemddir/"
systemctl --user daemon-reload
systemctl --user enable relay-ssh-agent.service
systemctl --user restart relay-ssh-agent.service
