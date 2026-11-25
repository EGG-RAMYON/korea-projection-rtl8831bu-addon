import hashlib
import sys
import zipfile
from pathlib import Path

out = Path(sys.argv[1])
name = sys.argv[2]
inner = out / f"{name}.zip"
with zipfile.ZipFile(inner) as z:
    assert z.testzip() is None
    meta = z.read("NEMESIS.data").decode()
    assert "depends=\"korea.projection@1.8.0\"" in meta
    assert "id=korea.projection.rtl8831bu\n" in meta
    assert "[service." not in meta
    for line in z.read("bin/payload.sha256").decode().splitlines():
        checksum, name_in_bin = line.split()
        assert hashlib.sha256(z.read("bin/" + name_in_bin)).hexdigest() == checksum
    assert z.read("bin/8851bu.ko") == (out / "8851bu.ko").read_bytes()
    changed = {(str(p)) for p in z.namelist() if p.endswith((".apk", "88x2bu.ko"))}
    assert not changed, changed
    for executable in ["bin/kp-eject", "bin/status.sh", "scripts/pre.sh", "scripts/post.sh", "scripts/preun.sh"]:
        assert (z.getinfo(executable).external_attr >> 16) & 0o777 == 0o755
with zipfile.ZipFile(out / f"{name}-usb.zip") as z:
    assert z.testzip() is None
    assert z.read("NEMESIS.data") == f"[nemesis]\ntype=install\npath=packages/{name}.zip\n".encode()
    assert z.read(f"packages/{name}.zip") == inner.read_bytes()
with zipfile.ZipFile(out / f"{name}-recovery-usb.zip") as z:
    assert z.testzip() is None
    assert b"type=execute\n" in z.read("NEMESIS.data")
    assert "NEMESIS.emergency" not in z.namelist()
print("PASS: archive payload SHA-256, module, dependency, permissions, USB nesting, recovery requires confirmation")
