# Rakyzu Music Player v0.3.1 Patch

UX Stability Patch.

## Changes
- Library Control bottom sheet now respects device navigation safe-area.
- Modal height is constrained and scrollable for smaller screens.
- Added Clear favorit and Clear riwayat actions.
- Header typography polished to reduce title clipping.
- Version bumped to 0.3.1+5.

## Apply

```bash
cd ~/zplayer-flutter
cp ~/storage/downloads/rakyzu-v031-patch.zip .
unzip -o rakyzu-v031-patch.zip
bash rakyzu-v031/apply_v031.sh
git add .
git commit -m "Stabilize library control UX"
git push
```
