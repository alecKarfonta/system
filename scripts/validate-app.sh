#!/bin/bash
# Validate that an app repo meets the system deploy contract.

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:?Usage: validate-app.sh <app>}"

exec python3 "${SYSTEM_ROOT}/scripts/lib/app_config.py" "${APP}" validate
