# Validates every .plist / .entitlements in the repo (CI, no Mac needed).
import glob
import plistlib
import sys

bad = []
files = glob.glob("**/*.plist", recursive=True) + glob.glob("Entitlements/*.entitlements")
for f in files:
    try:
        with open(f, "rb") as fh:
            plistlib.load(fh)
    except Exception as e:  # noqa: BLE001
        bad.append((f, e))

for f, e in bad:
    print("INVALID:", f, "-", e, file=sys.stderr)
print(f"checked {len(files)} property lists, {len(bad)} invalid")
sys.exit(1 if bad else 0)
