# Open Saber Plus PS4 status

This fork contains the PS4-adapted game source for
[`arpruss/OpenSaberPlus`](https://github.com/arpruss/OpenSaberPlus), branch
`godot-4-port`, revision `8c5295cdaadf02ea7418b0c6cbea20240ba913af`
(upstream 0.7.67). The working native VR engine remains Godot 4.3; this is a game
adaptation, not a Godot 4.6 engine port.

## Builds

| Build | Status |
|---|---|
| [**01.19 beta**](https://github.com/HyperNfs/OpenSaberPlusPs4/releases/tag/opensaber-plus-ps4-v01.19) | Newest preserved build. Adds native PS4 system-splash dismissal and removes engine/scene splash artwork. Host-tested against stubs; **real PS4 and PSVR confirmation is still pending.** |
| [**01.14 confirmed**](https://github.com/HyperNfs/OpenSaberPlusPs4/releases/tag/opensaber-plus-ps4-v01.14) | **Latest build confirmed on PS4 by the user**: “works very well at 50–60 FPS.” Use this as the known-good build until 01.19 passes a real HMD check. |
| 01.16 / 01.17 | Ran and reached VR, but retained the system splash and were not accepted. |

The 01.19 host checks cover call order, one-shot behavior and failure logging for
splash dismissal against stubs. They do **not** prove the real PS4 syscall or usable
headset output. If the game stays black, capture fresh `opensaber-plus.log` and
native logs instead of assuming the fix worked.

### 01.19 package

- `Open-Saber-Plus-01.19.pkg`
- Size: **95,748,096 bytes**
- SHA-256: `86c567837b40e859b4cf711224397bca9744dd05db7587bd498d3b184fab904d`

### 01.14 package

- `Open-Saber-Plus-01.14.pkg`
- Size: **94,765,056 bytes**
- SHA-256: `8e7966acfd9a676fd5d3ba0c11a3f74da3c8a36574ee81e470c86783fcbd3785`
- Title ID `OSAB00001` replaces Open Saber Plus, not the GDOT00001 loader.

01.14’s confirmation concerned performance and normal gameplay. Its splash/VR
visual state was not separately documented in the preserved evidence, so do not
claim that 01.14 is splash-free. See the
[01.14 release notes](https://github.com/HyperNfs/OpenSaberPlusPs4/releases/tag/opensaber-plus-ps4-v01.14)
for the exact original artifacts.

## What works in preserved builds

- Native PSVR stereo and PS Move input, with 1920×1080 TV output.
- PS4 account-isolated settings/scores, shared songs, pause/recenter controls,
  bounded map installation and strict constant-BPM v4 chart handling.
- 01.15 increased per-eye resolution to 1152×1296; actual hardware FPS was not
  measured. 01.14 is the last user-confirmed performance baseline.
- 01.19 host checks: native rebuild, actual OS-loop fixture, exported-PCK
  direct/staged boot, profile/map guards, 517ad Ogg/32-load validation and
  package hashes/signatures. Host checks are not console acceptance.

## Known limits

- Real headset/TV output, splash dismissal, colors, tracking alignment, full-song
  playback, restart/exit and actual FPS require PS4/HMD testing for 01.19.
- Variable timing, rotation/NJS changes and mod charts remain unsupported.
- Native Move rumble is not implemented.
- A downloaded public map is excluded from source and packages; supply your own
  ZIP to repeat the fixture.
- The packager requires a separately prepared Godot 4.3 PS4 engine tree. The
  archive contains patches/revisions but cannot reconstruct it automatically.

See `README.md`, `PROGRESS_SUMMARY.md`, `game/README.md` and `port/README.md` for
the full history and local build instructions.
