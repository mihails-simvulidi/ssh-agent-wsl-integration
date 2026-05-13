#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./escape-utils.sh
source "$SCRIPT_DIR/escape-utils.sh"

sudo apt-get install --no-install-recommends -y socat
winget.exe install -e --id jstarks.npiperelay || true

systemddir="$HOME/.config/systemd/user"
mkdir -p "$systemddir"

npiperelay_exe_path="$(command -v npiperelay.exe || true)"
if [ -z "$npiperelay_exe_path" ]; then
    echo "npiperelay.exe not found in PATH" >&2
    exit 1
fi
if ! command -v socat >/dev/null 2>&1; then
    echo "socat not found in PATH" >&2
    exit 1
fi

cat <<EOF > "$systemddir/relay-ssh-agent.service"
[Service]
ExecStart=socat -dd $(escape_for_systemd_execstart_socat_exec "$npiperelay_exe_path" -p //./pipe/openssh-ssh-agent) $(escape_for_systemd_execstart "UNIX-LISTEN:%t/ssh-agent.socket,fork")
Restart=always

[Install]
WantedBy=default.target
EOF

cat <<'EOF' | sudo tee /etc/profile.d/ssh-agent.sh >/dev/null
if [ -n "$XDG_RUNTIME_DIR" ]; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR%/}/ssh-agent.socket"
fi
EOF

systemctl --user daemon-reload
systemctl --user enable relay-ssh-agent.service
systemctl --user restart relay-ssh-agent.service
