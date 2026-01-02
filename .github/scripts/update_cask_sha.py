#!/usr/bin/env python3
"""Update SHA256 in cask file for a specific arch-os URL pattern."""
import re
import sys

if len(sys.argv) != 4:
    print(f"Usage: {sys.argv[0]} <cask_file> <sha> <url_pattern>")
    sys.exit(1)

cask_file = sys.argv[1]
sha = sys.argv[2]
pattern = sys.argv[3]

with open(cask_file, "r") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if pattern in line and i > 0 and "sha256" in lines[i - 1]:
        lines[i - 1] = re.sub(r'"[a-f0-9]{64}"', '"' + sha + '"', lines[i - 1])
        print(f"  Updated SHA on line {i} for {pattern}")
        break

with open(cask_file, "w") as f:
    f.writelines(lines)
