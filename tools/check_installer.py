#!/usr/bin/env python3
"""Verify GROWLIVO's standalone Roblox installer mirrors src/ exactly."""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "src"
INSTALLER = ROOT / "installer" / "INSTALLER_CommandBar.lua"
CONFIG = SOURCE_DIR / "GrowlivoConfig.lua"

ENTRY = re.compile(
    r'\{name="(?P<name>[^"]+)", className="(?P<class>[^"]+)", '
    r'target="(?P<target>[^"]+)", source=\[==\[(?P<source>.*?)\]==\]\},',
    re.DOTALL,
)

def verify() -> None:
    installer = INSTALLER.read_text(encoding="utf-8")
    start = installer.find("local packages = {")
    end = installer.find("\n}\n-- Preflight", start)
    if start < 0 or end < 0:
        raise AssertionError("Installer package list not found")
    package_text = installer[start:end]
    matches = list(ENTRY.finditer(package_text))
    sources = {f.stem: f for f in SOURCE_DIR.glob("*.lua")}
    if not matches:
        raise AssertionError("No packages found in installer")
    seen = set()
    for match in matches:
        name = match["name"]
        if name in seen:
            raise AssertionError(f"Duplicate package: {name}")
        seen.add(name)
        if name not in sources:
            raise AssertionError(f"Missing src/{name}.lua")
        if match["class"] not in {"Script", "ModuleScript", "LocalScript"}:
            raise AssertionError(f"Unexpected script class for {name}")
        if match["target"] not in {
            "ServerScriptService", "ReplicatedStorage", "StarterPlayerScripts"
        }:
            raise AssertionError(f"Unexpected install location for {name}")
        actual = sources[name].read_text(encoding="utf-8")
        if actual != match["source"]:
            raise AssertionError(f"Embedded source differs from src/{name}.lua")
    extra = sorted(set(sources) - seen)
    if extra:
        raise AssertionError(f"Sources missing from installer: {', '.join(extra)}")
    if len(matches) != 24:
        raise AssertionError(f"Expected 24 game packages; got {len(matches)}")
    version_match = re.search(r'Config\.Version\s*=\s*"([^"]+)"',
                              CONFIG.read_text(encoding="utf-8"))
    if not version_match:
        raise AssertionError("Config.Version missing")
    version = version_match.group(1)
    if f"GROWLIVO {version} / Command Bar Installer" not in installer:
        raise AssertionError("Installer header version differs from config")
    if f"{version} CLEAN installed: {len(matches)} game scripts" not in installer:
        raise AssertionError("Installer footer version/count mismatch")
    if "preservedAdminIds" not in installer:
        raise AssertionError("Installer must preserve existing admin IDs")
    print(f"OK: {len(matches)} scripts, matching installer, version {version}")

if __name__ == "__main__":
    try:
        verify()
    except (OSError, AssertionError) as exc:
        print(f"FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)
