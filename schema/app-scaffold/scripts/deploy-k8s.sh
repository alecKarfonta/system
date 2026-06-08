#!/usr/bin/env bash
set -euo pipefail
SYSTEM_ROOT="${SYSTEM_ROOT:-${HOME}/git/system}"
exec "${SYSTEM_ROOT}/scripts/deploy-app.sh" __APP_NAME__ "${1:-deploy}"
