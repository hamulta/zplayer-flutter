#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
WF="$ROOT/.github/workflows/build-apk.yml"
PUB="$ROOT/pubspec.yaml"

if [ ! -f "$WF" ] || [ ! -f "$PUB" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v050-alpha2-python-fstring-hotfix/apply_hotfix.sh"
  exit 1
fi

cp "$WF" "$WF.bak.v050_alpha2"
cp "$PUB" "$PUB.bak.v050_alpha2"

python3 <<'PY'
from pathlib import Path
import re

wf = Path(".github/workflows/build-apk.yml")
text = wf.read_text()

# Fix Python f-string SyntaxError inside CI:
# f"android {\n ..." is invalid because the literal { must be escaped.
# Safer: avoid f-string for this line.
bad_variants = [
    '''text = text.replace("android {", f"android {\\n    namespace '{namespace}'", 1)''',
    '''text = text.replace("android {", f"android {\\n    namespace \\'{namespace}\\'", 1)''',
    '''text = text.replace("android {", f"android {\\\\n    namespace '{namespace}'", 1)''',
    '''text = text.replace("android {", f"android {\\\\n    namespace \\'{namespace}\\'", 1)''',
]

fixed = '''text = text.replace("android {", "android {\\\\n    namespace '" + namespace + "'", 1)'''

changed = False
for bad in bad_variants:
    if bad in text:
        text = text.replace(bad, fixed)
        changed = True

# More tolerant regex fallback for formatting/spacing differences.
pattern = r'''text\s*=\s*text\.replace\("android \{",\s*f"android \{(\\\\n|\\n)\s+namespace ['\\"]\{namespace\}['\\"]",\s*1\)'''
text2, count = re.subn(pattern, fixed, text)
if count:
    text = text2
    changed = True

if not changed:
    print("No exact f-string issue found; continuing. Current workflow may already be fixed.")

# Also prevent the same bug if the script was accidentally converted to android {{ variants.
text = text.replace(
    '''text = text.replace("android {{", f"android {{\\n    namespace '{namespace}'", 1)''',
    '''text = text.replace("android {", "android {\\\\n    namespace '" + namespace + "'", 1)'''
)

wf.write_text(text)

pub = Path("pubspec.yaml")
p = pub.read_text()
p = re.sub(r"version:\s*0\.5\.0\+\d+", "version: 0.5.0+19", p)
p = re.sub(r"version:\s*0\.4\.[^\n]+", "version: 0.5.0+19", p)
pub.write_text(p)
PY

echo
echo "Applied Rakyzu v0.5.0-alpha2 Python f-string hotfix."
echo "- Fixes SyntaxError in on_audio_query Gradle patch step"
echo "- Escapes/removes invalid literal '{' inside Python f-string"
echo "- Version bumped to 0.5.0+19"
echo
