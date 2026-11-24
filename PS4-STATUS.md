# Open Saber Plus PS4 status

This fork contains the PS4-adapted game source for
[`arpruss/OpenSaberPlus`](https://github.com/arpruss/OpenSaberPlus), branch
`godot-4-port`, revision `8c5295cdaadf02ea7418b0c6cbea20240ba913af`
(upstream 0.7.67). The working native VR engine remains Godot 4.3; this is a game
adaptation, not a Godot 4.6 engine port.

## Current build

[**01.19 beta**](https://github.com/HyperNfs/OpenSaberPlusPs4/releases/tag/opensaber-plus-ps4-v01.19)
is the newest preserved build. It adds native PS4 system-splash dismissal after
the first running frame and removes engine/scene splash artwork. Host tests check
the call order, one-shot behavior and failure logging against stubs; **real PS4
and PSVR confirmation is still pending**. If it stays black, capture fresh
`opensaber-plus.log` and native logs rather than assuming the fix worked.

- Package: `Open-Saber-Plus-01.19.pkg`
- Size: **95,748,096 bytes**
- SHA-256: `86c567837b40e859b4cf711224397bca9744dd05db7587bd498d3b184fab904d`
- Previous user-accepted rollback: **01.14** (reported 50–60 FPS).

The release includes the unchanged package, checksums, notes, host test logs and
a source archive with the PS4 platform patches. The full engine base source is
not included because of its size; revision/patch metadata and reconstruction
instructions are included. See the release notes before installing. This is a
homebrew PS4 title with PSVR1/PS Move support—not an official Sony or Beat Saber
product, and no official game assets are redistributed.

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
