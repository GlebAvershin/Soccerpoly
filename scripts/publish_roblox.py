#!/usr/bin/env python3
"""Publish the compiled Soccerpoly place directly to Roblox via Open Cloud API."""
import os
import sys
from pathlib import Path
import urllib.request
import urllib.error
import json

ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / ".env"

DEFAULT_UNIVERSE_ID = "10777507892"
DEFAULT_PLACE_ID = "114770772027261"
DEFAULT_PLACE_PATH = ROOT / "dist/Soccerpoly.rbxl"


def load_env():
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def publish(universe_id: str = DEFAULT_UNIVERSE_ID, place_id: str = DEFAULT_PLACE_ID, rbxl_path: Path = DEFAULT_PLACE_PATH):
    load_env()
    api_key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY")
    if not api_key:
        print("[ERROR] ROBLOX_OPEN_CLOUD_API_KEY not found in environment or .env file.")
        print("Please create an API key in Creator Dashboard -> Credentials and set:")
        print("  ROBLOX_OPEN_CLOUD_API_KEY=your_key_here in .env")
        sys.exit(1)

    if not rbxl_path.exists():
        print(f"[ERROR] Binary place file not found: {rbxl_path}")
        print("Please build it first: make build (or rojo build)")
        sys.exit(1)

    size_mb = rbxl_path.stat().st_size / (1024 * 1024)
    print(f"Publishing {rbxl_path.name} ({size_mb:.2f} MB) to Roblox Place {place_id} (Universe {universe_id})...")

    with open(rbxl_path, "rb") as f:
        payload = f.read()

    url = f"https://apis.roblox.com/universes/v1/{universe_id}/places/{place_id}/versions?versionType=Published"
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "x-api-key": api_key,
            "Content-Type": "application/octet-stream",
            "User-Agent": "Soccerpoly-Deploy/1.0",
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            version_number = data.get("versionNumber")
            print(f"🎉 Successfully published to Roblox!")
            print(f"   Place ID: {place_id}")
            print(f"   Universe ID: {universe_id}")
            print(f"   New Version: #{version_number}")
            print(f"   Live URL: https://www.roblox.com/games/{place_id}/Soccerpoly")
            return version_number
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"[ERROR] Roblox API rejected upload (HTTP {e.code}): {body}")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] Failed to publish: {e}")
        sys.exit(1)


if __name__ == "__main__":
    publish()
