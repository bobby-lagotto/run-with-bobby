#!/usr/bin/env bash
set -euo pipefail

tracked_env_files="$(git ls-files '.env' '.env.*' || true)"
if [[ -n "${tracked_env_files}" ]]; then
  echo "Tracked env files are not allowed:"
  echo "${tracked_env_files}"
  exit 1
fi

set +e
matches="$(git grep -n -E \
  -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' \
  -e 'sk-[A-Za-z0-9_-]{32,}' \
  -e 'sk-ant-[A-Za-z0-9_-]{20,}' \
  -e 'sk-or-[A-Za-z0-9_-]{20,}' \
  -e 'whsec_[A-Za-z0-9]{20,}' \
  -e 'AKIA[0-9A-Z]{16}' \
  -e 'ghp_[0-9A-Za-z]{36}' \
  -e 'DATABASE_URL=.*://' \
  -e 'PRIVATE_KEY=.*[^[:space:]]' \
  -- ':!scripts/scan-secrets.sh')"
grep_status=$?
set -e

if [[ ${grep_status} -gt 1 ]]; then
  echo "Secret scan failed while reading tracked files."
  exit "${grep_status}"
fi

if [[ -n "${matches}" ]]; then
  echo "Potential secrets found in tracked files:"
  echo "${matches}"
  echo "Remove the values, rotate exposed credentials, then rerun this script."
  exit 1
fi

echo "No tracked secrets found."
