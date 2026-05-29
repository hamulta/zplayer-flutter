# Rakyzu Music Player v0.3.0 Patch

Adds:
- Favorites
- Recently played
- Persistent sort/filter/shuffle/repeat settings
- Library mode: All / Favorites / Recent
- Favorite heart buttons in song tiles and mini player
- Queue navigation based on current visible library view
- Version bump to 0.3.0+4

Apply from repo root:

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v030-patch.zip .
unzip -o rakyzu-v030-patch.zip
bash rakyzu-v030/apply_v030.sh
git add .
git commit -m "Add favorites recent history and persistent settings"
git push
```
