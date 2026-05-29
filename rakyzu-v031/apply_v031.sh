#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"

if [ ! -f "$ROOT/pubspec.yaml" ] || [ ! -d "$ROOT/lib" ]; then
  echo "ERROR: Jalankan script ini dari root repo Flutter, contoh:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v031/apply_v031.sh"
  exit 1
fi

mkdir -p "$ROOT/lib"

cp rakyzu-v031/files/lib/main.dart "$ROOT/lib/main.dart"
cp rakyzu-v031/files/pubspec.yaml "$ROOT/pubspec.yaml"

echo
echo "Applied Rakyzu Music Player v0.3.1 patch."
echo "Changes:"
echo "- Safe-area Library Control bottom sheet"
echo "- Scroll-constrained modal"
echo "- Clear favorite and clear history actions"
echo "- Header title sizing polish"
echo "- Version bumped to 0.3.1+5"
echo
