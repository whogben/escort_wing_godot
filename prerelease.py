#!/usr/bin/env python3
"""Pre-release verification and web export for Escort Wing.

The web build (``docs/``) is the project's main deployment target, so this
script makes sure a release is actually good to go before publishing it to
GitHub Pages. It:

1. Verifies the "Web" export preset bundles every *raw* (non-resource) data
   format the game reads at runtime: ``.lvl .sfo .wfo .pfo .particle``.
   These are plain text files (not imported resources), so they only ship if
   listed in the preset's ``include_filter``. Dropping ``.wfo``/``.pfo`` here
   silently strips every weapon and projectile definition from the export,
   which disables all weapon firing in the web build while the editor still
   works fine -- see ``WEAPON_FIRING_INVESTIGATION.md``.
2. Re-exports the Web build into ``docs/``.
3. Confirms every raw data file on disk actually landed in ``docs/index.pck``,
   so a packaging regression fails loudly here instead of in players' browsers.

Pure standard library; run with any Python 3:

    python3 prerelease.py            # verify preset, export, verify pck
    python3 prerelease.py --no-export  # only verify the existing docs/ build
    python3 prerelease.py --godot /path/to/Godot  # explicit engine binary
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent
DATA_DIR = PROJECT_DIR / "data"
DOCS_DIR = PROJECT_DIR / "docs"
PRESET_FILE = PROJECT_DIR / "export_presets.cfg"
PCK_FILE = DOCS_DIR / "index.pck"
EXPORT_TARGET = DOCS_DIR / "index.html"

PRESET_NAME = "Web"

# Raw, non-resource data formats GameData reads with FileAccess at runtime.
# Imported assets (.png/.ogg) ship automatically via export_filter; these do
# not, so each one must appear in the preset's include_filter. Keep in sync
# with GameData.type_info.
RAW_DATA_EXTS = ["lvl", "sfo", "wfo", "pfo", "particle"]
CANONICAL_INCLUDE_FILTER = ", ".join(f"*.{ext}" for ext in RAW_DATA_EXTS)

# Files every healthy web export must (re)produce.
REQUIRED_OUTPUTS = ["index.html", "index.js", "index.wasm", "index.pck"]

# Canary files: if these are missing from the pck, weapons will not fire.
CRITICAL_DATA_FILES = [
    "data/original_game/Weapon Infos/Pirate Gatling.wfo",
    "data/original_game/Projectile Infos/Illegally Copied Laser Pulse.pfo",
]


class CheckError(Exception):
    """A pre-release check failed."""


def _ok(msg: str) -> None:
    print(f"  [ok]   {msg}")


def _note(msg: str) -> None:
    print(f"  [note] {msg}")


def _warn(msg: str) -> None:
    print(f"  [warn] {msg}")


def find_godot(explicit: str | None) -> str:
    """Locate the Godot 4 binary (explicit arg > $GODOT_BIN > PATH > macOS app)."""
    candidates: list[str] = []
    if explicit:
        candidates.append(explicit)
    if os.environ.get("GODOT_BIN"):
        candidates.append(os.environ["GODOT_BIN"])
    for name in ("godot", "godot4", "Godot"):
        found = shutil.which(name)
        if found:
            candidates.append(found)
    candidates.append("/Applications/Godot.app/Contents/MacOS/Godot")

    for path in candidates:
        if path and Path(path).exists():
            return path
    raise CheckError(
        "Could not find the Godot binary. Set $GODOT_BIN or pass --godot /path/to/Godot."
    )


def editor_is_running() -> bool:
    """True if a Godot editor appears to be open on this project.

    The editor holds export_presets.cfg in memory and rewrites it on save, so
    an open editor can silently revert include_filter fixes.
    """
    try:
        out = subprocess.run(
            ["ps", "ax", "-o", "command"],
            capture_output=True,
            text=True,
            check=False,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    project_token = str(PROJECT_DIR)
    for line in out.splitlines():
        if "Godot" in line and project_token in line and "--export" not in line:
            return True
    return False


def _find_web_preset_bounds(lines: list[str]) -> tuple[int, int]:
    """Return [start, end) line indices of the ``[preset.N]`` block named Web."""
    header_re = re.compile(r"^\[preset\.\d+\]\s*$")
    block_starts = [i for i, ln in enumerate(lines) if header_re.match(ln)]
    for idx, start in enumerate(block_starts):
        end = block_starts[idx + 1] if idx + 1 < len(block_starts) else len(lines)
        # The options sub-block ([preset.N.options]) ends the top-level block.
        for j in range(start, end):
            if lines[j].strip().endswith(".options]") and lines[j].lstrip().startswith("[preset."):
                end = j
                break
        block = lines[start:end]
        if any(re.match(rf'^name\s*=\s*"{re.escape(PRESET_NAME)}"\s*$', b) for b in block):
            return start, end
    raise CheckError(f'No "{PRESET_NAME}" preset found in {PRESET_FILE.name}.')


def check_include_filter(fix: bool) -> None:
    """Ensure the Web preset's include_filter covers all raw data extensions."""
    print(f"Checking export preset include_filter ({PRESET_FILE.name})...")
    if not PRESET_FILE.exists():
        raise CheckError(f"{PRESET_FILE} does not exist.")

    text = PRESET_FILE.read_text()
    lines = text.splitlines()
    start, end = _find_web_preset_bounds(lines)

    filter_idx = None
    for i in range(start, end):
        if lines[i].lstrip().startswith("include_filter"):
            filter_idx = i
            break
    if filter_idx is None:
        raise CheckError(f'"{PRESET_NAME}" preset has no include_filter line.')

    current_value = lines[filter_idx].split("=", 1)[1].strip().strip('"')
    present = set(re.findall(r"\*\.(\w+)", current_value))
    missing = [ext for ext in RAW_DATA_EXTS if ext not in present]

    if not missing:
        _ok(f"include_filter covers all raw data formats: {current_value}")
        return

    msg = (
        f"include_filter is missing {', '.join('*.' + e for e in missing)} "
        f"(current: {current_value!r}). Without these, the export ships no "
        f"{'/'.join(missing)} files and weapons will not fire."
    )
    if not fix:
        raise CheckError(msg + " Re-run without --no-fix to repair it.")

    _warn(msg)
    lines[filter_idx] = f'include_filter="{CANONICAL_INCLUDE_FILTER}"'
    PRESET_FILE.write_text("\n".join(lines) + "\n")
    _note(f'Repaired include_filter -> "{CANONICAL_INCLUDE_FILTER}"')
    if editor_is_running():
        _warn(
            "The Godot editor is open on this project; it may overwrite "
            "export_presets.cfg on save. The export below reads the file fresh, "
            "but commit the repaired preset and/or close the editor to keep it."
        )


def run_export(godot: str) -> None:
    """Re-import resources and export the Web preset into docs/."""
    print(f"Exporting Web preset with {godot}...")
    DOCS_DIR.mkdir(parents=True, exist_ok=True)

    subprocess.run(
        [godot, "--headless", "--path", str(PROJECT_DIR), "--import"],
        check=False,
        capture_output=True,
        text=True,
    )

    result = subprocess.run(
        [
            godot,
            "--headless",
            "--path",
            str(PROJECT_DIR),
            "--export-release",
            PRESET_NAME,
            str(EXPORT_TARGET),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    tail = "\n".join((result.stdout + result.stderr).splitlines()[-15:])
    if result.returncode != 0:
        raise CheckError(f"Godot export failed (exit {result.returncode}):\n{tail}")
    _ok("Godot export completed (exit 0).")


def list_raw_data_files() -> list[Path]:
    files: list[Path] = []
    for ext in RAW_DATA_EXTS:
        files.extend(sorted(DATA_DIR.rglob(f"*.{ext}")))
    return files


def verify_outputs(export_started_at: float | None) -> None:
    """Confirm the required web files exist (and are fresh, if we just exported)."""
    print("Verifying web export outputs (docs/)...")
    for name in REQUIRED_OUTPUTS:
        path = DOCS_DIR / name
        if not path.exists():
            raise CheckError(f"Missing expected output file: {path}")
        if export_started_at is not None and path.stat().st_mtime < export_started_at:
            raise CheckError(
                f"{name} was not rebuilt by the export (stale mtime). "
                "The export likely failed partway."
            )
    _ok(f"All required outputs present: {', '.join(REQUIRED_OUTPUTS)}")


def verify_pck() -> None:
    """Confirm every raw data file on disk is packed into docs/index.pck."""
    print("Verifying packed data (docs/index.pck)...")
    if not PCK_FILE.exists():
        raise CheckError(f"{PCK_FILE} does not exist; run an export first.")
    blob = PCK_FILE.read_bytes()

    data_files = list_raw_data_files()
    if not data_files:
        raise CheckError(f"No raw data files found under {DATA_DIR}.")

    missing: list[str] = []
    per_ext: dict[str, list[int]] = {ext: [0, 0] for ext in RAW_DATA_EXTS}
    for path in data_files:
        rel = path.relative_to(PROJECT_DIR).as_posix()
        ext = path.suffix.lstrip(".")
        per_ext[ext][1] += 1
        if rel.encode("utf-8") in blob:
            per_ext[ext][0] += 1
        else:
            missing.append(rel)

    for ext in RAW_DATA_EXTS:
        packed, total = per_ext[ext]
        line = f"*.{ext}: {packed}/{total} packed"
        (_ok if packed == total else _warn)(line)

    for crit in CRITICAL_DATA_FILES:
        if crit.encode("utf-8") not in blob:
            missing.append(crit)

    if missing:
        sample = "\n    ".join(sorted(set(missing))[:10])
        more = "" if len(set(missing)) <= 10 else f"\n    ... and {len(set(missing)) - 10} more"
        raise CheckError(
            "The following data files are NOT in index.pck (they will be "
            f"missing at runtime):\n    {sample}{more}"
        )
    _ok(f"All {len(data_files)} raw data files are present in index.pck.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify and build the Escort Wing web release.")
    parser.add_argument("--godot", help="Path to the Godot 4 binary.")
    parser.add_argument(
        "--no-export",
        action="store_true",
        help="Skip the export; only verify the existing docs/ build.",
    )
    parser.add_argument(
        "--no-fix",
        action="store_true",
        help="Fail instead of repairing a bad include_filter.",
    )
    args = parser.parse_args()

    print("=== Escort Wing pre-release checks ===\n")
    try:
        check_include_filter(fix=not args.no_fix)
        print()

        export_started_at: float | None = None
        if args.no_export:
            _note("Skipping export (--no-export); verifying existing build.\n")
        else:
            if editor_is_running():
                _warn(
                    "A Godot editor is open on this project. If the export errors, "
                    "close it and retry.\n"
                )
            godot = find_godot(args.godot)
            export_started_at = time.time()
            run_export(godot)
            print()

        verify_outputs(export_started_at)
        print()
        verify_pck()
    except CheckError as exc:
        print(f"\nFAILED: {exc}", file=sys.stderr)
        return 1

    print("\n=== PASS: web release is good to go. ===")
    print("Next: git add docs export_presets.cfg && git commit && git push")
    return 0


if __name__ == "__main__":
    sys.exit(main())
