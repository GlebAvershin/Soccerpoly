"""Run the C++ balance inspector on the same validated catalog that ships in Roblox."""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

from event_studio import ROOT, load


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cxx", default="c++")
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    rules, expected = load()
    work = ROOT / ".tools"
    work.mkdir(exist_ok=True)
    executable = work / "cup-preview"
    command = [args.cxx, "-std=c++17", "-O2", "-Wall", "-Wextra", "-Werror",
               str(ROOT / "native/cup_preview.cpp"), "-o", str(executable)]
    if sys.platform == "darwin":
        command.extend(["-framework", "OpenGL"])
    subprocess.run(command, check=True)
    data = f"{rules['safe_cash']} {rules['trophy_value']}\n"
    for shot in rules["shots"]:
        data += f"{shot['result']} {shot['cash']} {shot['weight']}\n"
    run = [str(executable)]
    if args.preview:
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        run.extend(["--preview", str(args.preview)])
    result = subprocess.run(run, input=data, text=True, check=True, capture_output=True)
    numbers = dict(pair.split("=") for pair in result.stdout.splitlines()[0].split())
    assert float(numbers["expected_cash"]) == expected["shot_expected_cash"]
    assert float(numbers["expected_value"]) == expected["shot_expected_value"]
    if args.preview:
        image = args.preview.read_bytes()
        assert image.startswith(b"P6\n960 540\n255\n") and len(set(image[20:])) >= 12
    print(result.stdout, end="")


if __name__ == "__main__":
    main()
