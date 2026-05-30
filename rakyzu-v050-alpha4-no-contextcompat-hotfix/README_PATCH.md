# Rakyzu v0.5.0-alpha4 No-ContextCompat Hotfix

Fixes repeated Kotlin compile error:

```txt
Unresolved reference 'ContextCompat'
```

This hotfix removes `ContextCompat` completely instead of trying to repair the import.

Native service starter becomes:

```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    context.startForegroundService(intent)
} else {
    context.startService(intent)
}
```

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v050-alpha4-no-contextcompat-hotfix.zip .
unzip -o rakyzu-v050-alpha4-no-contextcompat-hotfix.zip
bash rakyzu-v050-alpha4-no-contextcompat-hotfix/apply_hotfix.sh

grep -n "Patch native foreground service starter\|version:" .github/workflows/build-apk.yml pubspec.yaml
grep -n "ContextCompat" .github/workflows/build-apk.yml

git add .github/workflows/build-apk.yml pubspec.yaml
git commit -m "Remove ContextCompat from native media service"
git push
```
