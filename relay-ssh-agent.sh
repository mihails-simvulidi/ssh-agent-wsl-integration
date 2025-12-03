#!/bin/sh
set -e

WINUSERPROFILE=$(cmd.exe /C ECHO %USERPROFILE% | tr -d '\r')
NPIPERELAY="$(wslpath "$WINUSERPROFILE")/AppData/Local/Microsoft/WinGet/Packages/jstarks.npiperelay_Microsoft.Winget.Source_8wekyb3d8bbwe/npiperelay.exe"
exec socat "EXEC:${NPIPERELAY} -p //./pipe/openssh-ssh-agent" "UNIX-LISTEN:${XDG_RUNTIME_DIR}/ssh-agent.socket"
