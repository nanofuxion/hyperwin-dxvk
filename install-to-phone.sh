#!/bin/bash
# Installs a built HyperWin DXVK zip into dev.hyperwin.app/files/dxvk/ on a connected phone.
set -euo pipefail
ZIP=${1:?usage: ./install-to-phone.sh <path/to/dxvk.zip>}
[ -f "$ZIP" ] || { echo "Not found: $ZIP" >&2; exit 1; }
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
unzip -q "$ZIP" -d "$TMP_DIR"
NAME=$(python3 -c 'import json,sys,re; m=json.load(open(sys.argv[1])); s=re.sub(r"[^a-z0-9.]+","-",m.get("name","dxvk").lower()).strip("-"); print(s or "dxvk")' "$TMP_DIR/meta.json")
echo "Installing '$NAME' to dev.hyperwin.app/files/dxvk/$NAME ..."
adb shell "run-as dev.hyperwin.app mkdir -p files/dxvk/$NAME"
for f in "$TMP_DIR"/*; do
  base=$(basename "$f")
  adb shell "run-as dev.hyperwin.app sh -c 'cat > files/dxvk/$NAME/$base'" < "$f"
done
echo "Installed files:"
adb shell "run-as dev.hyperwin.app ls -lh files/dxvk/$NAME/"
