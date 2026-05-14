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

escape_for_socat_exec_var() {
    local out_var="$1"
    local input="$2"
    local escaped=""
    local i ch

    # Assigned directly to a variable so trailing newlines are preserved (command substitution strips them).
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

    printf -v "$out_var" '%s' "$escaped"
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
