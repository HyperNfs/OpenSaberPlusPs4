# Open Saber Plus PS4 01.19 beta

**Beta:** newest preserved build, host-checked but **not yet confirmed on PS4/PSVR**.
Do not install over the 01.14 build unless you can restore it; 01.14 is the last
user-accepted 50–60 FPS baseline.

01.19 removes engine/scene splash artwork and loads internal SystemService to
call `sceSystemServiceHideSplashScreen()` once after the first running frame,
matching the SDK sample. A strict host fixture compiles the actual OS loop and
checks ordering, one-shot behavior, early exit and failure logging. It does not
prove the real PS4 syscall succeeds. Startup should be black, then the game;
capture fresh `opensaber-plus.log` and native logs if it remains black.

Features retained from earlier builds: native 1152×1296 PSVR stereo, 1920×1080
TV output, PS Move, account-isolated settings/scores, shared songs, retained
last poses on tracking loss, bounded chart installation and strict v4 parsing.

## Artifact

- `Open-Saber-Plus-01.19.pkg`
- **95,748,096 bytes**
- SHA-256 `86c567837b40e859b4cf711224397bca9744dd05db7587bd498d3b184fab904d`
- Title ID `OSAB00001`: this replaces Open Saber Plus, not the GDOT00001 loader.

Host checks passed: native rebuild, splash-loop UBSan fixture, direct/staged PCK
boot, profile/map guards, real 517ad Ogg/32 loads, package entries/hashes and
signatures. Actual HMD visuals, real FPS, occlusion, full songs, restart/exit and
app behavior on PS4 still need confirmation. The unchanged 01.15 backend baseline
is not relabeled as a new 01.19 subsystem suite.

The archive contains the adapted game and PS4 platform patches/revisions. It does
not contain a full Godot/Mesa/OpenOrbis engine checkout; follow its revision and
patch notes with the separately prepared local toolchain. Licenses and credits
remain with their sources; the game code is MIT and the native platform patches
have separate upstream terms. No official game assets or downloaded maps are
included.
