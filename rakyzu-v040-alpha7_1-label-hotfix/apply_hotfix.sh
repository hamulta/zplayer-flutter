#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
WF="$ROOT/.github/workflows/build-apk.yml"
PUB="$ROOT/pubspec.yaml"

if [ ! -f "$WF" ] || [ ! -f "$PUB" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v040-alpha7_1-label-hotfix/apply_hotfix.sh"
  exit 1
fi

cp "$WF" "$WF.bak.alpha7_1"
cp "$PUB" "$PUB.bak.alpha7_1"

python3 <<'PY'
from pathlib import Path
import re

wf = Path(".github/workflows/build-apk.yml")
text = wf.read_text()

step = """
      - name: Force Android app display name
        run: |
          python3 <<'PY2'
          from pathlib import Path
          import re

          manifest = Path("android/app/src/main/AndroidManifest.xml")
          text = manifest.read_text()

          if 'android:label="' in text:
              text = re.sub(
                  r'android:label="[^"]+"',
                  'android:label="Rakyzu Music Player"',
                  text,
                  count=1,
              )
          else:
              text = text.replace(
                  "    <application",
                  '    <application android:label="Rakyzu Music Player"',
                  1,
              )

          manifest.write_text(text)
          print(text)
          PY2

"""

if "Force Android app display name" not in text:
    marker = "      - name: Get dependencies\n"
    if marker not in text:
        raise SystemExit("Cannot find Get dependencies marker. Patch aborted.")
    text = text.replace(marker, step + marker, 1)

wf.write_text(text)

pub = Path("pubspec.yaml")
p = pub.read_text()
p = re.sub(r"version:\s*0\.4\.0\+\d+", "version: 0.4.0+15", p)
pub.write_text(p)
PY

echo
echo "Applied Rakyzu v0.4.0-alpha7.1 label hotfix."
echo "- Adds a dedicated CI step that forces Android app label to Rakyzu Music Player"
echo "- Prevents flutter create project_name fallback from showing zplayer_offline"
echo "- Version bumped to 0.4.0+15"
echo
