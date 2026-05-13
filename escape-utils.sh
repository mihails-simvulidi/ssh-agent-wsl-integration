#!/usr/bin/env bash

hex_escape_bytes() {
    local input="$1"
    local hexbytes=""
    local j

    hexbytes="$(printf '%s' "$input" | od -An -tx1 -v | tr -d ' \n')"
    local out=""
    for ((j = 0; j < ${#hexbytes}; j += 2)); do
        out+="\\x${hexbytes:j:2}"
    done

    printf '%s' "$out"
}

escape_for_socat_exec() {
    local input="$1"
    local escaped=""
    local i ch

    # Escape for socat's EXEC parser.
    for ((i = 0; i < ${#input}; i++)); do
        ch="${input:i:1}"
        case "$ch" in
            ','|':')
                escaped+="\\${ch}"
                ;;
            ' ')
                escaped+="\\\\${ch}"
                ;;
            '"'|"'"|'('| '['|$'\\'|'{')
                escaped+="\\\\\\${ch}"
                ;;
            *)
                escaped+="$ch"
                ;;
        esac
    done

    printf '%s' "$escaped"
}

escape_for_systemd_execstart() {
    local input="$1"
    local out=""
    local i ch ord

    for ((i = 0; i < ${#input}; i++)); do
        ch="${input:i:1}"
        LC_CTYPE=C printf -v ord '%d' "'$ch"
        # Keep ExecStart token parsing deterministic.
        if (( ord < 32 || ord > 126 )) || [[ "$ch" == ' ' || "$ch" == '"' || "$ch" == "'" || "$ch" == $'\\' ]]; then
            out+="$(hex_escape_bytes "$ch")"
        else
            out+="$ch"
        fi
    done

    printf '%s' "$out"
}

escape_for_systemd_execstart_socat_exec() {
    local input="$1"
    local socat_exec_arg=""

    socat_exec_arg="EXEC:$(escape_for_socat_exec "$input"; printf '.')"
    socat_exec_arg="${socat_exec_arg%.}"

    local arg
    for arg in "${@:2}"; do
        socat_exec_arg+=" $(escape_for_socat_exec "$arg"; printf '.')"
        socat_exec_arg="${socat_exec_arg%.}"
    done

    escape_for_systemd_execstart "$socat_exec_arg"
}