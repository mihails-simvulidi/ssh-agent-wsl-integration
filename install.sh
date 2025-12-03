#!/bin/sh
set -e
scriptdir=$(dirname "$0")

sudo apt-get install -y socat
winget.exe install -e --id jstarks.npiperelay
sudo install "$scriptdir/set-ssh-agent.sh" /etc/profile.d/
sudo install "$scriptdir/relay-ssh-agent.service" /etc/systemd/system/
sudo systemctl daemon-reload
