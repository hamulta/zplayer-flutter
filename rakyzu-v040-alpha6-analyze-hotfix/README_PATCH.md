# Rakyzu v0.4.0-alpha6.1 Analyze Hotfix

Fixes Dart analyzer failure after alpha6.

## Problem

`_syncNotificationState()` returns `void`, so this is invalid:

```dart
await _syncNotificationState();
```

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v040-alpha6-analyze-hotfix.zip .
unzip -o rakyzu-v040-alpha6-analyze-hotfix.zip
bash rakyzu-v040-alpha6-analyze-hotfix/apply_hotfix.sh

grep -n "await _syncNotificationState\|_requestStopFromService\|version:" lib/main.dart pubspec.yaml

git add lib/main.dart pubspec.yaml
git commit -m "Fix alpha6 analyzer errors"
git push
```
