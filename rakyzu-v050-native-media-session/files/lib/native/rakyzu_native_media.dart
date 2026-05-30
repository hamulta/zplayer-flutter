import 'package:flutter/services.dart';

class RakyzuNativeMedia {
  static const MethodChannel _channel = MethodChannel('rakyzu/native_media');
  static const EventChannel _events = EventChannel('rakyzu/native_media_events');

  static Stream<String> get actions {
    return _events.receiveBroadcastStream().map((event) => event.toString());
  }

  static Future<void> setTrack({
    required String id,
    required String title,
    required String artist,
    required String album,
    required int durationMs,
    required int positionMs,
    required bool playing,
  }) async {
    await _channel.invokeMethod('setTrack', <String, Object?>{
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': durationMs,
      'positionMs': positionMs,
      'playing': playing,
    });
  }

  static Future<void> updatePlayback({
    required bool playing,
    required int positionMs,
    required int durationMs,
  }) async {
    await _channel.invokeMethod('updatePlayback', <String, Object?>{
      'playing': playing,
      'positionMs': positionMs,
      'durationMs': durationMs,
    });
  }

  static Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }
}
