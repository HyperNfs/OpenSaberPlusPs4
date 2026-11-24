"""Both packagers must reject the other application's engine before writing output."""
from pathlib import Path
import importlib.util
import tempfile
from unittest.mock import patch

project = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("package_opensaber", project / "port/package_opensaber.py")
opensaber = importlib.util.module_from_spec(spec)
spec.loader.exec_module(opensaber)
import package_diagnostic as loader

for module, contents in ((opensaber, b"ordinary loader ELF"), (loader, b"Open Saber bundled game (OSAB00001)")):
    with tempfile.TemporaryDirectory() as temporary:
        home = Path(temporary)
        elf = home / "ps4-godot-port-research/godot-4.3/bin/godot.ps4.template_debug.x86_64.elf"
        elf.parent.mkdir(parents=True)
        elf.write_bytes(contents)
        with patch.object(Path, "home", return_value=home):
            try:
                module.main()
            except ValueError:
                pass
            else:
                raise AssertionError("Wrong application ELF accepted: " + module.__name__)
        assert not (home / "ps4-godot-port-research/native-output").exists()
for forbidden in ("getcwd", "chdir"):
    with tempfile.TemporaryDirectory() as temporary:
        home = Path(temporary)
        elf = home / "ps4-godot-port-research/godot-4.3/bin/godot.ps4.template_debug.x86_64.elf"
        elf.parent.mkdir(parents=True)
        elf.write_bytes(b"Open Saber bundled game (OSAB00001)")
        with patch.object(Path, "home", return_value=home), patch.object(opensaber.subprocess, "check_output", return_value="                 U " + forbidden + "\n"):
            try:
                opensaber.main()
            except ValueError as error:
                assert "compiled out" in str(error)
            else:
                raise AssertionError("Unsupported directory import accepted: " + forbidden)
        assert not (home / "ps4-godot-port-research/native-output").exists()
assert opensaber.CONTENT_ID == "IV0000-OSAB00001_00-OPENSABERPS40001"
assert loader.CONTENT_ID == "IV0000-GDOT00001_00-GODOTPS4GPU00001"
print("PASS: app identities stay separate; wrong bootstrap and unsupported native cwd imports fail before output")
