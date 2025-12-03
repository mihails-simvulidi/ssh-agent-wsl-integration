#!/bin/sh
set -e

WINUSERPROFILE=$(cmd.exe /C ECHO %USERPROFILE% | tr -d '\r')
export PATH="$(wslpath "$WINUSERPROFILE")/AppData/Local/Microsoft/WinGet/Packages/jstarks.npiperelay_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
exec socat "EXEC:npiperelay.exe -p //./pipe/openssh-ssh-agent" "UNIX-LISTEN:$XDG_RUNTIME_DIR/ssh-agent.socket"
