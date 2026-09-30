#!/usr/bin/env bash
set -euo pipefail

if [ -z "$MSYSTEM" ]; then
    echo "Script must be run via git bash"
    exit 0
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for command_name in powershell.exe cygpath; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 1
    fi
done

POWERSHELL_SCRIPT="$SCRIPT_DIR/install-root-ca.ps1"
if [[ ! -f "$POWERSHELL_SCRIPT" ]]; then
    printf 'PowerShell installer not found: %s\n' "$POWERSHELL_SCRIPT" >&2
    exit 1
fi

exec powershell.exe -NoProfile -File "$(cygpath -w "$POWERSHELL_SCRIPT")"
