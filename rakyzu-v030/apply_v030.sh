#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"

if [ ! -d "$ROOT/lib" ] || [ ! -f "$ROOT/pubspec.yaml" ]; then
  echo "ERROR: Jalankan script ini dari root repo Flutter: ~/zplayer-flutter"
  exit 1
fi

cp rakyzu-v030/files/lib/main.dart lib/main.dart
cp rakyzu-v030/files/pubspec.yaml pubspec.yaml

echo "Applied Rakyzu Music Player v0.3.0 patch."
echo "Updated:"
echo "- lib/main.dart"
echo "- pubspec.yaml"
echo
echo "Next:"
echo "git add ."
echo "git commit -m \"Add favorites recent history and persistent settings\""
echo "git push"
