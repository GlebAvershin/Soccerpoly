"""Launch a local playtest in Studio; fixtures never ship in the game build."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--rojo", default="rojo")
parser.add_argument("--players", type=int, choices=[1, 2, 4], default=1)
parser.add_argument("--device", choices=["portrait", "portrait-small", "landscape", "landscape-phone"])
parser.add_argument("--edition", choices=["en", "ru"], default="en")
parser.add_argument("--shot", choices=["goal", "save", "offside"], help="force a matchday outcome for visual QA")
parser.add_argument("--art", action="store_true", help="verify the Blender meshes and lobby music in a single-client test")
parser.add_argument("--matchday", action="store_true", help="verify formats, shot camera, goal meshes and audio in a single-client test")
parser.add_argument("--launchservices", action="store_true", help="use native macOS app launch instead of direct CLI")
parser.add_argument("--studio", default="/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio")
args = parser.parse_args()
args.rojo = str((root / args.rojo).resolve()) if (root / args.rojo).exists() else (shutil.which(args.rojo) or str(Path(args.rojo).resolve()))
if args.shot:
    args.matchday = True
if (args.art or args.matchday) and args.players != 1:
    parser.error("--art and --matchday use a single test client")
work = root / ".tools"
work.mkdir(exist_ok=True)
mode = {1: "WorldDraftSmoke", 2: "WorldDraftDuo", 4: "WorldDraftFour"}[args.players]
with tempfile.TemporaryDirectory(prefix=mode + "-", dir=work) as folder:
    tmp = Path(folder)
    shutil.copytree(root / "src", tmp / "src")
    shutil.copy(root / "default.project.json", tmp)
    shutil.copy(root / "tests/studio-report.server.luau", tmp / "src/server")
    shutil.copy(root / "tests/studio-player.client.luau", tmp / "src/client")
    place = tmp / "Soccerpoly QA.rbxl"
    subprocess.run([args.rojo, "build", "-o", str(place)], cwd=tmp, check=True)
    launch = tmp / "launch.luau"
    command = (f'test:ExecutePlayModeAsync("{mode}")' if args.players == 1
               else f'test:ExecuteMultiplayerTestAsync({args.players}, "{mode}")')
    device = ("local fixture = game:GetService('StarterPlayer').StarterPlayerScripts."
              f'Soccerpoly["studio-player"]\nfixture:SetAttribute("ExpectedPlayers", {args.players})\n')
    device += f'fixture:SetAttribute("Edition", "{args.edition}")\n'
    if args.shot:
        roll = {"goal": 1, "save": 4, "offside": 6}[args.shot]
        device += (f'fixture:SetAttribute("ExpectedShot", "{args.shot}")\n'
                   f'game:GetService("ServerScriptService").Soccerpoly.Match:SetAttribute("StudioShotRoll", {roll})\n')
    if args.art:
        device += 'fixture:SetAttribute("VerifyBlenderArt", true)\n'
    if args.matchday:
        device += ('fixture:SetAttribute("VerifyMatchday", true)\n'
                   'game:GetService("ServerScriptService").Soccerpoly.Match:SetAttribute("StudioMatchdaySmoke", true)\n')
    if args.device:
        portrait = args.device.startswith("portrait")
        direction = "Portrait" if portrait else "LandscapeLeft"
        device += f"""local sim = game:GetService("StudioDeviceSimulatorService")
sim:SetDeviceAsync("{'iphone_XR' if args.device == 'portrait' else 'iphone_7'}")
{'sim:SetResolutionAsync(640, 300)' if args.device == 'landscape' else ''}
local orientation = Enum.ScreenOrientation.{direction}
game:GetService("StarterGui").ScreenOrientation = orientation
sim:SetOrientationAsync(orientation)
game:GetService("StarterPlayer").StarterPlayerScripts.Soccerpoly["studio-player"]:SetAttribute("Device", "{args.device}")
"""
    launch.write_text("task.wait(2)\nlocal test = game:GetService('StudioTestService')\n"
                      + device + f'local result = {command}\nprint("WORLD DRAFT QA", result)\n')
    log_file = work / (mode + ("-" + args.device if args.device else "") + ".log")
    log_file.unlink(missing_ok=True)
    cmd = [args.studio, "--task", "RunScript", "--localPlaceFile", str(place),
           "--runScriptFile", str(launch), "--outputFile", str(log_file), "--quitAfterExecution"]
    if args.launchservices:
        cmd = ["open", "-n", "-W", "-a", str(Path(args.studio).parents[2]), "--args"] + cmd[1:]
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=210 if args.players == 4 else 110)
    finally:
        log = log_file.read_text() if log_file.exists() else ""
        print(log)
    assert "WORLD DRAFT QA PASS " + mode in log, f"Studio smoke failed: {log_file}"
