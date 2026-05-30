#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
WF="$ROOT/.github/workflows/build-apk.yml"
PUB="$ROOT/pubspec.yaml"

if [ ! -f "$WF" ] || [ ! -f "$PUB" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v050-alpha3-contextcompat-hotfix/apply_hotfix.sh"
  exit 1
fi

cp "$WF" "$WF.bak.v050_alpha3"
cp "$PUB" "$PUB.bak.v050_alpha3"

python3 <<'PY'
from pathlib import Path
import re

wf = Path(".github/workflows/build-apk.yml")
text = wf.read_text()

step = """      - name: Fix native ContextCompat import
        run: |
          python3 <<'PY2'
          from pathlib import Path

          fixed = False
          for file in Path("android/app/src/main/kotlin").rglob("RakyzuMediaService.kt"):
              text = file.read_text()
              text = text.replace(
                  "import androidx.core.app.ContextCompat",
                  "import androidx.core.content.ContextCompat",
              )
              file.write_text(text)
              print("Fixed:", file)
              print(text)
              fixed = True

          if not fixed:
              raise SystemExit("RakyzuMediaService.kt not found")
          PY2

"""

if "Fix native ContextCompat import" not in text:
    marker = "      - name: Force Android app display name\n"
    if marker not in text:
        raise SystemExit("Cannot find insertion marker 'Force Android app display name'. Hotfix aborted.")
    text = text.replace(marker, step + marker, 1)

# If any raw Kotlin snippet is present unencoded in workflow, fix that too.
text = text.replace(
    "import androidx.core.app.ContextCompat",
    "import androidx.core.content.ContextCompat",
)

wf.write_text(text)

pub = Path("pubspec.yaml")
p = pub.read_text()
p = re.sub(r"version:\s*0\.5\.0\+\d+", "version: 0.5.0+20", p)
p = re.sub(r"version:\s*0\.4\.[^\n]+", "version: 0.5.0+20", p)
pub.write_text(p)
PY

echo
echo "Applied Rakyzu v0.5.0-alpha3 ContextCompat hotfix."
echo "- Fixes Kotlin import: androidx.core.content.ContextCompat"
echo "- Adds CI repair step after native service generation"
echo "- Version bumped to 0.5.0+20"
echo
