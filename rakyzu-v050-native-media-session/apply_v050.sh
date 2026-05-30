#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
MAIN="$ROOT/lib/main.dart"
PUB="$ROOT/pubspec.yaml"
WF="$ROOT/.github/workflows/build-apk.yml"

if [ ! -f "$MAIN" ] || [ ! -f "$PUB" ] || [ ! -f "$WF" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v050-native-media-session/apply_v050.sh"
  exit 1
fi

cp "$MAIN" "$MAIN.bak.v050"
cp "$PUB" "$PUB.bak.v050"
cp "$WF" "$WF.bak.v050"

mkdir -p "$ROOT/lib/native"
cp rakyzu-v050-native-media-session/files/lib/native/rakyzu_native_media.dart "$ROOT/lib/native/rakyzu_native_media.dart"
cp rakyzu-v050-native-media-session/files/.github/workflows/build-apk.yml "$WF"

python3 <<'PY'
from pathlib import Path
import re

main = Path("lib/main.dart")
text = main.read_text()

if "native/rakyzu_native_media.dart" not in text:
    if "import 'audio/rakyzu_audio_handler.dart';" in text:
        text = text.replace(
            "import 'audio/rakyzu_audio_handler.dart';",
            "import 'audio/rakyzu_audio_handler.dart';\nimport 'native/rakyzu_native_media.dart';",
            1,
        )
    else:
        text = text.replace(
            "import 'package:shared_preferences/shared_preferences.dart';",
            "import 'package:shared_preferences/shared_preferences.dart';\n\nimport 'native/rakyzu_native_media.dart';",
            1,
        )

if "_nativeMediaActionSub" not in text:
    text = text.replace(
        "  StreamSubscription<Duration?>? _durationSub;",
        "  StreamSubscription<Duration?>? _durationSub;\n  StreamSubscription<String>? _nativeMediaActionSub;",
        1,
    )

if "RakyzuNativeMedia.actions.listen" not in text:
    marker = "    _registerAudioHandlerCallbacks();\n"
    insert = """    _nativeMediaActionSub = RakyzuNativeMedia.actions.listen((action) {
      if (!mounted) return;

      if (action == 'play') {
        _notificationPlay();
      } else if (action == 'pause') {
        _notificationPause();
      } else if (action == 'stop') {
        _notificationStop();
      } else if (action == 'next') {
        _next();
      } else if (action == 'previous') {
        _previous();
      } else if (action.startsWith('seek:')) {
        final raw = action.substring(5);
        final ms = int.tryParse(raw);
        if (ms != null) {
          _player.seek(Duration(milliseconds: ms));
        }
      }
    });

"""
    if marker not in text:
        raise SystemExit("Cannot find initState callback marker. Patch aborted.")
    text = text.replace(marker, marker + insert, 1)

if "RakyzuNativeMedia.updatePlayback" not in text:
    marker = "  void _syncNotificationState() {\n"
    insert = """  void _syncNotificationState() {
    final nativeSong = _currentSong;
    if (nativeSong != null) {
      final fallbackDuration = nativeSong.duration ?? 0;
      final duration = _player.duration ?? Duration(milliseconds: fallbackDuration);

      unawaited(
        RakyzuNativeMedia.updatePlayback(
          playing: _player.playing,
          positionMs: _player.position.inMilliseconds,
          durationMs: duration.inMilliseconds,
        ),
      );
    }

"""
    if marker not in text:
        raise SystemExit("Cannot find _syncNotificationState marker. Patch aborted.")
    text = text.replace(marker, insert, 1)

if "RakyzuNativeMedia.setTrack" not in text:
    pattern = r"(  void _syncNotificationTrack\(SongModel song\) \{.*?final durationMs = song\.duration \?\? 0;\n)"
    add = r"""\1
    unawaited(
      RakyzuNativeMedia.setTrack(
        id: song.id.toString(),
        title: song.title,
        artist: _smartArtistOrAlbum(song),
        album: _safeAlbum(song),
        durationMs: durationMs,
        positionMs: _player.position.inMilliseconds,
        playing: _player.playing,
      ),
    );

"""
    text, count = re.subn(pattern, add, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit("Cannot patch _syncNotificationTrack. Patch aborted.")

if "RakyzuNativeMedia.stop();" not in text:
    text = text.replace(
        """  Future<void> _notificationStop() async {
    await _player.stop();
    _syncNotificationState();
""",
        """  Future<void> _notificationStop() async {
    await _player.stop();
    unawaited(RakyzuNativeMedia.stop());
    _syncNotificationState();
""",
        1,
    )

if "_nativeMediaActionSub?.cancel();" not in text:
    text = text.replace(
        "    _durationSub?.cancel();",
        "    _durationSub?.cancel();\n    _nativeMediaActionSub?.cancel();",
        1,
    )

main.write_text(text)

pub = Path("pubspec.yaml")
p = pub.read_text()
p = re.sub(r"version:\s*0\.4\.[^\n]+", "version: 0.5.0+17", p)
p = re.sub(r"version:\s*0\.5\.[^\n]+", "version: 0.5.0+17", p)
pub.write_text(p)
PY

echo
echo "Applied Rakyzu v0.5.0 native Android MediaSession patch."
echo "- Adds native Kotlin MediaSessionCompat foreground notification engine"
echo "- Adds MethodChannel/EventChannel bridge"
echo "- Keeps current Flutter playback stable"
echo "- Mirrors track metadata + playback state into native Android media session"
echo "- Version bumped to 0.5.0+17"
echo
