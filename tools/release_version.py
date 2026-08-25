#!/usr/bin/env python3
"""Resolve and optionally bump the release version stored in manifest.json."""
from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path

SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


def parse_version(value: str) -> tuple[int, int, int]:
    normalized = value.removeprefix("v")
    match = SEMVER_RE.fullmatch(normalized)
    if match is None:
        raise ValueError(f"expected a stable semantic version like 1.2.3, got {value!r}")
    major, minor, patch = match.groups()
    try:
        return int(major), int(minor), int(patch)
    except ValueError as error:
        raise ValueError(f"invalid numeric version component in {value!r}") from error


def format_version(parts: tuple[int, int, int]) -> str:
    return ".".join(str(part) for part in parts)


def bump_version(current: tuple[int, int, int], bump: str) -> tuple[int, int, int]:
    major, minor, patch = current
    if bump == "major":
        return major + 1, 0, 0
    if bump == "minor":
        return major, minor + 1, 0
    if bump == "patch":
        return major, minor, patch + 1
    return current


def write_github_output(values: dict[str, str]) -> None:
    output_path = os.environ.get("GITHUB_OUTPUT")
    if not output_path:
        return
    with Path(output_path).open("a", encoding="utf-8") as output:
        for key, value in values.items():
            output.write(f"{key}={value}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=Path("manifest.json"))
    parser.add_argument(
        "--bump",
        choices=("none", "patch", "minor", "major"),
        default="none",
    )
    parser.add_argument(
        "--version",
        default="",
        help="Exact stable semantic version; cannot be combined with --bump.",
    )
    args = parser.parse_args()

    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        current_text = str(manifest["version"])
        current = parse_version(current_text)
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
        parser.error(f"cannot read current version from {args.manifest}: {error}")

    exact_text = args.version.strip().removeprefix("v")
    if exact_text and args.bump != "none":
        parser.error("--version and a non-none --bump cannot be used together")

    try:
        target = (
            parse_version(exact_text)
            if exact_text
            else bump_version(current, args.bump)
        )
    except ValueError as error:
        parser.error(str(error))
    if target < current:
        parser.error(
            f"refusing to move version backwards from {current_text} to {format_version(target)}"
        )

    target_text = format_version(target)
    changed = target != current
    if changed:
        manifest["version"] = target_text
        try:
            args.manifest.write_text(
                json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
        except OSError as error:
            parser.error(f"cannot update {args.manifest}: {error}")

    outputs = {
        "version": target_text,
        "tag": f"v{target_text}",
        "changed": str(changed).lower(),
    }
    try:
        write_github_output(outputs)
    except OSError as error:
        parser.error(f"cannot write GitHub Actions output: {error}")
    print(
        f"release version: {target_text} "
        f"({'updated manifest.json' if changed else 'manifest.json unchanged'})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
