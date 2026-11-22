#!/usr/bin/env bash
# Rebuilds the block lists and, if they changed, signs and writes a new feed/ (manifest.json, manifest.sig, shields.dat).
# Runs from .github/workflows/update-lists.yml every day. Needs FEED_PRIVATE_KEY (the PEM text of feed_private.pem).
# Optional: FORCE=1 publishes even when nothing changed. Set FEED_DIR to write somewhere else (for testing).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
FEED="${FEED_DIR:-$ROOT/feed}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
FORMAT="adblock-rust-0.13"          # must equal ENGINE_FORMAT in ListUpdater.kt (and the adblock version pinned in tools/tvshields)
# must equal PUBLIC_KEY_B64 in ListUpdater.kt: a manifest signed by any other key would be refused by every app
EXPECTED_PUB="${EXPECTED_PUBLIC_KEY_B64:-MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEGmHM+O+6nBhb7WCh2FC0XpBf7UBAsVfT2VHi2HRIncAdeQL2/q6rnyO1RiCgVkPB+gS9e22NYrZPo6mNLMQP4w==}"

[ -n "${FEED_PRIVATE_KEY:-}" ] || { echo "FEED_PRIVATE_KEY is not set (add it as a repository secret)"; exit 1; }
printf '%s\n' "$FEED_PRIVATE_KEY" > "$WORK/key.pem"; chmod 600 "$WORK/key.pem"
openssl pkey -in "$WORK/key.pem" -pubout -outform DER 2>/dev/null | base64 -w0 > "$WORK/pub.b64" || { echo "FEED_PRIVATE_KEY is not a valid PEM private key"; exit 1; }
[ "$(cat "$WORK/pub.b64")" = "$EXPECTED_PUB" ] || { echo "The private key does not match the public key built into the app. Nothing published."; exit 1; }
echo "$EXPECTED_PUB" | base64 -d | openssl pkey -pubin -inform DER -out "$WORK/pub.pem"

echo "== 1/5 downloading the lists"
mkdir -p "$WORK/dl" && (cd "$WORK/dl" && bash "$ROOT/tools/fetch_lists.sh")
for f in "$WORK"/dl/lists/*.txt; do [ "$(wc -c < "$f")" -gt 500 ] || { echo "list $(basename "$f") is empty or tiny: stopping"; exit 1; }; done

echo "== 2/5 building shields.dat"
( cd tools/tvshields && cargo build --release --locked --bins 2>&1 | tail -2 )
BIN="$ROOT/tools/tvshields/target/release"
"$BIN/build_shields" "$WORK/dl/lists" "$WORK/shields.dat" network

echo "== 3/5 testing it"
"$BIN/check" "$WORK/shields.dat"

echo "== 4/5 comparing with the published lists"
PREV_VER=1; PREV_SIZE=0; PREV_SHA=""
if [ -f "$FEED/manifest.json" ]; then
  PREV_VER=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" "$FEED/manifest.json")
  PREV_SIZE=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['size'])" "$FEED/manifest.json")
  PREV_SHA=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['sha256'])" "$FEED/manifest.json")
fi
SIZE=$(wc -c < "$WORK/shields.dat"); SHA=$(sha256sum "$WORK/shields.dat" | cut -d' ' -f1)
echo "published: version $PREV_VER, $PREV_SIZE bytes   new: $SIZE bytes"
if [ "$PREV_SIZE" -gt 0 ]; then
  # a half-downloaded or broken source must never replace a good list
  [ $((SIZE * 100)) -ge $((PREV_SIZE * 70)) ] || { echo "New lists are under 70% of the published size: stopping."; exit 1; }
  [ $((SIZE * 100)) -le $((PREV_SIZE * 150)) ] || { echo "New lists are over 150% of the published size: stopping."; exit 1; }
fi

# ---- the rules file (rules/youtube-rules.json): checked, hashed, and covered by the same signature as the lists
RULES_SRC="$ROOT/rules/youtube-rules.json"
RULES_JSON=""; RULES_SHA=""; RULES_VER=0; PREV_RULES_SHA=""; PREV_RULES_VER=0
if [ -f "$FEED/manifest.json" ]; then
  PREV_RULES_SHA=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('rules',{}).get('sha256',''))" "$FEED/manifest.json")
  PREV_RULES_VER=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('rules',{}).get('version',0))" "$FEED/manifest.json")
fi
if [ -f "$RULES_SRC" ]; then
  python3 "$ROOT/tools/check_rules.py" "$RULES_SRC"
  RULES_VER=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" "$RULES_SRC")
  RULES_SHA=$(sha256sum "$RULES_SRC" | cut -d' ' -f1); RULES_SIZE=$(wc -c < "$RULES_SRC")
  if [ "$RULES_SHA" != "$PREV_RULES_SHA" ] && [ "$RULES_VER" -le "$PREV_RULES_VER" ]; then
    echo "rules/youtube-rules.json changed but \"version\" is still $RULES_VER (published: $PREV_RULES_VER). Raise it, or apps ignore the change."; exit 1
  fi
  RULES_JSON=$(printf ',"rules":{"version":%s,"file":"rules.json","sha256":"%s","size":%s}' "$RULES_VER" "$RULES_SHA" "$RULES_SIZE")
fi

LISTS_CHANGED=1; [ "$SHA" = "$PREV_SHA" ] && [ -z "${FORCE:-}" ] && LISTS_CHANGED=""
RULES_CHANGED=""; [ "$RULES_SHA" != "$PREV_RULES_SHA" ] && RULES_CHANGED=1
if [ -z "$LISTS_CHANGED" ] && [ -z "$RULES_CHANGED" ]; then echo "Lists and rules did not change. Nothing to publish."; exit 0; fi

echo "== 5/5 signing and writing the feed"
# the list version only moves when the lists changed, so a rules-only change does not make every app download the lists again
if [ -n "$LISTS_CHANGED" ]; then VER=$((PREV_VER + 1)); else VER=$PREV_VER; fi
DATE=$(date -u +%F)
printf '{"version":%s,"format":"%s","file":"shields.dat","sha256":"%s","size":%s,"date":"%s"%s}' "$VER" "$FORMAT" "$SHA" "$SIZE" "$DATE" "$RULES_JSON" > "$WORK/manifest.json"
openssl dgst -sha256 -sign "$WORK/key.pem" "$WORK/manifest.json" | base64 -w0 > "$WORK/manifest.sig"
base64 -d < "$WORK/manifest.sig" > "$WORK/sig.der"
openssl dgst -sha256 -verify "$WORK/pub.pem" -signature "$WORK/sig.der" "$WORK/manifest.json" >/dev/null || { echo "signature check failed"; exit 1; }
mkdir -p "$FEED"
if [ -n "$LISTS_CHANGED" ]; then cp "$WORK/shields.dat" "$FEED/shields.dat"; fi
[ -f "$RULES_SRC" ] && cp "$RULES_SRC" "$FEED/rules.json"
cp "$WORK/manifest.sig" "$FEED/manifest.sig"; cp "$WORK/manifest.json" "$FEED/manifest.json"
echo "Published lists version $VER, rules version $RULES_VER ($DATE, $SIZE bytes of lists)."
