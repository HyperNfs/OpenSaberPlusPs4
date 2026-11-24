<div align="center">
  <img src="icon.png" alt="Open Saber Plus for PS4 icon" width="128">
  <h1>OpenSaberPlus for PS4</h1>
  <p><strong>PSVR1 + PS Move rhythm homebrew, built on OpenSaberPlus and a patched Godot 4.3 PS4 engine.</strong></p>
  <p>
    <a href="https://github.com/HyperNfs/OpenSaberPlusPs4/releases/tag/opensaber-plus-ps4-v01.19"><img src="https://img.shields.io/badge/release-01.19%20beta-yellow?style=for-the-badge" alt="01.19 beta"></a>
    <a href="PS4-STATUS.md"><img src="https://img.shields.io/badge/PS4-check%20pending-orange?style=for-the-badge" alt="PS4 check pending"></a>
    <a href="game/LICENSE"><img src="https://img.shields.io/badge/game%20license-MIT-blue?style=for-the-badge" alt="MIT game source"></a>
  </p>
</div>

> [!NOTE]
> **01.19 is host-checked, not console-confirmed.** The native splash dismissal and
> black startup were verified against stubs and exported-PCK fixtures; real PS4/PSVR
> output is still pending. **01.14** remains the last user-accepted build (50–60 FPS).

## At a glance

| | |
|---|---|
| Upstream | [`arpruss/OpenSaberPlus`](https://github.com/arpruss/OpenSaberPlus) @ `8c5295cdaadf02ea7418b0c6cbea20240ba913af` (0.7.67) |
| Engine | Patched Godot 4.3 PS4 port — **not** a Godot 4.6 port |
| Current beta | [01.19 release](https://github.com/HyperNfs/OpenSaberPlusPs4/releases/tag/opensaber-plus-ps4-v01.19) |
| Known-good rollback | 01.14 (user-reported 50–60 FPS) |
| Input | PS Move + Options / headset, native PSVR1 stereo |
| Title ID | `OSAB00001` (replaces Open Saber Plus, not the `GDOT00001` loader) |

## Get the build

Download **`Open-Saber-Plus-01.19.pkg`** from the
[01.19 beta release](https://github.com/HyperNfs/OpenSaberPlusPs4/releases/tag/opensaber-plus-ps4-v01.19)
and verify it before installing:

```sh
sha256sum Open-Saber-Plus-01.19.pkg
# 86c567837b40e859b4cf711224397bca9744dd05db7587bd498d3b184fab904d
```

Close the game fully, install, and relaunch. Loading should be black, then the game.
If it stays black, capture fresh `opensaber-plus.log` and native logs—removing the
pictures alone does not prove the 3D path works.

See [PS4-STATUS.md](PS4-STATUS.md) for the full measured scope and limits,
[PROGRESS_SUMMARY.md](PROGRESS_SUMMARY.md) for version history, and
[port/README.md](port/README.md) for build/test instructions.

## Features

- Native PSVR stereo at 1152×1296 per eye since 01.15, with 1920×1080 TV output.
- Tap **Options / Move Start** to pause or resume; hold ≥ 1 s to recenter.
  Pause → Main Menu returns to song selection.
- Settings and Plus scores are isolated per launch account; songs stay shared in
  `user://OpenSaber/Songs/`. Restart after switching PS4 accounts.
- On tracking loss the last valid pose remains visible, but untracked hands cannot
  cut or score. No initial pose is fabricated.
- Bounded ZIP chart installation, verified HTTPS/CDN checks and strict constant-BPM
  v4 parsing. Variable timing, rotation/NJS changes and mods are **not** supported.

## Repository layout

```text
game/             PS4-adapted Godot project from upstream (credits in game/LICENSE)
port/             Packager, artwork prep and host fixtures
native-reference/ PS4 shell metadata used by the packager
PS4-STATUS.md     What is measured, pending and explicitly unsupported
PROGRESS_SUMMARY.md  Version-by-version build history
```

Building requires a separately prepared Godot 4.3 PS4 toolchain and SDK outside
this repository. The [release source archive](https://github.com/HyperNfs/OpenSaberPlusPs4/releases/tag/opensaber-plus-ps4-v01.19)
contains adaptations, patches and revision metadata; it does not auto-rebuild the
engine.

## Credits & license

Game code is MIT — see [`game/LICENSE`](game/LICENSE). Roboto is Apache-2.0,
the nightsky image is CC BY 4.0 (ESO/S. Brunier), and other notices remain in that
file. PS4 platform patches carry separate Godot/Mesa/OpenOrbis terms documented in
the release archives. Upstream attribution is preserved at
[`arpruss/OpenSaberPlus`](https://github.com/arpruss/OpenSaberPlus). No official
Beat Saber assets or downloaded maps are redistributed here.
