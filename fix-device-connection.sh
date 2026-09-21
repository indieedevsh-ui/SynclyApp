#!/bin/zsh
# Naprawa połączenia Xcode 27 ↔ iPhone (CoreDevice / DDI)
set -euo pipefail

XCODE27="/Users/michael/Downloads/Xcode.app/Contents/Developer"

echo "==> Ustawiam xcode-select na Xcode 27 (Downloads)…"
sudo xcode-select -s "$XCODE27"
xcode-select -p

echo "==> Aktualizuję Developer Disk Images…"
sudo DEVELOPER_DIR="$XCODE27" xcrun devicectl manage ddis update --clean

echo "==> Restart usług urządzenia…"
killall -9 remoted 2>/dev/null || true
killall -9 Xcode 2>/dev/null || true
sleep 2

echo "==> Status urządzeń:"
DEVELOPER_DIR="$XCODE27" xcrun devicectl list devices

echo ""
echo "Dalej ręcznie:"
echo "1. Odłącz i podepnij iPhone (odblokowany)."
echo "2. Potwierdź Trust / Tryb dewelopera."
echo "3. Otwórz Xcode z Downloads (nie /Applications)."
echo "4. Scheme = BeSorted, Run na iPhonie."
