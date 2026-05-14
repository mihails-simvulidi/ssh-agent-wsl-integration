#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./escape-utils.sh
source "$SCRIPT_DIR/escape-utils.sh"

# Usage:
#   ./test-escaping.sh            # tests bytes 0..255
#   ./test-escaping.sh 127        # tests bytes 0..127
#   ./test-escaping.sh 255 /tmp/custom.sock

MAX_CODE="${1:-255}"
SOCKET_PATH="${2:-/tmp/socat-escape-e2e-${UID}.sock}"
TEST_DIR="$(mktemp -d)"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SYSTEMD_PREFIX="socat-escape-e2e"
SYSTEMD_RUNTIME_DIR="/tmp/${SYSTEMD_PREFIX}-${UID}"
KEEP_ARTIFACTS="${KEEP_ARTIFACTS:-0}"
PARALLEL_JOBS="${PARALLEL_JOBS:-8}"

if ! [[ "$MAX_CODE" =~ ^[0-9]+$ ]]; then
    echo "MAX_CODE must be an integer" >&2
    exit 1
fi

if (( MAX_CODE < 0 || MAX_CODE > 255 )); then
    echo "MAX_CODE must be in range 0..255" >&2
    exit 1
fi

if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || (( PARALLEL_JOBS < 1 )); then
    echo "PARALLEL_JOBS must be an integer >= 1" >&2
    exit 1
fi

if ! command -v socat >/dev/null 2>&1; then
    echo "socat not found in PATH" >&2
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemctl not found in PATH" >&2
    exit 1
fi

if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "systemctl --user is not available in this session" >&2
    exit 1
fi

mkdir -p "$SYSTEMD_RUNTIME_DIR" "$SYSTEMD_USER_DIR"

listener_pid=""
created_units=()
cleanup() {
    if [[ -n "$listener_pid" ]]; then
        kill "$listener_pid" >/dev/null 2>&1 || true
        wait "$listener_pid" 2>/dev/null || true
    fi

    rm -f "$SOCKET_PATH"
    rm -rf "$SYSTEMD_RUNTIME_DIR"

    for unit_name in "${created_units[@]}"; do
        rm -f "${SYSTEMD_USER_DIR}/${unit_name}"
    done

    if ((${#created_units[@]} > 0)); then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi

    if [[ "$KEEP_ARTIFACTS" != "1" ]]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT

# Stable sink listener for second socat address in every test case.
socat -T1 -u "UNIX-LISTEN:${SOCKET_PATH},fork,unlink-early" OPEN:/dev/null,rdonly >/dev/null 2>&1 &
listener_pid=$!

success_count=0
not_found_count=0
other_fail_count=0
skipped_count=0
runnable_codes=()

# Count runnable cases to display deterministic progress.
run_total=$((MAX_CODE + 1))
if (( MAX_CODE >= 0 )); then
    run_total=$((run_total - 1))
fi
if (( MAX_CODE >= 47 )); then
    run_total=$((run_total - 1))
fi
completed_count=0

print_progress() {
    local current="$1"
    local total="$2"
    local pct=100

    if (( total > 0 )); then
        pct=$(( current * 100 / total ))
    fi

    printf '\r[PROGRESS] %d/%d (%d%%)' "$current" "$total" "$pct"
}

echo "Running end-to-end escaping tests: 0..${MAX_CODE}"
print_progress 0 "$run_total"

for ((code = 0; code <= MAX_CODE; code++)); do
    printf -v hex '%02x' "$code"
    printf -v chr '%b' "\\x${hex}"

    path="${TEST_DIR}/file_${code}_${chr}"
    abs_path="$path"

    if (( code == 0 )); then
        ((skipped_count += 1))
        printf '\n'
        printf '[SKIP] code=%d reason=NUL_not_representable\n' "$code"
        print_progress "$completed_count" "$run_total"
        continue
    fi

    if (( code == 47 )); then
        ((skipped_count += 1))
        printf '\n'
        printf '[SKIP] code=%d reason=slash_not_allowed_in_component\n' "$code"
        print_progress "$completed_count" "$run_total"
        continue
    fi

    cat > "$path" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$path"

    escape_for_socat_exec_var abs_path_escaped "$abs_path"
    exec_addr_unit="$(escape_for_systemd_execstart "EXEC:${abs_path_escaped}")"
    connect_addr_unit="$(escape_for_systemd_execstart "UNIX-CONNECT:${SOCKET_PATH}")"

    unit_name="${SYSTEMD_PREFIX}-${code}.service"
    unit_path="${SYSTEMD_USER_DIR}/${unit_name}"
    err_file="${SYSTEMD_RUNTIME_DIR}/err-${code}.log"
    start_err_file="${SYSTEMD_RUNTIME_DIR}/start-${code}.log"

    : > "$err_file"
    : > "$start_err_file"

    cat > "$unit_path" <<EOF
[Unit]
Description=Socat/systemd escape e2e test ${code}

[Service]
Type=oneshot
ExecStart=socat -T1 ${exec_addr_unit} ${connect_addr_unit}
StandardOutput=null
StandardError=file:${err_file}
EOF

    created_units+=("$unit_name")
    runnable_codes+=("$code")
done

systemctl --user daemon-reload >/dev/null 2>&1

run_case() {
    local code="$1"
    local unit_name="${SYSTEMD_PREFIX}-${code}.service"
    local err_file="${SYSTEMD_RUNTIME_DIR}/err-${code}.log"
    local start_err_file="${SYSTEMD_RUNTIME_DIR}/start-${code}.log"
    local status_file="${SYSTEMD_RUNTIME_DIR}/status-${code}.txt"
    local err_text=""

    systemctl --user reset-failed "$unit_name" >/dev/null 2>&1 || true
    if systemctl --user start "$unit_name" >/dev/null 2>"$start_err_file"; then
        printf 'OK\n' > "$status_file"
        return 0
    fi

    if [[ -s "$err_file" ]]; then
        err_text="$(<"$err_file")"
    elif [[ -s "$start_err_file" ]]; then
        err_text="$(<"$start_err_file")"
    else
        err_text="systemd service failed without stderr output"
    fi

    if grep -qiE 'no such file|not found' <<<"$err_text"; then
        printf 'NOT_FOUND\n%s\n' "$err_text" > "$status_file"
    else
        printf 'FAIL\n%s\n' "$err_text" > "$status_file"
    fi
}

active_jobs=0
pids=()
for code in "${runnable_codes[@]}"; do
    run_case "$code" &
    pids+=("$!")
    ((active_jobs += 1))

    if (( active_jobs >= PARALLEL_JOBS )); then
        wait "${pids[0]}" || true
        pids=("${pids[@]:1}")
        ((active_jobs -= 1))
        ((completed_count += 1))
        print_progress "$completed_count" "$run_total"
    fi
done

for pid in "${pids[@]}"; do
    wait "$pid" || true
    ((completed_count += 1))
    print_progress "$completed_count" "$run_total"
done

printf '\n'

for code in "${runnable_codes[@]}"; do
    printf -v hex '%02x' "$code"
    printf -v chr '%b' "\\x${hex}"
    path="${TEST_DIR}/file_${code}_${chr}"

    status_file="${SYSTEMD_RUNTIME_DIR}/status-${code}.txt"
    status="$(sed -n '1p' "$status_file")"
    if [[ "$status" == "OK" ]]; then
        ((success_count += 1))
        continue
    fi

    err_text="$(sed -n '2,$p' "$status_file")"
    if [[ "$status" == "NOT_FOUND" ]]; then
        ((not_found_count += 1))
        printf '[MISS] code=%d repr=%q err=%q\n' "$code" "$path" "$err_text"
    else
        ((other_fail_count += 1))
        printf '[FAIL] code=%d repr=%q err=%q\n' "$code" "$path" "$err_text"
    fi
done

echo "--- summary ---"
printf 'success=%d\n' "$success_count"
printf 'not_found=%d\n' "$not_found_count"
printf 'other_fail=%d\n' "$other_fail_count"
printf 'skipped=%d\n' "$skipped_count"

if (( not_found_count > 0 || other_fail_count > 0 )); then
    exit 1
fi
