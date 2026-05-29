#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$ROOT/lib" ] || [ ! -f "$ROOT/pubspec.yaml" ]; then
  echo "ERROR: Jalankan script ini dari root repo Flutter: ~/zplayer-flutter"
  exit 1
fi

cp "$PATCH_DIR/lib/main.dart" "$ROOT/lib/main.dart"

python3 <<'PY'
from pathlib import Path
p = Path('pubspec.yaml')
text = p.read_text()
lines = text.splitlines()
out = []
changed = False
for line in lines:
    if line.startswith('version:'):
        out.append('version: 0.2.0+2')
        changed = True
    else:
        out.append(line)
if not changed:
    out.insert(1, 'version: 0.2.0+2')
p.write_text('\n'.join(out) + '\n')
PY

if [ -f README.md ]; then
python3 <<'PY'
from pathlib import Path
p = Path('README.md')
text = p.read_text()
text = text.replace('ZPlayer Offline', 'Rakyzu Music Player')
text = text.replace('Native Flutter local music player', 'Premium offline music player')
p.write_text(text)
PY
fi

echo "Applied Rakyzu Music Player v0.2.0 patch."
