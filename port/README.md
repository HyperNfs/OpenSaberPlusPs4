# PS4 packaging / checks

From this project root:

```sh
python3 port/package_opensaber.py
```

The packager reuses the already-built, repaired Godot 4.3 `ps4_app=opensaber`
engine at `~/ps4-godot-port-research/godot-4.3`. It checks application identity,
PS4 directory ABI, ELF/FSELF layout, matching visible game/package versions,
then exports a PS4-feature-tagged PCK with x86 S3TC/BPTC texture imports.
Bundled covers use the Keep importer because songs are copied as raw files.

Direct and staged exported-PCK boot fixtures exercise a fake PSVR backend,
first-draw gating, pooling, axes, triggers, defaults/uncapped height and
Options pause/resume/countdown/recenter/menu. Custom-map tests exercise malformed
ZIPs/JSON, staging/queue failures and repeated v2/v3/v4 loads. The separate Linux
profile fixture requires an explicitly isolated XDG_DATA_HOME; never run it on
real user data. The exported-PCK host tests set GODOT_PS4_USER_ID=00000001 to
simulate native account identity (actual PS4 startup resolves and replaces it).
Assertions cover two-account isolation, first-owner-only migration, unchanged
legacy files, zero height defaults, explicit offset persistence and pitch changes.
Tracking-loss tests keep hands visible, prevent cuts and reset reacquisition rays.
Native tests also compile the actual head tracking-update method with host types.

The packager refuses replacing an existing versioned PKG, requires pass markers
and absence of SCRIPT ERROR / Program crashed, retains the supplied root icon
and generates opaque-black pic1 via prepare_artwork.gd (no splash artwork),
validates RGB8 dimensions, includes runtime dependencies/licences, then validates
all package entries/hashes. Engine show_image is false; bootstrap is a plain Node
with no drawing children. The native OS loop loads SystemService and calls
sceSystemServiceHideSplashScreen once after the first running frame, following
the SDK sample. tests/test_ps4_splash.py in the shared platform compiles that exact
loop against host stubs and checks order, one-shot behavior and failure logging.
These checks do not substitute for confirming the real PS4 overlay disappears.

Actual public map 517ad is NOT redistributed with the source or installer. To
repeat its extra test, supply its ZIP to `custom_map_test.gd` after `-- --map-zip
/path/to/map.zip` with a PS4-feature-tagged PCK. It validates/decompresses and
checks Ogg audio plus 32 loads of 612 notes, 28 arcs, 2 chains and 962 events.

Outputs: `builds/<version>/Open-Saber-Plus-<version>.pkg`. Title ID OSAB00001 is
an intentional replacement for Open Saber, NOT the GDOT00001 PCK loader. No
console upload, install or launch is performed by this packager. Preserve source,
matching ELF/FSELF/PCK, logs, native baseline/patches and checksums per release.

Host dummy rendering prints viewport/dummy-mesh warnings. Deliberately invalid
map fixtures print validation warnings; neither substitutes for real HMD/GPU
coverage. Native backend details remain in ../GodotPCKLoader/port/engine/README.md.
