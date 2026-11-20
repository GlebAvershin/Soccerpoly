"""Exercise the production CareerStore lifecycle in Luau with an in-memory Roblox store."""
import os
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
career = (root / "src/server/CareerStore.luau").read_text()
config = (root / "src/shared/SponsorPass.luau").read_text()
fixture = (root / "tests/sponsor-pass.fixture.luau").read_text()
source = fixture.replace("-- INSERT SPONSOR CONFIG", config).replace("-- INSERT CAREER STORE", career)
with tempfile.TemporaryDirectory() as directory:
    script = Path(directory, "check.luau")
    script.write_text(source)
    subprocess.run([os.getenv("LUAU", "luau"), str(script)], check=True)
