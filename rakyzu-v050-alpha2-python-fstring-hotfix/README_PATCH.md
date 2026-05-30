# Rakyzu v0.5.0-alpha2 Python f-string Hotfix

Fixes CI error:

```txt
SyntaxError: unexpected character after line continuation character
```

Cause:

```python
text = text.replace("android {", f"android {\n    namespace '{namespace}'", 1)
```

In Python f-strings, literal `{` must be escaped or avoided.

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v050-alpha2-python-fstring-hotfix.zip .
unzip -o rakyzu-v050-alpha2-python-fstring-hotfix.zip
bash rakyzu-v050-alpha2-python-fstring-hotfix/apply_hotfix.sh

grep -n "namespace.*namespace\|version:" .github/workflows/build-apk.yml pubspec.yaml

git add .github/workflows/build-apk.yml pubspec.yaml
git commit -m "Fix workflow Python namespace f-string"
git push
```
