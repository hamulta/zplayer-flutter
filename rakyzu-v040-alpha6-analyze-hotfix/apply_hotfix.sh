#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
MAIN="$ROOT/lib/main.dart"
PUB="$ROOT/pubspec.yaml"

if [ ! -f "$MAIN" ] || [ ! -f "$PUB" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v040-alpha6-analyze-hotfix/apply_hotfix.sh"
  exit 1
fi

cp "$MAIN" "$MAIN.bak.alpha6_analyze"
cp "$PUB" "$PUB.bak.alpha6_analyze"

python3 <<'PY'
from pathlib import Path
import re

main = Path("lib/main.dart")
text = main.read_text()

# Fix analyzer error:
# _syncNotificationState() returns void, so it must not be awaited.
text = text.replace("await _syncNotificationState();", "_syncNotificationState();")

# Remove unused stop bridge if present. It is not needed in alpha6 yet.
text = re.sub(
    r"\n  Future<void> _requestStopFromService\(\) async \{.*?\n  \}\n",
    "\n",
    text,
    count=1,
    flags=re.S,
)

main.write_text(text)

pub = Path("pubspec.yaml")
p = pub.read_text()
p = re.sub(r"version:\s*0\.4\.0\+\d+", "version: 0.4.0+13", p)
pub.write_text(p)
PY

echo
echo "Applied Rakyzu v0.4.0-alpha6.1 analyze hotfix."
echo "- Removed invalid await on _syncNotificationState()"
echo "- Removed unused _requestStopFromService() bridge"
echo "- Version bumped to 0.4.0+13"
echo
