#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"

if [ ! -f "$ROOT/pubspec.yaml" ] || [ ! -d "$ROOT/lib" ] || [ ! -d "$ROOT/.github/workflows" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v040-alpha5-audioservice-skeleton/apply_alpha5.sh"
  exit 1
fi

mkdir -p "$ROOT/lib/audio"
mkdir -p "$ROOT/.github/workflows"

cp rakyzu-v040-alpha5-audioservice-skeleton/files/lib/main.dart "$ROOT/lib/main.dart"
cp rakyzu-v040-alpha5-audioservice-skeleton/files/lib/audio/rakyzu_audio_handler.dart "$ROOT/lib/audio/rakyzu_audio_handler.dart"
cp rakyzu-v040-alpha5-audioservice-skeleton/files/pubspec.yaml "$ROOT/pubspec.yaml"
cp rakyzu-v040-alpha5-audioservice-skeleton/files/.github/workflows/build-apk.yml "$ROOT/.github/workflows/build-apk.yml"

echo
echo "Applied Rakyzu v0.4.0-alpha5 AudioService skeleton."
echo "- Adds audio_service custom handler"
echo "- Keeps foreground playback as source of truth"
echo "- Mirrors metadata/playback state to Android media notification"
echo "- Adds guarded service init fallback"
echo "- Version bumped to 0.4.0+10"
echo
