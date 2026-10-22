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
PPU_SOURCE="$SNESRECOMP_ROOT/runner/src/snes/ppu.c"
HOST_SOURCE="$SNESRECOMP_ROOT/runner/src/desktop/host_main.c"
# The single patch carries every Secret of Mana framework change: the IRQ
# task-switch fix, the Mode 5 renderer fallback, the Mode 5 logical output and
# the intro raster journal. All four markers are checked after it is applied.
missing=0
for marker in "interp_bridge_last_interrupt_return_pc:$FRAME_DRIVER" \
               "new_renderer_supports_mode:$PPU_SOURCE" \
               "g_ppu_render_width:$HOST_SOURCE" \
               "ppu_rasterApplyLine:$FRAME_DRIVER"; do
  pattern=${marker%%:*}; file=${marker#*:}
  grep -q "$pattern" "$file" || missing=1
done
if [ "$missing" -ne 0 ]; then
  git -C "$SNESRECOMP_ROOT" apply --check "$PATCH_FILE"
  git -C "$SNESRECOMP_ROOT" apply "$PATCH_FILE"
fi
for marker in "interp_bridge_last_interrupt_return_pc:$FRAME_DRIVER" \
               "new_renderer_supports_mode:$PPU_SOURCE" \
               "g_ppu_render_width:$HOST_SOURCE" \
               "ppu_rasterApplyLine:$FRAME_DRIVER"; do
  pattern=${marker%%:*}; file=${marker#*:}
  grep -q "$pattern" "$file" || { echo "Secret of Mana framework patch is not active ($pattern)" >&2; exit 1; }
done
echo "SNESRecomp patch $PATCH_ACTUAL verified and active"
cmake -S "$ROOT" -B "$ROOT/build" -G Ninja -DCMAKE_BUILD_TYPE=Release "-DSNESRECOMP_ROOT=$SNESRECOMP_ROOT" "-DRECOMP_UI_ROOT=$RECOMP_UI_ROOT"
cmake --build "$ROOT/build" --config Release --parallel
printf 'Built %s and %s\n' "$ROOT/build/som_recomp" "$ROOT/build/som_headless"

