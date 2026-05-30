# Rakyzu v0.5.0-alpha1 Gradle KTS Hotfix

Fixes CI failure:

```txt
FileNotFoundError: android/app/build.gradle
```

Flutter newer templates can generate `android/app/build.gradle.kts` instead of `android/app/build.gradle`.

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v050-alpha1-gradle-kts-hotfix.zip .
unzip -o rakyzu-v050-alpha1-gradle-kts-hotfix.zip
bash rakyzu-v050-alpha1-gradle-kts-hotfix/apply_hotfix.sh

grep -n "build.gradle.kts\|Patched Kotlin Gradle\|version:" .github/workflows/build-apk.yml pubspec.yaml

git add .github/workflows/build-apk.yml pubspec.yaml
git commit -m "Support Gradle Kotlin DSL in native media workflow"
git push
```
