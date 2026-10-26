#!/bin/bash
# Runs the headless logic checks (game/tools/*_check, *_test) in parallel and exits non-zero if any fails.
#   bash tools/run_checks.sh                 all checks (before a merge / an export)
#   bash tools/run_checks.sh <group|name>    a group or every check whose name contains the word
# Groups (run the one that matches what changed; the full set only before merging or exporting):
#   hero      role_check feel_check            the three heroes' moves, numbers, game feel
#   monster   ai_trace loot_check              monster AI / attacks / loot (ai_trace takes MONSTERS="45,58" to limit it)
#   ui        bag_check forge_check pad_check  menus, backpack, forge, gamepad
#   stage     camera_check walk_check stage_test…  stage scenes, camera, mechanisms
#   fabao     fabao_check
# Every run uses --fixed-fps 60: game time advances 1/60 s per frame and the engine does not wait for real time, so a
# check runs as fast as the machine can go (several times faster than real time) and frame-exactly. JOBS (default 6)
# checks run at once. A check fails on a line starting with FAIL, a script/parse error, or a timeout.
GODOT="${GODOT:-/c/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe}"
JOBS="${JOBS:-6}"
cd "$(dirname "$0")/../game" || exit 2
ALL=("ai_trace -- --check" "walk_check" "pad_check" "forge_check" "bag_check" "fabao_check" "loot_check" "smoke_test"
  "camera_check" "role_check" "feel_check" "stage_test -- hub" "stage_test -- door12" "stage_test -- door12_tangseng"
  "stage_test -- pearls" "stage_test -- pearls_tangseng")
case "$1" in
  hero) SEL=("role_check" "feel_check") ;;
  monster) SEL=("ai_trace -- --check${MONSTERS:+ --ids=$MONSTERS}" "loot_check") ;;
  ui) SEL=("bag_check" "forge_check" "pad_check") ;;
  stage) SEL=("camera_check" "walk_check" "stage_test -- hub" "stage_test -- door12" "stage_test -- door12_tangseng" "stage_test -- pearls" "stage_test -- pearls_tangseng") ;;
  "") SEL=("${ALL[@]}") ;;
  *) SEL=(); for c in "${ALL[@]}"; do [[ "$c" == *"$1"* ]] && SEL+=("$c"); done ;;
esac
tmp=$(mktemp -d)
run() {   # $1 = check, $2 = result file
  local scene="${1%% *}" rest="${1#"$scene"}" out code
  local t0=$SECONDS
  out=$(timeout 400 "$GODOT" --headless --path . --fixed-fps 60 "res://tools/$scene.tscn" $rest 2>&1)
  code=$?
  if [ $code -ne 0 ] && [ $code -ne 1 ] || echo "$out" | grep -qE "^FAIL|SCRIPT ERROR|Parse Error"; then
    # the randomised fabao check gets one retry
    if [[ "$scene" == fabao_check ]] && [ -z "$3" ]; then run "$1" "$2" retry; return; fi
    { echo "FAIL  $1  ($((SECONDS - t0))s)"; echo "$out" | grep -E "^FAIL|SCRIPT ERROR|Parse Error" | head -5 | sed 's/^/      /'; } > "$2"
  else
    echo "PASS  $1  ($((SECONDS - t0))s)" > "$2"
  fi
}
i=0
for c in "${SEL[@]}"; do
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 0.5; done
  run "$c" "$tmp/$i" &
  i=$((i + 1))
done
wait
failed=0
for f in "$tmp"/*; do cat "$f"; grep -q '^FAIL' "$f" && failed=1; done
rm -rf "$tmp"
exit $failed
