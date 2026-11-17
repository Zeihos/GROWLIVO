#!/usr/bin/env python3
"""Regenerate embedded Luau sources in the standalone Roblox Studio installer.

Only package source fields are replaced. Names, classes, targets, and the
installer's backup/rollback logic remain unchanged.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

from check_installer import ENTRY, INSTALLER, SOURCE_DIR, verify


def build() -> tuple[str, list[str]]:
    installer = INSTALLER.read_text(encoding="utf-8")
    start = installer.find("local packages = {")
    end = installer.find("\n}\n-- Preflight", start)
    if start < 0 or end < 0:
        raise ValueError("Installer package section not found")

    block = installer[start:end]
    packages = list(ENTRY.finditer(block))
    sources = {path.stem: path for path in SOURCE_DIR.glob("*.lua")}
    names = [match["name"] for match in packages]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate package names")
    if not names or set(names) != set(sources):
        missing = sorted(set(sources) - set(names))
        stale = sorted(set(names) - set(sources))
        raise ValueError(f"Package/source mismatch: missing={missing}, stale={stale}")
    if block.count("source=[==[") != len(packages):
        raise ValueError("Unparseable package source block")

    changed = []
    cursor = 0
    fragments = []
    for match in packages:
        name = match["name"]
        source = sources[name].read_text(encoding="utf-8")
        if "]==]" in source:
            raise ValueError(f"Unsupported embedded delimiter in src/{name}.lua")
        if source != match["source"]:
            changed.append(name)
        fragments.append(block[cursor:match.start("source")])
        fragments.append(source)
        cursor = match.end("source")
    fragments.append(block[cursor:])
    new_block = "".join(fragments)
    return installer[:start] + new_block + installer[end:], changed


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Проверить или синхронизировать исходники с установщиком."
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--write", action="store_true",
                       help="встроить обновлённые исходники в установщик")
    group.add_argument("--check", action="store_true",
                       help="только проверить; режим по умолчанию")
    args = parser.parse_args()

    try:
        content, changed = build()
        if changed and not args.write:
            print("Несинхронизированные скрипты: " + ", ".join(changed),
                  file=sys.stderr)
            print("Запусти: python3 tools/sync_installer.py --write",
                  file=sys.stderr)
            return 1
        if args.write and changed:
            INSTALLER.write_text(content, encoding="utf-8")
            print("Обновлено встроенных скриптов: " + ", ".join(changed))
        verify()
    except (OSError, ValueError, AssertionError) as exc:
        print(f"Ошибка: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
