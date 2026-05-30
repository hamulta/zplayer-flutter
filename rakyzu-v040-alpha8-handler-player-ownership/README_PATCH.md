# Rakyzu v0.4.0-alpha8 Handler Player Ownership

This patch changes the AudioService integration from a passive mirror to shared player ownership.

## Why

Android media controls, lock screen controls, and dynamic media surfaces require an active media session with playback state and media metadata. Previous alpha builds only mirrored UI player state into the handler. This patch makes the handler own the `AudioPlayer` instance and lets the UI use that same instance.

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v040-alpha8-handler-player-ownership.zip .
unzip -o rakyzu-v040-alpha8-handler-player-ownership.zip
bash rakyzu-v040-alpha8-handler-player-ownership/apply_alpha8.sh

grep -n "late final AudioPlayer _player\|handler.player\|version:" lib/main.dart pubspec.yaml
grep -n "final AudioPlayer player\|queue.add\|PlaybackState" lib/audio/rakyzu_audio_handler.dart

git add lib/main.dart lib/audio/rakyzu_audio_handler.dart pubspec.yaml
git commit -m "Move playback ownership into AudioService handler"
git push
```
