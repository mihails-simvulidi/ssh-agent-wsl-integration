#!/bin/sh
set -e
scriptdir=$(dirname "$0")

apt-get install -y socat
winget.exe install -e --id jstarks.npiperelay
install "$scriptdir/set-ssh-agent.sh" /etc/profile.d/
install "$scriptdir/relay-ssh-agent.service" /etc/systemd/system/
systemctl daemon-reload
