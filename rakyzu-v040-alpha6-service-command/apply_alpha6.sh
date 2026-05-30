#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
MAIN="$ROOT/lib/main.dart"
PUB="$ROOT/pubspec.yaml"

if [ ! -f "$MAIN" ] || [ ! -f "$PUB" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v040-alpha6-service-command/apply_alpha6.sh"
  exit 1
fi

cp "$MAIN" "$MAIN.bak.alpha6"
cp "$PUB" "$PUB.bak.alpha6"

python3 <<'PY'
from pathlib import Path
import re

main = Path("lib/main.dart")
text = main.read_text()

marker = """  Future<void> _notificationStop() async {
    await _player.stop();
    _syncNotificationState();

    if (mounted) setState(() {});
  }

"""

helpers = """  Future<void> _requestPlayFromService() async {
    final handler = rakyzuAudioHandler;

    if (handler != null) {
      await handler.play();
    } else {
      await _player.play();
      _syncNotificationState();
    }
  }

  Future<void> _requestPauseFromService() async {
    final handler = rakyzuAudioHandler;

    if (handler != null) {
      await handler.pause();
    } else {
      await _player.pause();
      _syncNotificationState();
    }
  }

  Future<void> _requestStopFromService() async {
    final handler = rakyzuAudioHandler;

    if (handler != null) {
      await handler.stop();
    } else {
      await _player.stop();
      _syncNotificationState();
    }
  }

"""

if "_requestPlayFromService" not in text:
    if marker not in text:
        raise SystemExit("Cannot find _notificationStop marker. Patch aborted.")
    text = text.replace(marker, marker + helpers, 1)

text = text.replace(
"""      await _player.play();
      _syncNotificationState();

      await _rememberRecent(song.id);
""",
"""      await _syncNotificationState();

      await _requestPlayFromService();

      await _rememberRecent(song.id);
""",
1
)

pattern = r"""  Future<void> _togglePlayPause\(\) async \{.*?\n  \}\n\n  Future<void> _handleCompleted"""
replacement = """  Future<void> _togglePlayPause() async {
    if (_songs.isEmpty) return;

    if (_currentIndex < 0) {
      final source = _visibleSongs.isNotEmpty ? _visibleSongs : _songs;
      await _playSong(source.first);
      return;
    }

    if (_player.playing) {
      await _requestPauseFromService();
    } else {
      await _requestPlayFromService();
    }

    if (mounted) setState(() {});
  }

  Future<void> _handleCompleted"""
text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
if count != 1:
    raise SystemExit("Cannot patch _togglePlayPause. Patch aborted.")

main.write_text(text)

pub = Path("pubspec.yaml")
p = pub.read_text()
p = re.sub(r"version:\s*0\.4\.0\+\d+", "version: 0.4.0+12", p)
pub.write_text(p)
PY

echo
echo "Applied Rakyzu v0.4.0-alpha6 service command patch."
echo "- UI play/pause now routes through AudioService handler"
echo "- Foreground player still remains source of truth"
echo "- This should trigger media notification service more reliably"
echo "- Version bumped to 0.4.0+12"
echo
