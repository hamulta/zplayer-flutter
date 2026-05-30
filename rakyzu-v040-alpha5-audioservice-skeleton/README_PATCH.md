# Rakyzu v0.4.0-alpha5 AudioService Skeleton

This patch replaces the failed `just_audio_background` strategy with a safer `audio_service` custom handler.

## Goal

- Keep normal foreground playback stable.
- Initialize media notification service in guarded mode.
- Mirror current track and playback state to the notification.
- Allow notification play/pause/next/previous/seek to call back into the existing player.

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v040-alpha5-audioservice-skeleton.zip .
unzip -o rakyzu-v040-alpha5-audioservice-skeleton.zip
bash rakyzu-v040-alpha5-audioservice-skeleton/apply_alpha5.sh
git add lib/main.dart lib/audio/rakyzu_audio_handler.dart pubspec.yaml .github/workflows/build-apk.yml
git commit -m "Add AudioService notification skeleton"
git push
```
