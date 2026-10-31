#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v adb >/dev/null || { echo 'adb est absent du PATH.' >&2; exit 1; }
command -v flutter >/dev/null || { echo 'Flutter est absent du PATH.' >&2; exit 1; }
device_id="${1:-}"
if [[ -z "$device_id" ]]; then
  echo 'Branchez votre téléphone, autorisez le débogage USB, puis choisissez son identifiant :'
  adb devices
  echo 'Relancez : bash scripts/test_phone.sh IDENTIFIANT_DU_TELEPHONE'
  exit 1
fi
cd "$project_root/app"
flutter run -d "$device_id"
