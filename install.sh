#!/bin/sh
set -e
scriptdir=$(dirname "$0")
systemddir=~/.config/systemd/user/

sudo apt-get install -y socat
winget.exe install -e --id jstarks.npiperelay || true
sudo install "$scriptdir/set-ssh-agent.sh" /etc/profile.d/
mkdir -p "$systemddir"
install "$scriptdir/relay-ssh-agent.service" "$systemddir"
systemctl --user daemon-reload
systemctl --user enable relay-ssh-agent.service
systemctl --user restart relay-ssh-agent.service
