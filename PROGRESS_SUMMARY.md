# OpenSaberPlus PS4 progress

## 01.19 — native system-splash dismissal + no-art startup (HMD check pending)

User m05717: 01.17 enters VR but still shows splash after loading/warm-up; requests
removing it completely. First removal-only checkpoint01.18 was built but NEVER
uploaded. It removes engine splash image/show flag and duplicated game artwork,
turns bootstrap into a nondrawing Node with no children, logs loading/errors to
console and uses opaque-black startup/shell background. User's icon and original
root splash PNG remain intact; root splash is unused. Existing first-draw/warmup
sequence, native1152x1296 stereo, settings/songs/accounts/height remain unchanged.

Root platform omission discovered before final upload: unlike SDK Piglet sample,
OS_PS4::run never called sceSystemServiceHideSplashScreen(). Shell pic1 is a
separate OS overlay, so removing/hiding a Godot CanvasLayer cannot dismiss it.
01.19 loads ORBIS_SYSMODULE_INTERNAL_SYSTEM_SERVICE and calls HideSplashScreen
once after the first non-exiting Main::iteration, logging success or failure.
Actual OS loop compiled against host stubs under strict UBSan: first-frame order,
one-shot behavior, no-loop/early exit and failed-call diagnostics PASS.
Native rebuild30.93s PASS. Direct/staged PCK boot asserts no visual bootstrap or
engine splash; rendering/input/recovery, map/ZIP, account/profile/pitch guards
PASS. Package entries/hashes/signatures PASS. Previous15 backend baseline logs
are retained explicitly as baseline, not relabelled as a new run.

Built builds/01.19/Open-Saber-Plus-01.19.pkg, 95,748,096B, SHA256
86c567837b40e859b4cf711224397bca9744dd05db7587bd498d3b184fab904d.
Matching native ELF/FSELF/PCK/source/tests will be preserved; delivery.json records
actual upload/readback status. No automatic install/launch. Real console proof
of splash dismissal and usable VR is still required. Do not release16/17/18.


## 01.13 — first Plus candidate built

User authorized replacing the game with arpruss/OpenSaberPlus, then requested a
separate optimization/image-quality pass after Plus is made. Original Open Saber
sources and preserved 01.12 remain unchanged. Upstream revision and migration
contract are in README.md. No Godot 4.6 engine migration was necessary for host
compatibility; game is adapted to the working PS4 Godot 4.3 backend.

Built `builds/01.13/Open-Saber-Plus-01.13.pkg`, SHA256
`602f905ae6b0924e405e4ad7437b6dd0a62fd4889fe59037d09f31902e48f547`.
Native binary is unchanged from the repaired 01.11/01.12 backend. Packager passed
native layout checks, direct and staged exported-PCK boot, synthetic custom maps,
profile migration and package integrity validation. External actual map 517ad
also passed Ogg decode and 32 repeated loads with all expected note/event counts.
These checks assert no SCRIPT ERROR or Program crashed; a zero exit alone was
not accepted (earlier failed fixtures returned zero).

Fixed fork integration issues found by tests: raw sample cover Keep import and
independent highscore placeholder; S3TC/BPTC imports for AMD instead of ETC-only;
v2 malformed-record loop that never advanced; arc smoothing before tail existed;
idle particles restarting; repeated speed-change pitch compensation; optional
YouTube path lookup; clear stale ConfigFile keys on reload.

Shared songs, separate Plus score/settings profile, non-destructive preference
migration, PSVR/Move/Options/height, safe downloader and strict v4 guards carry
over. Variable-BPM/rotation/NJS/mod charts remain unsupported by the strict path.

Console installation/launch has NOT been performed. Full-song playback, HMD
colour/alignment, app restarts and real performance remain unverified. 01.13 is
preserved as a checkpoint before the following optimization changes.

## 01.14 — optimized Plus candidate built

Package `builds/01.14/Open-Saber-Plus-01.14.pkg`, SHA256
`8e7966acfd9a676fd5d3ba0c11a3f74da3c8a36574ee81e470c86783fcbd3785`.

Native PSVR now GPU-copies the two array layers into a reusable vertically packed
2D atlas and makes ONE fenced CPU read, rather than two. Eye size stays 960x1080,
colour format/conversion stays intact and native label-retirement/owned memory is
unchanged. Atlas uses transfer flags, NOT CPU_READ (Godot maps CPU_READ without
waiting for queued copies). Failed atlas creation/copy falls back to the working
per-eye path AFTER draining queued work; failures are not retried each frame.
Cleanup resets the optimization for the next session. Costs about 8 MiB GPU atlas
plus two GPU image copies/frame; actual net speedup is hardware-dependent.

Native logs now print readback/native-copy average microseconds after the first
120 frames and then every 1200, within the existing local 4 MiB cap. These are NOT
headset FPS and no 60/120 FPS claim is made. No Godot-core or Mesa modifications
were needed for batching. Native compile/link and the full documented strict
UBSan backend suite passed, including a new test of the ACTUAL readback helper:
byte-exact left/right/row/format order, reuse/format change, one read, invalid/short
reads, failed second-copy drain-before-free, cached fallback and reinitialization.

Game HUD no longer emits global score changes every physics tick. Actual score
changes notify immediately AFTER accuracy updates; only the song clock is polled
at 4 Hz. Both UI fonts now use MSDF. Exported-PCK tests assert imported MSDF fonts,
no idle score dispatch, live clock and correct score-event data. Existing direct
and staged boot/Options/height, safe map installation, repeated v2/v3/v4 loading
and profile/pitch migration fixtures pass; actual map 517ad audio/32 loads also
pass again. Package format/digests/signatures and native layout checks pass.

Original OpenSaberPS4 and preserved 01.12/Plus 01.13 remain untouched. No automated
console install/launch; see delivery.json for the actual transfer outcome. Native
GPU copies, HMD fonts/colour/tracking and full gameplay/performance still need PS4
acceptance; host mocks/dummy rendering do not establish those results.

## 01.15 — release preparation candidate

User confirmed 01.14 works very well at 50–60 FPS. New request: sharper image,
zero default height, per-account profiles, visible last poses on tracking loss,
and supplied icon/splash artwork. Original 01.14 is preserved as FPS rollback.

Built `builds/01.15/Open-Saber-Plus-01.15.pkg` (98,369,536 bytes), SHA256
`816eab6033cd6763234a13ebc3c3bb0a9907e97e5ac55f11fad1dd91191b1fdd`.
Native rebuilt successfully. Eye inputs are 1152x1296 (1.2x each dimension, 44%
more pixels); native scanout stays 1920x1080 and stereo batching/BGRA conversion
stay unchanged. Compositor owned allocation is bounded at 56 MiB, up from 48.
Default game viewport has PS4-specific 1920x1080 overrides. Further speculative
performance changes were skipped; this image-quality increase needs real FPS tests.

Height default is now 0.0, without silently overriding explicit saved offsets.
Native GetInitialUser supplies the launch-account ID; failure exits before scripts
rather than opening a shared unidentified profile. Strict fixed-width hex paths
separate settings, Plus scores and play counts by account. Songs remain shared.
Only the first account migrates legacy shared preferences/Plus scores/counts;
existing and legacy files are not overwritten. A different PS4 account requires
restarting the application. Profiles are ordinary local files, not encrypted saves.

Tracking updates commit both eyes/head/render pose only after all validation.
After a valid pose, tracking loss keeps last-known view/hand positions visible;
tracking validity remains false and untracked sabers cannot cut/score. Reacquired
hands reset swing/raycast history, preventing teleport-hit sweeps. Initial pose
is not fabricated. This is visual continuity, not replacement tracking: pause if
tracking is lost, and verify occlusion/recovery with the real PSVR SDK.

User artwork is included in game boot, PS4 icon0/save_data/pic1, with constrained
RGB8 PNG dimensions and black letterboxing rather than stretched/cropped content.
Strict UBSan backend suite, actual extracted tracking-method tests, enlarged
compositor bounds, account formatting, direct/staged exported boot/control tests,
two-account migration/default/score/count/pitch tests, guarded map tests and real
517ad Ogg/32 repeated loads all passed. PNG/package layout/digests/signatures pass.
Preserve matching native symbols/FSELF/PCK/source and consult delivery.json for
transfer status. No automatic console install/launch. Before public release:
check TV/HMD sharpness and FPS, cover/reveal headset and each Move, and restart
under two PS4 accounts to confirm isolation and first-owner legacy migration.

## 01.16 — final release-preparation candidate

01.15 remains an unuploaded, preserved checkpoint. Final review found legacy
(non-swing) scoring retained controller movement bounds across reacquisition.
01.16 additionally resets that AABB on loss/recovery and adds a seeded-AABB
regression assertion, preventing the next real cut from receiving phantom travel
bonus. Native code/binary is unchanged from the compiled/tested 01.15 engine.
All 01.15 features, supplied artwork and limitations above apply unchanged.

Built `builds/01.16/Open-Saber-Plus-01.16.pkg` (98,369,536 bytes), SHA256
`10f64668b59e5d48d4820484e25d254f236db1daa8d38754c0d87f7829904d69`.
Direct/staged exported-PCK controls, tracking/legacy bounds, maps and two-account
profiles pass; package layout/digests/signatures pass. Native build/backend logs
are the matching unchanged 01.15 build. Actual 517ad repeated-load validation is
recorded separately. Before public release, perform the same real FPS/occlusion/
two-account restart checks described above. No automatic install/launch; consult
the final release's delivery.json for transfer status.

## 01.17 — startup handoff hotfix candidate (console confirmation pending)

User m05566/m05585 reports 01.16 runs/FPS moves but retains the splash and does
not show usable VR. Read-only capture, no relaunch: private investigation under
~/ps4-godot-port-research/opensaberplus-01.16-splash-20261025-200838/.
IMPORTANT: Plus logs to /data/opensaber/game/logs/opensaber-plus.log. The older
opensaber.log belongs to the original game and must not drive this diagnosis.
Current Plus log reaches original scene/pools/native 1152x1296 initialization,
map selection and loading-screen-finished, with no GDScript error. Native log
shows ongoing stereo readback/submission and tracking. A set_frustum p_right <=
p_left warning occurs at transition; its origin is not conclusively established.

Instead of relying only on deferred queue_free after VR starts, boot joins the
ps4_boot_overlay group; _initialize_psvr hides that group BEFORE its existing
frame_post_draw barrier/native initialize call. Completion also hides explicitly
before queue_free. This ensures a splash-free scene draw before scanout handoff.
Removed only the new PS4 logical window 1920x1080 overrides, restoring the known
960x540 setup. Native output remains 1920x1080 and per-eye inputs remain1152x1296.
Native code/ELF is unchanged from the compiled/tested01.15 engine.

Built builds/01.17/Open-Saber-Plus-01.17.pkg, SHA256
f69a2e2a58efb826d078910c03eb44884f65cdbb671ef10de8f02e17e6cd3f9a.
Direct/staged exported-PCK boot now asserts no visible splash at XR initialize;
profile/map guards and package entries/signatures pass. All account/height/
tracking-loss/artwork features retained. Real 517ad validation logged separately.
Consult delivery.json for transfer/readback verification. No install/launch by
agent. Still needs actual PS4/HMD transition confirmation before public release;
this fixes handoff ordering but host fixtures cannot prove visual recovery.
