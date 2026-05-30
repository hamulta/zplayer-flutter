#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
WF="$ROOT/.github/workflows/build-apk.yml"
PUB="$ROOT/pubspec.yaml"

if [ ! -f "$WF" ] || [ ! -f "$PUB" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v040-alpha7-activity-binding/apply_alpha7.sh"
  exit 1
fi

cp "$WF" "$WF.bak.alpha7"
cp "$PUB" "$PUB.bak.alpha7"

python3 <<'PY'
from pathlib import Path
import re

wf = Path(".github/workflows/build-apk.yml")
text = wf.read_text()

# The official audio_service Android setup requires the Activity to be
# AudioServiceActivity or a custom activity subclassing it. Our previous
# alpha added service/receiver but left the default .MainActivity.
needle = """          text = re.sub(r'android:label="[^"]+"', 'android:label="Rakyzu Music Player"', text, count=1)

          if "com.ryanheise.audioservice.AudioService" not in text:
"""

insert = """          text = re.sub(
              r'android:name="\\\\.MainActivity"',
              'android:name="com.ryanheise.audioservice.AudioServiceActivity"',
              text,
              count=1,
          )

          if "com.ryanheise.audioservice.AudioService" not in text:
"""

if "AudioServiceActivity" not in text:
    if needle not in text:
        raise SystemExit("Cannot find manifest patch insertion point. Patch aborted.")
    text = text.replace(needle, insert, 1)

wf.write_text(text)

pub = Path("pubspec.yaml")
p = pub.read_text()
p = re.sub(r"version:\s*0\.4\.0\+\d+", "version: 0.4.0+14", p)
pub.write_text(p)
PY

echo
echo "Applied Rakyzu v0.4.0-alpha7 Activity binding patch."
echo "- Patches AndroidManifest activity to AudioServiceActivity in CI"
echo "- Keeps service/receiver manifest patch"
echo "- Keeps foreground playback stable"
echo "- Version bumped to 0.4.0+14"
echo
