# Rakyzu v0.4.0-alpha7 Activity Binding Patch

Fixes missing media notification by binding the Android Activity to `AudioServiceActivity`.

## Why

Previous alpha versions added the `AudioService` service and receiver, but still used the default `.MainActivity`. The official `audio_service` Android setup requires the existing Activity to use `com.ryanheise.audioservice.AudioServiceActivity` or a custom activity subclassing it.

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v040-alpha7-activity-binding.zip .
unzip -o rakyzu-v040-alpha7-activity-binding.zip
bash rakyzu-v040-alpha7-activity-binding/apply_alpha7.sh

grep -n "AudioServiceActivity\|version:" .github/workflows/build-apk.yml pubspec.yaml

git add .github/workflows/build-apk.yml pubspec.yaml
git commit -m "Bind Android activity to AudioService"
git push
```
