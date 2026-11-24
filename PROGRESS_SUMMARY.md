# Open Saber Plus PS4 progress summary

## Latest confirmed: 01.14

User confirmed **01.14 works very well at 50–60 FPS**. Use it as the known-good
build. Its preserved evidence establishes real console performance, but does not
separately document a splash-free visual state.

- Package: `builds/01.14/Open-Saber-Plus-01.14.pkg`
- SHA-256: `8e7966acfd9a676fd5d3ba0c11a3f74da3c8a36574ee81e470c86783fcbd3785`

01.14 introduced the GPU stereo atlas, one fenced CPU readback, corrected score
event ordering, a 4 Hz song clock, MSDF UI fonts and the native
PSVR/Move/Options/height/profile/download/v4 paths. It was uploaded and
fully read-back verified; no console work was done by the uploader.

## 01.19 — newest candidate, confirmation pending

User m05717: 01.17 enters VR but still shows the splash after loading/warm-up.
01.19 removes engine splash image/show flag and duplicated game artwork, and
loads internal SystemService to call `sceSystemServiceHideSplashScreen()` once
after the first running frame. Root icon/splash PNG remain intact but the root
splash is unused.

- Package: `builds/01.19/Open-Saber-Plus-01.19.pkg`
- SHA-256: `86c567837b40e859b4cf711224397bca9744dd05db7587bd498d3b184fab904d`
- Host checks: native rebuild, actual OS-loop fixture, exported-PCK direct/staged
  boot, profile/map guards, 517ad Ogg/32 loads and package hashes/signatures.
- Real PS4/HMD confirmation of splash dismissal and usable VR is still required.

## 01.16 / 01.17 — ran but not accepted

01.16 ran with FPS/menu/native VR activity but retained the system splash and did
not show usable VR. 01.17 changed the splash handoff and boot sequence; the user
reported the splash still appeared in VR. Neither is a confirmed-good replacement
for 01.14.

## 01.15 — resolution change, unmeasured FPS

01.15 raised per-eye PSVR resolution to 1152×1296 and increased stereo texture
provisioning. Host fixtures passed, but real headset sharpness and FPS were not
measured. The 01.14 FPS baseline remains the user-confirmed reference.

## Earlier builds

01.13 was the first OpenSaberPlus PS4 candidate and carried the Plus scoring,
profile migration, safe downloader and strict constant-BPM v4 conversion work
forward from the original OpenSaber port. Original 01.12 and 01.13 artifacts are
preserved locally. No official game assets or downloaded maps are published.
