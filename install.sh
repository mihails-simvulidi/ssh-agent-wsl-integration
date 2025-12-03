#!/bin/sh
set -e
repodir=$(dirname "$0")
systemddir=~/.config/systemd/user

sudo apt-get install -y socat
winget.exe install -e --id jstarks.npiperelay || true
mkdir -p "$systemddir"

cat <<EOF >$systemddir/relay-ssh-agent.service
[Install]
WantedBy=default.target

[Service]
Environment="PATH=$PATH"
ExecStart=socat "EXEC:npiperelay.exe -p //./pipe/openssh-ssh-agent" "UNIX-LISTEN:\${XDG_RUNTIME_DIR}/ssh-agent.socket"
EOF

cat <<EOF >/etc/profile.d/ssh-agent.sh
if [ -n "$XDG_RUNTIME_DIR" ]; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}ssh-agent.socket"
fi
EOF

systemctl --user daemon-reload
systemctl --user enable relay-ssh-agent.service
systemctl --user restart relay-ssh-agent.service
