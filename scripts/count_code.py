#!/usr/bin/env python3
"""Measure MoonBit source and test metrics without modifying the project."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MARKERS = ("TO" + "DO", "FIX" + "ME", "X" + "XX")


def loc(path: Path) -> int:
    return sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.strip())


moon_files = sorted(p for p in ROOT.rglob("*.mbt") if "_build" not in p.parts)
test_files = [p for p in moon_files if p.name.endswith("_test.mbt")]
cli_example_files = [
    p
    for p in moon_files
    if p not in test_files
    and (p.name.startswith("cli") or "cmd" in p.parts or "examples" in p.parts)
]
core_files = [p for p in moon_files if p not in test_files and p not in cli_example_files]

test_text = "\n".join(p.read_text(encoding="utf-8") for p in test_files)
named_tests = len(re.findall(r'^\s*test\s+"', test_text, flags=re.MULTILINE))

property_text = (ROOT / "property_test.mbt").read_text(encoding="utf-8")
property_cases = sum(int(n) for n in re.findall(r"while\s+i\s*<\s*(\d+)", property_text))

truncation_text = (ROOT / "truncation_test.mbt").read_text(encoding="utf-8")
fixture_block = truncation_text.split("let fixtures = [", 1)[1].split("  ]", 1)[0]
fixtures = []
for line in fixture_block.splitlines():
    match = re.match(r'^\s*("(?:[^"\\]|\\.)*")[,]?\s*$', line)
    if match:
        fixtures.append(json.loads(match.group(1)))
truncation_cases = sum(len(value) + 1 for value in fixtures) + 4

scan_files = [
    p
    for p in ROOT.rglob("*")
    if p.is_file() and "_build" not in p.parts and p.suffix in {".mbt", ".md", ".py", ".ps1", ".toml"}
]
marker_count = 0
for path in scan_files:
    text = path.read_text(encoding="utf-8")
    marker_count += sum(text.count(marker) for marker in MARKERS)

core_loc = sum(map(loc, core_files))
test_loc = sum(map(loc, test_files))
cli_examples_loc = sum(map(loc, cli_example_files))
total_loc = core_loc + test_loc + cli_examples_loc

print(f"core LOC: {core_loc}")
print(f"test LOC: {test_loc}")
print(f"CLI/examples LOC: {cli_examples_loc}")
print(f"total MoonBit LOC: {total_loc}")
print(f"named tests: {named_tests}")
print(f"property cases: {property_cases}")
print(f"truncation cases: {truncation_cases}")
print(f"unfinished-marker count: {marker_count}")
