#!/usr/bin/env bash
# Downloads the current filter lists into ./lists (all from GitHub).
set -euo pipefail
mkdir -p lists; cd lists
EL=https://raw.githubusercontent.com/easylist/easylist/master
UA=https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters
get() { curl -fsSL --retry 3 -o "$1" "$2" && echo "ok  $1 ($(wc -c < "$1") bytes)"; }
get easylist_general_block.txt      $EL/easylist/easylist_general_block.txt
get easylist_specific_block.txt     $EL/easylist/easylist_specific_block.txt
get easylist_thirdparty.txt         $EL/easylist/easylist_thirdparty.txt
get easylist_adservers.txt          $EL/easylist/easylist_adservers.txt
get easylist_adservers_popup.txt    $EL/easylist/easylist_adservers_popup.txt
get easylist_allowlist.txt          $EL/easylist/easylist_allowlist.txt
get easylist_allowlist_popup.txt    $EL/easylist/easylist_allowlist_popup.txt
get easyprivacy_trackingservers.txt $EL/easyprivacy/easyprivacy_trackingservers.txt
for n in filters filters-2023 filters-2024 filters-2025 quick-fixes badware resource-abuse annoyances-others unbreak privacy; do get $n.txt $UA/$n.txt; done
echo "done: $(ls | wc -l) lists in ./lists"
