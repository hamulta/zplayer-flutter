# Rakyzu v0.4.0-alpha7.1 Label Hotfix

Fixes launcher/app display name reverting to `zplayer_offline`.

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v040-alpha7_1-label-hotfix.zip .
unzip -o rakyzu-v040-alpha7_1-label-hotfix.zip
bash rakyzu-v040-alpha7_1-label-hotfix/apply_hotfix.sh

grep -n "Force Android app display name\|Rakyzu Music Player\|version:" .github/workflows/build-apk.yml pubspec.yaml

git add .github/workflows/build-apk.yml pubspec.yaml
git commit -m "Restore Android display name"
git push
```
