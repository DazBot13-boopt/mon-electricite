#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v flutter >/dev/null || { echo 'Flutter est absent. Installez le SDK Flutter puis relancez ce script.' >&2; exit 1; }
cd "$project_root/app"
if [[ -d android ]]; then
  echo 'Le dossier android existe déjà. Conservation des fichiers existants.'
else
  flutter create --platforms=android --org=dev.prototype.sbee --project-name=mon_electricite --no-pub .
fi
python3 - "$project_root/app" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
base=Path(sys.argv[1])
ns='http://schemas.android.com/apk/res/android'
ET.register_namespace('android',ns)
manifest=base/'android/app/src/main/AndroidManifest.xml'
tree=ET.parse(manifest);root=tree.getroot()
if not any(e.get('{'+ns+'}name')=='android.permission.INTERNET' for e in root.findall('uses-permission')):
    ET.SubElement(root,'uses-permission',{'{'+ns+'}name':'android.permission.INTERNET'})
root.find('application').set('{'+ns+'}label','Mon Électricité')
root.find('application').set('{'+ns+'}icon','@drawable/app_icon')
tree.write(manifest,encoding='utf-8',xml_declaration=True)
icon=base/'android/app/src/main/res/drawable/app_icon.xml'
icon.parent.mkdir(parents=True,exist_ok=True)
icon.write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android"
 android:width="48dp" android:height="48dp" android:viewportWidth="48" android:viewportHeight="48">
 <path android:fillColor="#142C46" android:pathData="M10,0 L38,0 Q48,0 48,10 L48,38 Q48,48 38,48 L10,48 Q0,48 0,38 L0,10 Q0,0 10,0 Z"/>
 <path android:fillColor="#FFD15C" android:pathData="M27,8 L15,27 L23,27 L20,40 L35,19 L27,19 Z"/>
</vector>\n''')
PY
flutter pub get
dart format lib test
echo 'Projet Android préparé. Exécutez flutter analyze puis flutter build apk --debug.'
