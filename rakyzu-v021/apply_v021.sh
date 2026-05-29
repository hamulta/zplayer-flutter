#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
if [ ! -d "$ROOT/lib" ] || [ ! -f "$ROOT/pubspec.yaml" ]; then
  echo "ERROR: Jalankan script ini dari root repo zplayer-flutter."
  exit 1
fi

cp rakyzu-v021/lib/main.dart lib/main.dart

python3 <<'PY'
from pathlib import Path
import re
p = Path('pubspec.yaml')
text = p.read_text()
text = re.sub(r'(?m)^version:\s*.*$', 'version: 0.2.1+3', text)
p.write_text(text)
PY

echo "Applied Rakyzu Music Player v0.2.1 metadata polish patch."
