#!/bin/sh
set -e
scriptdir=$(dirname "$0")

sudo apt-get install -y socat
winget.exe install -e --id jstarks.npiperelay || true
sudo install "$scriptdir/set-ssh-agent.sh" /etc/profile.d/
install "$scriptdir/relay-ssh-agent.service" ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable relay-ssh-agent.service
systemctl --user restart relay-ssh-agent.service
