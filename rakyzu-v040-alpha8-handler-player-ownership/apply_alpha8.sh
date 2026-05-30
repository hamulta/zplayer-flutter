#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(pwd)"
MAIN="$ROOT/lib/main.dart"
HANDLER="$ROOT/lib/audio/rakyzu_audio_handler.dart"
PUB="$ROOT/pubspec.yaml"

if [ ! -f "$MAIN" ] || [ ! -f "$HANDLER" ] || [ ! -f "$PUB" ]; then
  echo "ERROR: Jalankan dari root repo Flutter:"
  echo "cd ~/zplayer-flutter"
  echo "bash rakyzu-v040-alpha8-handler-player-ownership/apply_alpha8.sh"
  exit 1
fi

cp "$MAIN" "$MAIN.bak.alpha8"
cp "$HANDLER" "$HANDLER.bak.alpha8"
cp "$PUB" "$PUB.bak.alpha8"

cat > "$HANDLER" <<'DART'
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class RakyzuAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();

  Future<void> Function()? onPlayRequested;
  Future<void> Function()? onPauseRequested;
  Future<void> Function()? onStopRequested;
  Future<void> Function()? onNextRequested;
  Future<void> Function()? onPreviousRequested;
  Future<void> Function(Duration position)? onSeekRequested;

  bool _queueEnabled = false;
  StreamSubscription<PlaybackEvent>? _playbackEventSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  RakyzuAudioHandler() {
    _playbackEventSub = player.playbackEventStream.listen((_) {
      _broadcastState();
    });

    _positionSub = player.positionStream.listen((_) {
      _broadcastState();
    });

    _durationSub = player.durationStream.listen((_) {
      _broadcastState();
    });
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  List<MediaControl> _controls() {
    return <MediaControl>[
      if (_queueEnabled) MediaControl.skipToPrevious,
      player.playing ? MediaControl.pause : MediaControl.play,
      if (_queueEnabled) MediaControl.skipToNext,
      MediaControl.stop,
    ];
  }

  List<int> _compactActionIndices() {
    return _queueEnabled ? const <int>[0, 1, 2] : const <int>[0];
  }

  void _broadcastState() {
    playbackState.add(
      PlaybackState(
        controls: _controls(),
        androidCompactActionIndices: _compactActionIndices(),
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: _mapProcessingState(player.processingState),
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: 0,
      ),
    );
  }

  void updateNowPlaying({
    required String id,
    required String title,
    required String artist,
    required String album,
    Duration? duration,
  }) {
    final item = MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
    );

    mediaItem.add(item);
    queue.add(<MediaItem>[item]);
    _broadcastState();
  }

  void updatePlayback({
    required bool playing,
    required AudioProcessingState processingState,
    required Duration position,
    required Duration bufferedPosition,
    required bool queueEnabled,
  }) {
    _queueEnabled = queueEnabled;

    playbackState.add(
      PlaybackState(
        controls: _controls(),
        androidCompactActionIndices: _compactActionIndices(),
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: processingState,
        playing: playing,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: player.speed,
        queueIndex: queueEnabled ? 0 : null,
      ),
    );
  }

  void clearCallbacks() {
    onPlayRequested = null;
    onPauseRequested = null;
    onStopRequested = null;
    onNextRequested = null;
    onPreviousRequested = null;
    onSeekRequested = null;
  }

  @override
  Future<void> play() async {
    if (onPlayRequested != null) {
      await onPlayRequested!.call();
    } else {
      await player.play();
    }

    _broadcastState();
  }

  @override
  Future<void> pause() async {
    if (onPauseRequested != null) {
      await onPauseRequested!.call();
    } else {
      await player.pause();
    }

    _broadcastState();
  }

  @override
  Future<void> stop() async {
    if (onStopRequested != null) {
      await onStopRequested!.call();
    } else {
      await player.stop();
    }

    _broadcastState();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    await onNextRequested?.call();
    _broadcastState();
  }

  @override
  Future<void> skipToPrevious() async {
    await onPreviousRequested?.call();
    _broadcastState();
  }

  @override
  Future<void> seek(Duration position) async {
    if (onSeekRequested != null) {
      await onSeekRequested!.call(position);
    } else {
      await player.seek(position);
    }

    _broadcastState();
  }

  Future<void> disposeHandler() async {
    clearCallbacks();
    await _playbackEventSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await player.dispose();
  }
}

DART

python3 <<'PY'
from pathlib import Path
import re

main = Path("lib/main.dart")
text = main.read_text()

# Let AudioService handler own the same AudioPlayer instance used by UI.
text = text.replace(
    "  final AudioPlayer _player = AudioPlayer();",
    "  late final AudioPlayer _player;",
    1,
)

if "_player = rakyzuAudioHandler?.player ?? AudioPlayer();" not in text:
    text = text.replace(
        """  void initState() {
    super.initState();
""",
        """  void initState() {
    super.initState();
    _player = rakyzuAudioHandler?.player ?? AudioPlayer();
""",
        1,
    )

# Do not dispose handler-owned player from the UI state.
text = text.replace(
    """    _searchController.dispose();
    _player.dispose();
    super.dispose();
""",
    """    _searchController.dispose();
    if (rakyzuAudioHandler == null) {
      _player.dispose();
    }
    super.dispose();
""",
    1,
)

# If previous dispose manually cleared callbacks, keep it but prefer helper when available.
text = text.replace(
    """      handler.onPlayRequested = null;
      handler.onPauseRequested = null;
      handler.onStopRequested = null;
      handler.onNextRequested = null;
      handler.onPreviousRequested = null;
      handler.onSeekRequested = null;
""",
    """      handler.clearCallbacks();
""",
    1,
)

main.write_text(text)

pub = Path("pubspec.yaml")
p = pub.read_text()
p = re.sub(r"version:\s*0\.4\.0\+\d+", "version: 0.4.0+16", p)
pub.write_text(p)
PY

echo
echo "Applied Rakyzu v0.4.0-alpha8 handler player ownership."
echo "- AudioService handler now owns the AudioPlayer instance"
echo "- UI uses handler.player when AudioService init succeeds"
echo "- MediaItem, queue, PlaybackState are broadcast from handler streams"
echo "- Foreground fallback remains available if AudioService fails"
echo "- Version bumped to 0.4.0+16"
echo
