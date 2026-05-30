# Rakyzu v0.5.0-alpha3 ContextCompat Hotfix

Fixes Kotlin compile error:

```txt
Unresolved reference 'ContextCompat'
```

Cause:

```kotlin
import androidx.core.app.ContextCompat
```

Correct import:

```kotlin
import androidx.core.content.ContextCompat
```

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v050-alpha3-contextcompat-hotfix.zip .
unzip -o rakyzu-v050-alpha3-contextcompat-hotfix.zip
bash rakyzu-v050-alpha3-contextcompat-hotfix/apply_hotfix.sh

grep -n "Fix native ContextCompat import\|version:" .github/workflows/build-apk.yml pubspec.yaml

git add .github/workflows/build-apk.yml pubspec.yaml
git commit -m "Fix native ContextCompat import"
git push
```
