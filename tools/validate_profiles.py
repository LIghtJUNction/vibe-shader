#!/usr/bin/env python3
from __future__ import annotations

import re
import sys

from validate_glsl import (
    GL_FRAGMENT_SHADER,
    GL_VERTEX_SHADER,
    PACK_ROOT,
    SHADERS,
    GLValidator,
    check_directives,
    resolve_includes,
)


def numeric_re(key: str) -> re.Pattern[str]:
    return re.compile(rf"(?m)^#define\s+{re.escape(key)}\s+[^\n]+$")


def boolean_re(key: str) -> re.Pattern[str]:
    return re.compile(rf"(?m)^(?://)?#define\s+{re.escape(key)}(?:\s.*)?$")


def parse_settings(text: str) -> dict[str, set[str] | None]:
    """Return numeric option domains and boolean options; reject invalid defaults."""
    options = {}
    pattern = re.compile(r"^(?://)?#define\s+(\w+)(?:\s+([^/\s]+))?(?:\s*//\s*\[([^]]+)\])?\s*$")
    for line in text.splitlines():
        match = pattern.match(line.strip())
        if not match:
            continue
        key, default, domain = match.groups()
        if key.startswith("VIBE_SHADER_"):
            continue
        values = set(domain.split()) if domain else None
        if default is not None and (values is None or default not in values):
            raise ValueError(f"{key}: default {default!r} outside declared domain")
        if key in options:
            raise ValueError(f"duplicate setting {key}")
        options[key] = values
    return options


def parse_profiles(properties: str, settings: str) -> dict[str, dict]:
    """Compile precisely the options in the shipped UI, not a second hand copy."""
    options = parse_settings(settings)
    profiles = {}
    for name, body in re.findall(r"(?m)^profile\.(\w+)\s*=\s*(.+)$", properties):
        if name in profiles:
            raise ValueError(f"duplicate profile {name}")
        profile = {"numbers": {}, "on": set(), "off": set()}
        seen = set()
        for token in body.split():
            key = token.split("=", 1)[0].lstrip("!")
            if key not in options or key in seen:
                raise ValueError(f"{name}: unknown or duplicate option {key}")
            seen.add(key)
            if "=" in token:
                value = token.split("=", 1)[1]
                if options[key] is None or value not in options[key] or token.startswith("!"):
                    raise ValueError(f"{name}: invalid value {token}")
                profile["numbers"][key] = value
            else:
                if options[key] is not None:
                    raise ValueError(f"{name}: numeric option {key} needs a value")
                profile["off" if token.startswith("!") else "on"].add(key)
        profiles[name] = profile
    if not profiles:
        raise ValueError("no quality profiles found")
    return profiles


PROFILES = parse_profiles(
    (SHADERS / "shaders.properties").read_text(encoding="utf-8"),
    (SHADERS / "lib/settings.glsl").read_text(encoding="utf-8"),
)
# Exercise the native emission attribute and its compatibility fallback.
for name in ("HIGH", "CINEMATIC"):
    if name in PROFILES:
        PROFILES[name]["feature_defines"] = {"IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE"}

REPRESENTATIVE = {
    "world0": (
        "gbuffers_terrain",
        "gbuffers_water",
        "deferred",
        "composite",
        "final",
        "shadow",
    ),
    "world-1": ("gbuffers_terrain", "gbuffers_water", "deferred", "composite", "final"),
    "world1": ("gbuffers_terrain", "gbuffers_water", "deferred", "composite", "final"),
}


def apply_profile(source: str, profile: dict) -> str:
    for key, value in profile["numbers"].items():
        source = numeric_re(key).sub(f"#define {key} {value}", source)
    for key in profile["off"]:
        source = boolean_re(key).sub(f"//#define {key}", source)
    for key in profile["on"]:
        source = boolean_re(key).sub(f"#define {key}", source)
    feature_defines = profile.get("feature_defines", set())
    if feature_defines:
        insertion = "".join(f"#define {key}\n" for key in sorted(feature_defines))
        source = source.replace("\n", "\n" + insertion, 1)
    return source


def main() -> int:
    if set(PROFILES) != {"LOW", "MEDIUM", "HIGH", "CINEMATIC"}:
        raise ValueError("expected LOW, MEDIUM, HIGH and CINEMATIC profiles")
    print("PASS shaders.properties profile contract")

    validator = GLValidator()
    failures: list[str] = []
    total = 0
    cases = [(name, profile, REPRESENTATIVE) for name, profile in PROFILES.items()]
    post_programs = {dim: ("deferred", "composite", "final") for dim in REPRESENTATIVE}
    variants = {
        "OFF": {"CELESTIAL_QUALITY": "0", "TIDAL_GLOW": "0.00", "WATER_QUALITY": "0"},
        "STILL": {"PHENOMENA_SPEED": "0.00"},
        **{f"LEGACY_{mode}": {"VIBE_MODE": str(mode)} for mode in range(4)},
    }
    for name, numbers in variants.items():
        profile = {**PROFILES["HIGH"], "numbers": {**PROFILES["HIGH"]["numbers"], **numbers}}
        cases.append((name, profile, post_programs))
    for profile_name, profile, representatives in cases:
        for dim, programs in representatives.items():
            for program in programs:
                vsh = SHADERS / dim / f"{program}.vsh"
                fsh = SHADERS / dim / f"{program}.fsh"
                vs = fs = 0
                label = f"{profile_name}:{dim}/{program}"
                try:
                    vsrc = apply_profile(resolve_includes(vsh), profile)
                    fsrc = apply_profile(resolve_includes(fsh), profile)
                    check_directives(vsrc, label + ".vsh")
                    check_directives(fsrc, label + ".fsh")
                    vs = validator.compile(GL_VERTEX_SHADER, vsrc, label + ".vsh")
                    fs = validator.compile(GL_FRAGMENT_SHADER, fsrc, label + ".fsh")
                    validator.link(vs, fs, label)
                    print("PASS", label)
                except Exception as exc:
                    failures.append(str(exc))
                    print("FAIL", label, file=sys.stderr)
                    print(exc, file=sys.stderr)
                finally:
                    validator.delete_shaders(vs, fs)
                total += 1
    print(f"OpenGL: {validator.version}")
    print(
        f"Validated {total} profile-specific linked programs; failures: {len(failures)}"
    )
    if failures:
        (PACK_ROOT / "PROFILE_VALIDATION_ERRORS.txt").write_text(
            "\n\n".join(failures), encoding="utf-8"
        )
        return 1
    (PACK_ROOT / "PROFILE_VALIDATION_ERRORS.txt").unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
