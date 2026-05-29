#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"

if [ ! -f "$ROOT/pubspec.yaml" ] || [ ! -d "$ROOT/lib" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v040-alpha/apply_v040_alpha.sh"
  exit 1
fi

mkdir -p "$ROOT/lib"
mkdir -p "$ROOT/.github/workflows"

cp rakyzu-v040-alpha/files/lib/main.dart "$ROOT/lib/main.dart"
cp rakyzu-v040-alpha/files/pubspec.yaml "$ROOT/pubspec.yaml"
cp rakyzu-v040-alpha/files/.github/workflows/build-apk.yml "$ROOT/.github/workflows/build-apk.yml"

echo
echo "Applied Rakyzu Music Player v0.4.0-alpha patch."
echo "Changes:"
echo "- Added just_audio_background dependency"
echo "- Initialized background audio service"
echo "- Added MediaItem tags for notification/lockscreen metadata"
echo "- Patched GitHub workflow to add Android background service manifest entries"
echo "- Build workflow now runs on main and feature/background-playback"
echo "- Version bumped to 0.4.0+6"
echo
