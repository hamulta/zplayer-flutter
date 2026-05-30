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

