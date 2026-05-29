import 'package:audio_service/audio_service.dart';

class RakyzuAudioHandler extends BaseAudioHandler with SeekHandler {
  Future<void> Function()? onPlayRequested;
  Future<void> Function()? onPauseRequested;
  Future<void> Function()? onStopRequested;
  Future<void> Function()? onNextRequested;
  Future<void> Function()? onPreviousRequested;
  Future<void> Function(Duration position)? onSeekRequested;

  void updateNowPlaying({
    required String id,
    required String title,
    required String artist,
    required String album,
    Duration? duration,
  }) {
    mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
      ),
    );
  }

  void updatePlayback({
    required bool playing,
    required AudioProcessingState processingState,
    required Duration position,
    required Duration bufferedPosition,
    required bool queueEnabled,
  }) {
    final controls = <MediaControl>[
      if (queueEnabled) MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      if (queueEnabled) MediaControl.skipToNext,
      MediaControl.stop,
    ];

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        androidCompactActionIndices: queueEnabled ? const [0, 1, 2] : const [0],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: processingState,
        playing: playing,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: 1.0,
      ),
    );
  }

  @override
  Future<void> play() async {
    await onPlayRequested?.call();
  }

  @override
  Future<void> pause() async {
    await onPauseRequested?.call();
  }

  @override
  Future<void> stop() async {
    await onStopRequested?.call();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    await onNextRequested?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    await onPreviousRequested?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    await onSeekRequested?.call(position);
  }
}
