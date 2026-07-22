#!/usr/bin/env bash
# build a jailbreak-installable IPA with the conventional Payload layout
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
STAGE="$ROOT/.ipa-stage"
OUT="$ROOT/TuneTube-1.0.1-stable.ipa"

bash "$ROOT/build_fat.sh"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload/TuneTube.app"
cp "$ROOT/build/TuneTube.app/TuneTube" "$STAGE/Payload/TuneTube.app/"
cp "$ROOT/build/TuneTube.app/Info.plist" "$STAGE/Payload/TuneTube.app/"
cp "$ROOT/build/TuneTube.app/"Icon*.png "$STAGE/Payload/TuneTube.app/"
cp "$ROOT/build/TuneTube.app/"Default*.png "$STAGE/Payload/TuneTube.app/"
cp "$ROOT/build/TuneTube.app/icon-settings.png" "$STAGE/Payload/TuneTube.app/"
cp "$ROOT/build/TuneTube.app/sqmrak.jpg" "$STAGE/Payload/TuneTube.app/"
cp "$ROOT/build/TuneTube.app/"player-*.png "$STAGE/Payload/TuneTube.app/"
chmod 755 "$STAGE/Payload/TuneTube.app/TuneTube"
chmod 644 "$STAGE/Payload/TuneTube.app/Info.plist"
chmod 644 "$STAGE/Payload/TuneTube.app/"Icon*.png
chmod 644 "$STAGE/Payload/TuneTube.app/"Default*.png
chmod 644 "$STAGE/Payload/TuneTube.app/icon-settings.png"
chmod 644 "$STAGE/Payload/TuneTube.app/sqmrak.jpg"
chmod 644 "$STAGE/Payload/TuneTube.app/"player-*.png
rm -f "$OUT"

(cd "$STAGE" && zip -qry "$OUT" Payload)
rm -rf "$STAGE"

unzip -l "$OUT"
echo "built $OUT"
