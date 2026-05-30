# Rakyzu v0.4.0-alpha6 Service Command Patch

This patch keeps foreground playback stable, but routes UI play/pause commands through the AudioService handler so Android has a stronger reason to start/show the media notification.

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v040-alpha6-service-command.zip .
unzip -o rakyzu-v040-alpha6-service-command.zip
bash rakyzu-v040-alpha6-service-command/apply_alpha6.sh

grep -n "_requestPlayFromService\|version:" lib/main.dart pubspec.yaml

git add lib/main.dart pubspec.yaml
git commit -m "Route playback commands through AudioService"
git push
```
