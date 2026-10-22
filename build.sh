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
PATCH_FILE="$ROOT/$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["framework_patch"]["file"])' "$LOCK")"
PATCH_EXPECTED=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["framework_patch"]["sha256"])' "$LOCK")
PATCH_ACTUAL=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$PATCH_FILE")
[ "$PATCH_ACTUAL" = "$PATCH_EXPECTED" ] || { echo "Framework patch SHA-256 mismatch: $PATCH_FILE" >&2; exit 1; }
FRAME_DRIVER="$SNESRECOMP_ROOT/runner/src/generic_frame_driver.c"
if ! grep -q 'interp_bridge_last_interrupt_return_pc' "$FRAME_DRIVER"; then
  git -C "$SNESRECOMP_ROOT" apply --check "$PATCH_FILE"
  git -C "$SNESRECOMP_ROOT" apply "$PATCH_FILE"
fi
grep -q 'interp_bridge_last_interrupt_return_pc' "$FRAME_DRIVER" || { echo 'SNESRecomp IRQ patch is not active' >&2; exit 1; }
echo "SNESRecomp patch $PATCH_ACTUAL verified and active"
RENDERER_PATCH="$ROOT/$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8-sig"))["renderer_patch"]["file"])' "$LOCK")"
RENDERER_PATCH_EXPECTED=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8-sig"))["renderer_patch"]["sha256"])' "$LOCK")
RENDERER_PATCH_ACTUAL=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$RENDERER_PATCH")
[ "$RENDERER_PATCH_ACTUAL" = "$RENDERER_PATCH_EXPECTED" ] || { echo "Renderer patch SHA-256 mismatch: $RENDERER_PATCH" >&2; exit 1; }
PPU_SOURCE="$SNESRECOMP_ROOT/runner/src/snes/ppu.c"
if ! grep -q 'new_renderer_supports_mode' "$PPU_SOURCE"; then
  git -C "$SNESRECOMP_ROOT" apply --check "$RENDERER_PATCH"
  git -C "$SNESRECOMP_ROOT" apply "$RENDERER_PATCH"
fi
grep -q 'new_renderer_supports_mode' "$PPU_SOURCE" || { echo 'SNESRecomp mode 5 renderer fallback is not active' >&2; exit 1; }
echo "SNESRecomp renderer patch $RENDERER_PATCH_ACTUAL verified and active"
cmake -S "$ROOT" -B "$ROOT/build" -G Ninja -DCMAKE_BUILD_TYPE=Release "-DSNESRECOMP_ROOT=$SNESRECOMP_ROOT" "-DRECOMP_UI_ROOT=$RECOMP_UI_ROOT"
cmake --build "$ROOT/build" --config Release --parallel
printf 'Built %s and %s\n' "$ROOT/build/som_recomp" "$ROOT/build/som_headless"

