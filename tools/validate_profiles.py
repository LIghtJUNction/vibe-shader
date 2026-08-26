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


PROFILES = {
    "LOW": {
        "numbers": {
            "SHADOW_QUALITY": "1",
            "SHADOW_DISTANCE": "96.0",
            "CLOUD_QUALITY": "1",
            "WATER_QUALITY": "1",
            "SSR_QUALITY": "0",
            "VIBE_MODE": "2",
            "VIBE_INTENSITY": "0.75",
            "ATMOSPHERE_DENSITY": "0.55",
            "BLOOM_STRENGTH": "0.40",
            "EDGE_STRENGTH": "0.26",
        },
        "off": {
            "SSAO_ENABLED",
            "VOLUMETRIC_LIGHTING",
            "TAA_ENABLED",
            "AURORA_ENABLED",
            "FILMIC_GRAIN",
        },
        "on": {
            "FXAA_ENABLED",
            "BLOOM_ENABLED",
            "RAIN_EFFECTS",
            "WAVING_FOLIAGE",
            "WAVING_WATER",
            "EMISSIVE_ORES",
            "BLOCK_EDGE_ACCENT",
            "VIBE_PULSE",
        },
    },
    "MEDIUM": {
        "numbers": {
            "SHADOW_QUALITY": "2",
            "SHADOW_DISTANCE": "128.0",
            "CLOUD_QUALITY": "1",
            "WATER_QUALITY": "2",
            "SSR_QUALITY": "1",
            "VIBE_MODE": "2",
            "VIBE_INTENSITY": "0.90",
            "ATMOSPHERE_DENSITY": "0.62",
            "BLOOM_STRENGTH": "0.62",
            "EDGE_STRENGTH": "0.30",
        },
        "off": {"TAA_ENABLED", "FILMIC_GRAIN"},
        "on": {
            "SSAO_ENABLED",
            "VOLUMETRIC_LIGHTING",
            "FXAA_ENABLED",
            "BLOOM_ENABLED",
            "AURORA_ENABLED",
            "RAIN_EFFECTS",
            "WAVING_FOLIAGE",
            "WAVING_WATER",
            "EMISSIVE_ORES",
            "BLOCK_EDGE_ACCENT",
            "VIBE_PULSE",
        },
    },
    "HIGH": {
        "numbers": {
            "SHADOW_QUALITY": "2",
            "SHADOW_DISTANCE": "160.0",
            "CLOUD_QUALITY": "2",
            "WATER_QUALITY": "2",
            "SSR_QUALITY": "2",
            "VIBE_MODE": "2",
            "VIBE_INTENSITY": "0.90",
            "ATMOSPHERE_DENSITY": "0.68",
            "BLOOM_STRENGTH": "0.78",
            "EDGE_STRENGTH": "0.34",
        },
        "off": {"TAA_ENABLED"},
        "on": {
            "SSAO_ENABLED",
            "VOLUMETRIC_LIGHTING",
            "FXAA_ENABLED",
            "BLOOM_ENABLED",
            "AURORA_ENABLED",
            "RAIN_EFFECTS",
            "WAVING_FOLIAGE",
            "WAVING_WATER",
            "EMISSIVE_ORES",
            "BLOCK_EDGE_ACCENT",
            "VIBE_PULSE",
            "FILMIC_GRAIN",
        },
        "feature_defines": {"IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE"},
    },
    "CINEMATIC": {
        "numbers": {
            "SHADOW_QUALITY": "3",
            "SHADOW_DISTANCE": "224.0",
            "CLOUD_QUALITY": "3",
            "WATER_QUALITY": "3",
            "SSR_QUALITY": "3",
            "VIBE_MODE": "2",
            "VIBE_INTENSITY": "1.10",
            "ATMOSPHERE_DENSITY": "0.72",
            "BLOOM_STRENGTH": "1.00",
            "EDGE_STRENGTH": "0.40",
            "MOTION_STABILITY": "0.62",
        },
        "off": {"FXAA_ENABLED"},
        "on": {
            "SSAO_ENABLED",
            "VOLUMETRIC_LIGHTING",
            "TAA_ENABLED",
            "BLOOM_ENABLED",
            "AURORA_ENABLED",
            "RAIN_EFFECTS",
            "WAVING_FOLIAGE",
            "WAVING_WATER",
            "EMISSIVE_ORES",
            "BLOCK_EDGE_ACCENT",
            "VIBE_PULSE",
            "FILMIC_GRAIN",
        },
        "feature_defines": {"IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE"},
    },
}

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
    validator = GLValidator()
    failures: list[str] = []
    total = 0
    for profile_name, profile in PROFILES.items():
        for dim, programs in REPRESENTATIVE.items():
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
                    if vs:
                        validator.gl.glDeleteShader(vs)
                    if fs:
                        validator.gl.glDeleteShader(fs)
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
