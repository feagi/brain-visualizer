#!/usr/bin/env python3
"""
Update BVVersion.brain_visualizer_timestamp in godot_source/BrainVisualizer/BVVersion.gd.

Called from CI with one argument: Unix seconds (integer string).

The source file may have an inline comment after `int:` (e.g. `# set by github actions`).
The previous sed/regex approach failed because it did not allow that comment line.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: update_bvversion_timestamp.py <unix_timestamp>", file=sys.stderr)
        return 2

    ts = sys.argv[1]
    if not ts.isdigit():
        print(f"Invalid timestamp (must be digits): {ts!r}", file=sys.stderr)
        return 2

    root = Path(__file__).resolve().parent.parent
    path = root / "godot_source" / "BrainVisualizer" / "BVVersion.gd"
    if not path.is_file():
        print(f"Missing file: {path}", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")

    # Allow optional same-line comment after `int:` — matches real BVVersion.gd:
    # static var brain_visualizer_timestamp: int: # set by github actions
    # \tget: return 1774815021
    pattern = re.compile(
        r"(static var brain_visualizer_timestamp:\s*int:\s*(?:#[^\n]*)?\s*\n\s*get:\s*return\s*)\d+",
        re.MULTILINE,
    )
    new_text, count = pattern.subn(r"\g<1>" + ts, text, count=1)
    if count != 1:
        print(
            "Failed to update BVVersion.brain_visualizer_timestamp exactly once.\n"
            "Expected pattern: static var brain_visualizer_timestamp: int: [optional # comment]\n"
            "then get: return <digits>.\n"
            f"File head:\n{path.read_text(encoding='utf-8')[:800]}",
            file=sys.stderr,
        )
        return 1

    path.write_text(new_text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
