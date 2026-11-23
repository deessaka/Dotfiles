#!/usr/bin/env python3
"""Safely update only the Team-owned block in user instruction files."""
import argparse
import os
from pathlib import Path
import re
import stat
import tempfile

def updated_text(path: Path, block: str) -> str:
    lines = block.splitlines()
    start, end = lines[0], lines[-1]
    if not (start.startswith("<!-- ") and start.endswith(":BEGIN -->")
            and end.startswith("<!-- ") and end.endswith(":END -->")):
        raise ValueError("marqueurs invalides dans le bloc fourni")
    if path.is_symlink():
        raise ValueError("AGENTS.md est un lien symbolique ; refus de le remplacer")
    current = path.read_text() if path.exists() else ""
    starts, ends = current.count(start), current.count(end)
    if (starts, ends) not in {(0, 0), (1, 1)}:
        raise ValueError("marqueurs présents ou dupliqués de façon incohérente")
    if starts:
        pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.S)
        return pattern.sub(block.rstrip(), current, count=1)
    return current.rstrip() + ("\n\n" if current.strip() else "") + block.rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("path", type=Path)
    parser.add_argument("block", type=Path)
    args = parser.parse_args()
    block = args.block.read_text()
    result = updated_text(args.path, block)
    if args.check:
        print("Bloc Team prêt à être actualisé.")
        return
    args.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    mode = stat.S_IMODE(args.path.stat().st_mode) if args.path.exists() else 0o600
    fd, temp_name = tempfile.mkstemp(prefix=".AGENTS.md.team-", dir=args.path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(result)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temp_name, mode)
        os.replace(temp_name, args.path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)
    print("Bloc Team actualisé.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        raise SystemExit(f"Erreur : {error}")
