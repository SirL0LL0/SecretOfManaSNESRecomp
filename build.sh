#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOCK="$ROOT/dependencies.lock.json"
SNESRECOMP_ROOT=${SNESRECOMP_ROOT:-"$ROOT/../snesrecomp"}
RECOMP_UI_ROOT=${RECOMP_UI_ROOT:-"$SNESRECOMP_ROOT/recomp-ui"}
pin_value() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["dependencies"][sys.argv[2]][sys.argv[3]])' "$LOCK" "$1" "$2"
}
check_pin() {
  name=$1 path=$2 expected=$3 url=$4
  actual=$(git -C "$path" rev-parse HEAD); origin=$(git -C "$path" remote get-url origin)
  [ "$actual" = "$expected" ] || { echo "$name revision mismatch: expected $expected, found $actual" >&2; exit 1; }
  [ "$origin" = "$url" ] || { echo "$name origin mismatch: expected $url, found $origin" >&2; exit 1; }
  echo "$name $actual verified"
}
check_pin snesrecomp "$SNESRECOMP_ROOT" "$(pin_value snesrecomp revision)" "$(pin_value snesrecomp repository)"
check_pin recomp-ui "$RECOMP_UI_ROOT" "$(pin_value recomp-ui revision)" "$(pin_value recomp-ui repository)"
# The Secret of Mana framework changes live on the pinned snesrecomp fork
# commit. recomp-ui is upstream plus one patch: the launcher's language
# selector, translation-file picker and Italian strings.
ui_patch_value() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["ui_patch"][sys.argv[2]])' "$LOCK" "$1"
}
PATCH_FILE="$ROOT/$(ui_patch_value file)"
PATCH_EXPECTED=$(ui_patch_value sha256)
PATCH_MARKER=$(ui_patch_value marker)
PATCH_ACTUAL=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$PATCH_FILE")
[ "$PATCH_ACTUAL" = "$PATCH_EXPECTED" ] || { echo "recomp-ui patch SHA-256 mismatch: $PATCH_FILE" >&2; exit 1; }
UI_HEADER="$RECOMP_UI_ROOT/src/recomp_launcher.h"
if ! grep -q "$PATCH_MARKER" "$UI_HEADER"; then
  git -C "$RECOMP_UI_ROOT" apply --check "$PATCH_FILE"
  git -C "$RECOMP_UI_ROOT" apply "$PATCH_FILE"
fi
grep -q "$PATCH_MARKER" "$UI_HEADER" || { echo "Secret of Mana recomp-ui patch is not active" >&2; exit 1; }
echo "recomp-ui patch $PATCH_ACTUAL verified and active"
cmake -S "$ROOT" -B "$ROOT/build" -G Ninja -DCMAKE_BUILD_TYPE=Release "-DSNESRECOMP_ROOT=$SNESRECOMP_ROOT" "-DRECOMP_UI_ROOT=$RECOMP_UI_ROOT"
cmake --build "$ROOT/build" --config Release --parallel
printf 'Built %s and %s\n' "$ROOT/build/som_recomp" "$ROOT/build/som_headless"

