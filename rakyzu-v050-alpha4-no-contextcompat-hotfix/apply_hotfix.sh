#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
WF="$ROOT/.github/workflows/build-apk.yml"
PUB="$ROOT/pubspec.yaml"

if [ ! -f "$WF" ] || [ ! -f "$PUB" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v050-alpha4-no-contextcompat-hotfix/apply_hotfix.sh"
  exit 1
fi

cp "$WF" "$WF.bak.v050_alpha4"
cp "$PUB" "$PUB.bak.v050_alpha4"

python3 <<'PY'
from pathlib import Path
import re

wf = Path(".github/workflows/build-apk.yml")
text = wf.read_text()

# Remove old fragile ContextCompat repair step if present.
text = re.sub(
    r"\n      - name: Fix native ContextCompat import\n        run: \|\n          python3 <<'PY2'\n.*?\n          PY2\n",
    "\n",
    text,
    flags=re.S,
)

step = '''      - name: Patch native foreground service starter
        run: |
          python3 <<'PY2'
          from pathlib import Path

          fixed = False
          replacement = (
              "if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {\\n"
              "                context.startForegroundService(intent)\\n"
              "            } else {\\n"
              "                @Suppress(\\"DEPRECATION\\")\\n"
              "                context.startService(intent)\\n"
              "            }"
          )

          for file in Path("android/app/src/main/kotlin").rglob("RakyzuMediaService.kt"):
              text = file.read_text()

              text = text.replace("import androidx.core.app.ContextCompat\\n", "")
              text = text.replace("import androidx.core.content.ContextCompat\\n", "")
              text = text.replace("ContextCompat.startForegroundService(context, intent)", replacement)

              file.write_text(text)
              print("Patched:", file)
              print(text)
              fixed = True

          if not fixed:
              raise SystemExit("RakyzuMediaService.kt not found")
          PY2

'''

if "Patch native foreground service starter" not in text:
    marker = "      - name: Force Android app display name\n"
    if marker not in text:
        raise SystemExit("Cannot find insertion marker 'Force Android app display name'. Hotfix aborted.")
    text = text.replace(marker, step + marker, 1)

# Also patch any literal Kotlin snippet in workflow if it exists unencoded.
text = text.replace("import androidx.core.app.ContextCompat\\n", "")
text = text.replace("import androidx.core.content.ContextCompat\\n", "")
text = text.replace("import androidx.core.app.ContextCompat", "")
text = text.replace("import androidx.core.content.ContextCompat", "")

wf.write_text(text)

pub = Path("pubspec.yaml")
p = pub.read_text()
p = re.sub(r"version:\s*0\.5\.0\+\d+", "version: 0.5.0+21", p)
p = re.sub(r"version:\s*0\.4\.[^\n]+", "version: 0.5.0+21", p)
pub.write_text(p)
PY

echo
echo "Applied Rakyzu v0.5.0-alpha4 no-ContextCompat hotfix."
echo "- Removes ContextCompat dependency from native service"
echo "- Uses context.startForegroundService/startService directly"
echo "- Adds CI patch step after native service generation"
echo "- Version bumped to 0.5.0+21"
echo
