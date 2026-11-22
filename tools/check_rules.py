#!/usr/bin/env python3
"""Checks rules/youtube-rules.json before it is signed. Exits with an error text if anything is wrong.
The same limits are enforced again by the app (Rules.kt), so a file that passes here is also accepted there."""
import json, re, sys

def fail(msg):
    print("rules check failed: " + msg); sys.exit(1)

path = sys.argv[1] if len(sys.argv) > 1 else "rules/youtube-rules.json"
try:
    raw = open(path, "rb").read()
    d = json.loads(raw)
except Exception as e:
    fail("not valid JSON (%s)" % e)
if len(raw) > 32 * 1024: fail("file is over 32 KB")
if d.get("schema") != 1: fail('"schema" must be 1')
v = d.get("version")
if not isinstance(v, int) or v < 1: fail('"version" must be a whole number, 1 or more')
yt = d.get("youtube", {})
host_re = re.compile(r"^[a-z0-9]([a-z0-9.-]{0,60}[a-z0-9])?$")
key_re = re.compile(r"^[A-Za-z0-9_]{1,40}$")
def strlist(name, lst, rx, mx):
    if not isinstance(lst, list) or len(lst) > mx: fail("%s must be a list of at most %d entries" % (name, mx))
    for s in lst:
        if not isinstance(s, str) or not rx.match(s): fail("%s: bad entry %r" % (name, s))
ml = yt.get("max_level", 2)
if not isinstance(ml, int) or isinstance(ml, bool) or not 0 <= ml <= 2: fail("youtube.max_level must be 0, 1 or 2")
strlist("youtube.ad_keys", yt.get("ad_keys", []), key_re, 30)
if not yt.get("ad_keys"): fail("youtube.ad_keys must not be empty")
strlist("youtube.never_cancel_hosts", yt.get("never_cancel_hosts", []), host_re, 40)
nc = yt.get("never_cancel", [])
if not isinstance(nc, list) or len(nc) > 60: fail("youtube.never_cancel must be a list of at most 60 entries")
for e in nc:
    if not isinstance(e, dict) or not host_re.match(str(e.get("host", ""))): fail("never_cancel: bad host in %r" % (e,))
    p = e.get("path_contains", "")
    if not isinstance(p, str) or len(p) > 80: fail("never_cancel: bad path_contains in %r" % (e,))
po = d.get("popups", {})
sn, sw = po.get("strikes_needed", 3), po.get("strike_window_min", 60)
if not isinstance(sn, int) or not 2 <= sn <= 10: fail("popups.strikes_needed must be 2 to 10")
if not isinstance(sw, int) or not 10 <= sw <= 1440: fail("popups.strike_window_min must be 10 to 1440")
print("rules ok: version %d" % v)
