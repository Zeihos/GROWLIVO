#!/usr/bin/env python3
"""Static safety checks for GROWLIVO's Luau definitions and auto-hatch contract.

These checks validate source data and server/client wiring. They do NOT run
Luau or substitute for actual multiplayer and DataStore tests in Roblox Studio.
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIG = (ROOT / "src" / "GrowlivoConfig.lua").read_text(encoding="utf-8")
SERVER = (ROOT / "src" / "GrowlivoServer.lua").read_text(encoding="utf-8")
CLIENT = (ROOT / "src" / "GrowlivoClient.lua").read_text(encoding="utf-8")

WORLD = re.compile(
    r'\{Id = "(\w+)", Name = "[^"]+", Multiplier = \d+, '
    r'UnlockRebirths = \d+, UnlockGems = \d+, EggId = "(\w+)"\}'
)
PET = re.compile(
    r'\{Id = "(\w+)", Name = "[^"]+", Rarity = "[^"]+", Bonus = \d+, Color = '
)
EGG = re.compile(
    r'^    (\w+) = \{Name = "[^"]+", Price = (\d+), World = "(\w+)", Drops = \{\n'
    r'(.*?)\n    \}\},?', re.MULTILINE | re.DOTALL,
)
DROP = re.compile(r'\{Species = "(\w+)", Chance = (\d+)\}')


def check() -> None:
    worlds = WORLD.findall(CONFIG)
    pets = PET.findall(CONFIG)
    eggs = EGG.findall(CONFIG)
    assert worlds, "Missing world definitions"
    assert pets, "Missing pet definitions"
    assert eggs, "Missing egg definitions"
    assert len(set(world for world, _ in worlds)) == len(worlds), "Duplicate worlds"
    assert len(set(pets)) == len(pets), "Duplicate pets"
    assert len(set(egg for egg, _, _, _ in eggs)) == len(eggs), "Duplicate eggs"

    egg_by_id = {name: (int(price), world, DROP.findall(drops))
                 for name, price, world, drops in eggs}
    used_pets = set()
    for world, egg_id in worlds:
        assert egg_id in egg_by_id, f"Unknown egg {egg_id} in {world}"
        price, assigned_world, drops = egg_by_id[egg_id]
        assert assigned_world == world, f"Egg {egg_id} belongs to {assigned_world}"
        assert price > 0, f"Invalid price in {egg_id}"
        assert drops, f"Egg {egg_id} has no drops"
        assert sum(int(chance) for _, chance in drops) == 100, (
            f"Drop odds in {egg_id} do not sum to 100%"
        )
        assert all(int(chance) > 0 for _, chance in drops), (
            f"Zero-probability drop in {egg_id}"
        )
        species = [species for species, _ in drops]
        assert len(species) == len(set(species)), f"Duplicate species in {egg_id}"
        assert all(species in pets for species in species), (
            f"Unknown pet species in {egg_id}"
        )
        used_pets.update(species)
    assert set(egg_by_id) == {egg_id for _, egg_id in worlds}, "Orphan eggs"
    assert used_pets == set(pets), "Unobtainable pet species"

    # Validate that auto hatch is opt-in, rate limited and shares the manual
    # server-owned purchase path, without using the blocking cinematic.
    assert 'Config.ProfileVersion = 7' in CONFIG, "Unexpected save schema version"
    assert 'Config.DataStoreName = "GROWLIVO_Profiles_v1"' in CONFIG, (
        "DataStore name changed"
    )
    assert re.search(
        r'Config.AutoHatch = \{UnlockRebirths = [1-9]\d*, '
        r'IntervalSeconds = [1-9]\d*\}', CONFIG
    ), "Invalid auto hatch limits"
    expected_server_fragments = (
        'if actionName == "ToggleAutoHatch" then',
        'if p.Rebirths < Config.AutoHatch.UnlockRebirths then',
        'hatch(player, p, 1, true)',
        'if not silent and (not isMax or i <= Config.MaxHatchBatch) then',
        'notify(player, "🤖 Автояйцо: " .. results[1].Name)',
        'if p and isReady(player) and player.Parent == Players',
        'p.Clicks < egg.Price or #p.Pets >= Config.MaxPetInventory',
        'setPlayerAttribute(player, "AutoHatchEnabled", false)',
    )
    for fragment in expected_server_fragments:
        assert fragment in SERVER, f"Missing server safety contract: {fragment}"
    assert 'Action:FireServer("ToggleAutoHatch")' in CLIENT, (
        "Client auto hatch button is disconnected"
    )
    for action in ("Hatch", "Hatch3", "HatchMax"):
        assert f'Action:FireServer("{action}")' in CLIENT, (
            f"Missing manual hatch action: {action}"
        )
    assert 'readyToBuy and maxCount >= entry.Count' in CLIENT, (
        "Egg buttons do not share affordability preview"
    )
    # Accidental destructive actions and redundant equip writes.
    assert 'rebirthPending = true' in CLIENT
    assert 'rebirthTarget = attr("Rebirths")' in CLIENT
    assert 'rebirth.Text = "⚠ ПОДТВЕРДИТЬ\\nСБРОС УЛУЧШЕНИЙ"' in CLIENT
    assert 'if ticket == rebirthNonce and rebirthPending then' in CLIENT
    assert 'if release.Parent and release.Text == "..." then' in CLIENT
    assert 'release.Active = true' in CLIENT
    assert 'if unchanged then' in SERVER and (
        'notify(player, "Лучшие питомцы уже экипированы")' in SERVER
    ), "Redundant equip actions should not create dirty snapshots"
    print(f"OK: {len(worlds)} worlds, {len(eggs)} eggs, "
          f"{len(pets)} obtainable pets; automation and safety UI static contracts")


if __name__ == "__main__":
    try:
        check()
    except (AssertionError, OSError, ValueError) as exc:
        print(f"FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)
