#!/bin/bash
# Register an app repo with the system (creates apps/<name>.yaml).

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${1:?Usage: register-app.sh <repo-path>}"

REPO="$(cd "${REPO}" && pwd)"
CONTRACT="${REPO}/system.yaml"

if [ ! -f "${CONTRACT}" ]; then
    echo "Missing ${CONTRACT}" >&2
    echo "Copy schema/system.yaml.example to your repo as system.yaml" >&2
    exit 1
fi

APP_NAME="$(python3 - "${CONTRACT}" <<'PY'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
name = data.get("name")
if not name:
    raise SystemExit("system.yaml must set name")
print(name)
PY
)"

TARGET="${SYSTEM_ROOT}/apps/${APP_NAME}.yaml"
if [ -f "${TARGET}" ]; then
    echo "Already registered: ${TARGET}" >&2
    exit 1
fi

cat > "${TARGET}" <<EOF
repo: ${REPO}
EOF

echo "Registered ${APP_NAME} -> ${TARGET}"
python3 "${SYSTEM_ROOT}/scripts/lib/app_config.py" "${APP_NAME}" validate
