# Open Saber Plus PS4 01.14 — latest confirmed build

This is the **latest build confirmed on PS4 by the user**: it was reported as
working very well at **50–60 FPS**. Use it as the known-good install until a newer
candidate receives the same real-headset check.

01.19 is newer but is only host-checked: its native splash dismissal still needs
PS4/PSVR confirmation. 01.16/01.17 ran but kept the system splash and were not
accepted.

## Artifact

- `Open-Saber-Plus-01.14.pkg`
- **94,765,056 bytes**
- SHA-256 `8e7966acfd9a676fd5d3ba0c11a3f74da3c8a36574ee81e470c86783fcbd3785`
- Title ID `OSAB00001` (replaces Open Saber Plus, not the `GDOT00001` loader)

Features retained from earlier builds: native PSVR stereo and PS Move, 1920×1080
TV output, Options tap pause/hold recenter, account-isolated settings/scores,
shared songs, bounded chart installation and strict constant-BPM v4 handling.

Host checks passed before the original upload: native compile/link, strict UBSan
backend suite, direct/staged exported-PCK boot, Options/height, profile/pitch
migration, safe archive/queue, repeated v2/v3/v4 tests, package
layout/digests/signatures and real 517ad Ogg/32-load validation. Actual GPU/HMD
colors, tracking alignment and full-song behavior were not automated. The
50–60 FPS confirmation came from real use after upload, not from this host suite.

The source archive contains adaptations, patches and revision metadata. It does
not include a full Godot/Mesa/OpenOrbis checkout; rebuilds require the separately
prepared local toolchain. No official Beat Saber assets or downloaded maps are
included.
