# Rakyzu Music Player v0.4.0-alpha Patch

Background Playback Alpha.

## Adds
- `just_audio_background`
- Android audio service manifest patch
- Notification/lockscreen metadata via `MediaItem`
- Background playback foundation

## Scope
This is alpha:
- Goal 1: audio keeps playing when app is minimized / screen off.
- Goal 2: Android media notification appears.
- Goal 3: lockscreen media metadata appears where supported.

Next/previous notification behavior will be strengthened in beta with a real playlist queue.

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v040-alpha-patch.zip .
unzip -o rakyzu-v040-alpha-patch.zip
bash rakyzu-v040-alpha/apply_v040_alpha.sh
git add .
git commit -m "Add background playback alpha"
git push -u origin feature/background-playback
```
