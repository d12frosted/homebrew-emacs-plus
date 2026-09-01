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


def sha_line_for(url_index):
    """Index of the sha256 stanza belonging to the url on url_index.

    brew style separates the two stanzas with a blank line in some blocks,
    so walk back over blanks and comments. Anything else ends the search:
    every url carries its own sha256, and borrowing the one from a
    neighbouring block would publish a cask that fails to verify.
    """
    for i in range(url_index - 1, -1, -1):
        stripped = lines[i].strip()
        if not stripped or stripped.startswith("#"):
            continue
        return i if "sha256" in stripped else None
    return None


for i, line in enumerate(lines):
    if pattern not in line or "url " not in line:
        continue
    sha_index = sha_line_for(i)
    if sha_index is None:
        print(f"  No sha256 stanza belongs to the url for {pattern}")
        sys.exit(1)
    lines[sha_index] = re.sub(r'"[a-f0-9]{64}"', '"' + sha + '"', lines[sha_index])
    print(f"  Updated SHA on line {sha_index + 1} for {pattern}")
    break
else:
    print(f"  No url matching {pattern} in {cask_file}")
    sys.exit(1)

with open(cask_file, "w") as f:
    f.writelines(lines)
