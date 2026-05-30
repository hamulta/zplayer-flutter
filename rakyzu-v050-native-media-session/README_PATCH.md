# Rakyzu v0.5.0 Native Android MediaSession Patch

This patch takes a native Android route for media notification surfaces:

- Native Kotlin `MediaSessionCompat`
- Native foreground service with `mediaPlayback`
- Native media-style notification
- MethodChannel/EventChannel bridge
- Flutter playback remains stable and mirrors metadata/state into native Android system surfaces

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v050-native-media-session.zip .
unzip -o rakyzu-v050-native-media-session.zip
bash rakyzu-v050-native-media-session/apply_v050.sh

grep -n "RakyzuNativeMedia\|version:" lib/main.dart pubspec.yaml
grep -n "RakyzuMediaService\|MainActivity\|androidx.media" .github/workflows/build-apk.yml

git add lib/main.dart lib/native/rakyzu_native_media.dart pubspec.yaml .github/workflows/build-apk.yml
git commit -m "Add native Android media session notification engine"
git push
```

## Test

1. Install APK.
2. Open Rakyzu Music Player.
3. Play a song.
4. Pull notification shade.
5. Check lock screen / Android dynamic media bar.
6. Test notification play/pause/next/previous.
