#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
WF="$ROOT/.github/workflows/build-apk.yml"
PUB="$ROOT/pubspec.yaml"

if [ ! -f "$WF" ] || [ ! -f "$PUB" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v050-alpha1-gradle-kts-hotfix/apply_hotfix.sh"
  exit 1
fi

cp "$WF" "$WF.bak.v050_alpha1"
cp "$PUB" "$PUB.bak.v050_alpha1"

python3 <<'PY'
from pathlib import Path
import re

wf = Path(".github/workflows/build-apk.yml")
text = wf.read_text()

old = '''          gradle = Path("android/app/build.gradle")
          g = gradle.read_text()

          deps = [
              'implementation "androidx.core:core-ktx:1.13.1"',
              'implementation "androidx.media:media:1.7.0"',
          ]

          if "dependencies {" not in g:
              g += "\\n\\ndependencies {\\n}\\n"

          for dep in deps:
              if dep not in g:
                  g = g.replace("dependencies {", "dependencies {\\n    " + dep, 1)

          g = re.sub(r'compileSdk\\\\s*=?\\\\s*\\\\d+', 'compileSdk 35', g)
          g = re.sub(r'compileSdkVersion\\\\s+\\\\d+', 'compileSdkVersion 35', g)

          gradle.write_text(g)
          print(g)
'''

new = '''          gradle = Path("android/app/build.gradle")
          gradle_kts = Path("android/app/build.gradle.kts")

          if gradle.exists():
              g = gradle.read_text()

              deps = [
                  'implementation "androidx.core:core-ktx:1.13.1"',
                  'implementation "androidx.media:media:1.7.0"',
              ]

              if "dependencies {" not in g:
                  g += "\\n\\ndependencies {\\n}\\n"

              for dep in deps:
                  if dep not in g:
                      g = g.replace("dependencies {", "dependencies {\\n    " + dep, 1)

              g = re.sub(r'compileSdk\\\\s*=?\\\\s*\\\\d+', 'compileSdk 35', g)
              g = re.sub(r'compileSdkVersion\\\\s+\\\\d+', 'compileSdkVersion 35', g)

              gradle.write_text(g)
              print("Patched Groovy Gradle:", gradle)
              print(g)

          elif gradle_kts.exists():
              g = gradle_kts.read_text()

              deps = [
                  'implementation("androidx.core:core-ktx:1.13.1")',
                  'implementation("androidx.media:media:1.7.0")',
              ]

              if "dependencies {" not in g:
                  g += "\\n\\ndependencies {\\n}\\n"

              for dep in deps:
                  if dep not in g:
                      g = g.replace("dependencies {", "dependencies {\\n    " + dep, 1)

              g = re.sub(r'compileSdk\\\\s*=\\\\s*\\\\d+', 'compileSdk = 35', g)
              g = re.sub(r'compileSdkVersion\\\\(\\\\d+\\\\)', 'compileSdkVersion(35)', g)

              gradle_kts.write_text(g)
              print("Patched Kotlin Gradle:", gradle_kts)
              print(g)

          else:
              raise SystemExit("Neither android/app/build.gradle nor android/app/build.gradle.kts exists")
'''

if old not in text:
    start = text.find('          gradle = Path("android/app/build.gradle")')
    if start == -1:
        raise SystemExit("Cannot find Gradle patch block in workflow. Hotfix aborted.")
    end_marker = '          print(g)\n'
    end = text.find(end_marker, start)
    if end == -1:
        raise SystemExit("Cannot find end of Gradle patch block. Hotfix aborted.")
    end += len(end_marker)
    text = text[:start] + new + text[end:]
else:
    text = text.replace(old, new, 1)

wf.write_text(text)

pub = Path("pubspec.yaml")
p = pub.read_text()
p = re.sub(r"version:\s*0\.5\.0\+\d+", "version: 0.5.0+18", p)
p = re.sub(r"version:\s*0\.4\.[^\n]+", "version: 0.5.0+18", p)
pub.write_text(p)
PY

echo
echo "Applied Rakyzu v0.5.0-alpha1 Gradle KTS hotfix."
echo "- CI now supports android/app/build.gradle.kts"
echo "- Native media dependencies are injected into Kotlin DSL Gradle if needed"
echo "- Version bumped to 0.5.0+18"
echo
