"""Package OpenSaberPlus with the working ps4_app=opensaber engine."""
from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
LOADER = PROJECT.parent / "GodotPCKLoader" / "port"
sys.path.insert(0, str(LOADER / "engine"))
from package_diagnostic import PSVR_ATTRIBUTE, check_icon, stage_runtime

VERSION = "01.19"
CONTENT_ID = "IV0000-OSAB00001_00-OPENSABERPS40001"


def main() -> None:
    home = Path.home()
    work = home / "ps4-godot-port-research"
    sdk = home / "ps4-tools/OpenOrbis/PS4Toolchain"
    elf = work / "godot-4.3/bin/godot.ps4.template_debug.x86_64.elf"
    data = elf.read_bytes()
    if b"Open Saber bundled game (OSAB00001)" not in data or b"/data/godot-games\0" in data:
        raise ValueError("Build ps4_app=opensaber first; refusing to package the PCK loader as OSAB00001")
    directory_object = work / "godot-4.3/drivers/unix/dir_access_unix.ps4.template_debug.x86_64.o"
    symbols = subprocess.check_output(["llvm-nm", "--undefined-only", str(directory_object)], text=True)
    if any(line.split()[-1] in ("getcwd", "chdir") for line in symbols.splitlines() if line.split()):
        raise ValueError("PS4 logical directories were compiled out; rebuild with the PS4_ENABLED core patch")
    game_source = (PROJECT / "game/game/BeepSaber_Game.gd").read_text()
    if f'"PS4 {VERSION}"' not in game_source:
        raise ValueError("Game version marker must match the package VERSION")
    delivery = PROJECT / "builds" / VERSION
    copied = delivery / f"Open-Saber-Plus-{VERSION}.pkg"
    if copied.exists():
        raise FileExistsError(f"Preserve existing release {copied}; bump VERSION before rebuilding")
    output = work / "native-output" / f"opensaber-{VERSION}"
    output.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "OO_PS4_TOOLCHAIN": str(sdk)}
    subprocess.run([str(sdk / "bin/linux/create-fself"), "-in=" + str(elf), "-out=" + str(output / "opensaber.oelf"), "--eboot", str(output / "eboot.bin"), "--paid", "0x3800000000000011", "--sdkver", "0x05508001"], env=env, check=True)
    for executable in (elf, output / "opensaber.oelf"):
        subprocess.run([sys.executable, str(LOADER / "tests/check_ps4_elf.py"), str(executable)], check=True)
    subprocess.run([sys.executable, str(LOADER / "tests/check_ps4_loader_layout.py"), str(elf), str(output / "opensaber.oelf"), str(output / "eboot.bin")], check=True)
    subprocess.run(["proot-distro", "login", "debian", "--bind", str(work) + ":/work", "--bind", str(PROJECT / "game") + ":/game", "--", "/work/godot-host/Godot_v4.3-stable_linux.arm64", "--headless", "--path", "/game", "--export-pack", "PS4 (OSAB00001)", "/work/native-output/opensaber-" + VERSION + "/eboot.pck"], check=True)
    # Test the exported PCK with fresh data: source-tree runs can hide missing raw song assets.
    with tempfile.TemporaryDirectory(prefix="opensaberplus-profile-test-pack-check-", dir=work) as temporary:
        user_dir = "/work/" + Path(temporary).name
        command = ["proot-distro", "login", "debian", "--bind", str(work) + ":/work", "--bind", str(PROJECT) + ":/source", "--", "env", "XDG_DATA_HOME=" + user_dir, "GODOT_PS4_USER_ID=00000001", "/work/godot-host/Godot_v4.3-stable_linux.arm64", "--headless", "--path", "/source/game", "--main-pack", "/work/native-output/opensaber-" + VERSION + "/eboot.pck", "--xr-mode", "off", "--audio-driver", "Dummy", "--quit-after", "1400"]
        for name, script, options, marker in (
            ("host-boot.log", "opensaber_boot_test.gd", [], "OPENSABER_BOOT_TEST PASS"),
            ("host-staged-boot.log", "opensaber_boot_test.gd", ["--", "--boot-screen"], "OPENSABER_BOOT_TEST PASS"),
            ("host-custom-map.log", "custom_map_test.gd", [], "CUSTOM_MAP_TEST PASS"),
            ("host-profile.log", "plus_profile_test.gd", [], "PLUS_PROFILE_TEST PASS"),
        ):
            check = subprocess.run(command + ["--script", "/source/port/tests/" + script] + options, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=80)
            (output / name).write_text(check.stdout)
            if check.returncode != 0 or marker not in check.stdout or "SCRIPT ERROR" in check.stdout or "Program crashed" in check.stdout:
                raise RuntimeError(f"Exported PCK failed the original-game boot fixture; see {output / name}")
    stage_runtime(sdk, output)
    (output / "sce_sys").mkdir(exist_ok=True)
    subprocess.run(["proot-distro", "login", "debian", "--bind", str(work) + ":/work", "--bind", str(PROJECT) + ":/source", "--", "/work/godot-host/Godot_v4.3-stable_linux.arm64", "--headless", "--script", "/source/port/prepare_artwork.gd", "--", "/source", "/work/native-output/opensaber-" + VERSION + "/sce_sys"], cwd=work, check=True)
    for name, size in (("icon0.png", (512, 512)), ("save_data.png", (228, 128)), ("pic1.png", (1920, 1080))):
        check_icon(output / "sce_sys" / name, size)
    (output / "licenses").mkdir(exist_ok=True)
    notices = {
        PROJECT / "game/LICENSE": "Open-Saber-MIT.txt",
        PROJECT / "game/README.md": "Open-Saber-credits.md",
        work / "godot-4.3/LICENSE.txt": "Godot-LICENSE.txt",
        work / "godot-4.3/COPYRIGHT.txt": "Godot-COPYRIGHT.txt",
        work / "orbis-compat/LICENSE": "Orbis-Compat-LICENSE.txt",
        work / "orbis-compat/LICENSING.md": "Orbis-Compat-LICENSING.md",
        work / "mesa-ps4/docs/license.rst": "Mesa-license.rst",
        LOADER / "engine/licenses/OpenOrbis-GPL-3.0.txt": "OpenOrbis-GPL-3.0.txt",
        LOADER / "engine/ps4/psvr/LICENSE.txt": "Native-PSVR-MIT.txt",
    }
    for source, name in notices.items():
        shutil.copyfile(source, output / "licenses" / name)
    dotnet = str(Path(sys.executable).parent / "dotnet")
    pkgtool = str(home / "ps4-tools/pkgtool/PkgTool.Core.dll")
    def tool(*args: str) -> None:
        subprocess.run([dotnet, pkgtool, *args], cwd=output, check=True)
    tool("sfo_new", "sce_sys/param.sfo")
    for key, value in {"APP_TYPE": 1, "ATTRIBUTE": PSVR_ATTRIBUTE, "DOWNLOAD_DATA_SIZE": 0, "SYSTEM_VER": 0}.items():
        tool("sfo_setentry", "sce_sys/param.sfo", key, "--type", "Integer", "--maxsize", "4", "--value", str(value))
    for key, (size, value) in {"APP_VER": (8, VERSION), "CATEGORY": (4, "gd"), "CONTENT_ID": (48, CONTENT_ID), "TITLE": (128, "Open Saber Plus"), "TITLE_ID": (12, "OSAB00001"), "VERSION": (8, VERSION)}.items():
        tool("sfo_setentry", "sce_sys/param.sfo", key, "--type", "Utf8", "--maxsize", str(size), "--value", value)
    files = ["eboot.bin", "eboot.pck"] + sorted(str(p.relative_to(output)) for folder in ("sce_sys", "sce_module", "licenses") for p in (output / folder).rglob("*") if p.is_file())
    assert all("sce_module/" + name in files for name in ("libSceFios2.prx", "libc.prx"))
    assert all(not any(c.isspace() for c in name) for name in files)
    subprocess.run([str(sdk / "bin/linux/create-gp4"), "-out", "pkg.gp4", "--content-id=" + CONTENT_ID, "--files", " ".join(files)], cwd=output, env=env, check=True)
    tool("pkg_build", "pkg.gp4", ".")
    package = output / (CONTENT_ID + ".pkg")
    tool("pkg_validate", str(package))
    delivery.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(package, copied)
    with package.open("rb") as f:
        digest = hashlib.file_digest(f, "sha256").hexdigest()
    with copied.open("rb") as f:
        assert hashlib.file_digest(f, "sha256").hexdigest() == digest
    (delivery / "SHA256SUMS.txt").write_text(f"{digest}  {copied.name}\n")
    print(f"Open Saber Plus {VERSION} candidate: {copied}\nSHA256: {digest}\nNot console-verified; installs as OSAB00001, not GDOT00001.")


if __name__ == "__main__":
    if len(sys.argv) != 1:
        raise SystemExit("Usage: python3 port/package_opensaber.py (no options)")
    main()
