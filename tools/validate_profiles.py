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
            "ATMOSPHERE_DENSITY": "0.68",
            "BLOOM_STRENGTH": "0.25",
            "TERRAIN_COHESION_STRENGTH": "0.50",
            "MATERIAL_DETAIL_STRENGTH": "0.30",
            "VOXEL_ROUNDNESS": "0.20",
            "VISION_FOCUS_DISTANCE": "80.0",
            "DISTANT_BLUR_STRENGTH": "0.32",
            "ASTIGMATISM_STRENGTH": "0.12",
            "SURVIVAL_EFFECT_STRENGTH": "0.62",
        },
        "off": {
            "SSAO_ENABLED",
            "VOLUMETRIC_LIGHTING",
            "TAA_ENABLED",
            "AURORA_ENABLED",
            "EMISSIVE_ORES",
            "MATERIAL_DETAIL",
            "ROUNDED_VOXEL_LIGHTING",
        },
        "on": {
            "FXAA_ENABLED",
            "BLOOM_ENABLED",
            "RAIN_EFFECTS",
            "WAVING_FOLIAGE",
            "WAVING_WATER",
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
            "ATMOSPHERE_DENSITY": "0.68",
            "BLOOM_STRENGTH": "0.40",
            "TERRAIN_COHESION_STRENGTH": "0.65",
            "MATERIAL_DETAIL_STRENGTH": "0.45",
            "VOXEL_ROUNDNESS": "0.30",
            "VISION_FOCUS_DISTANCE": "72.0",
            "DISTANT_BLUR_STRENGTH": "0.42",
            "ASTIGMATISM_STRENGTH": "0.17",
            "SURVIVAL_EFFECT_STRENGTH": "0.68",
        },
        "off": {"TAA_ENABLED", "EMISSIVE_ORES"},
        "on": {
            "SSAO_ENABLED",
            "VOLUMETRIC_LIGHTING",
            "FXAA_ENABLED",
            "BLOOM_ENABLED",
            "AURORA_ENABLED",
            "RAIN_EFFECTS",
            "WAVING_FOLIAGE",
            "WAVING_WATER",
            "MATERIAL_DETAIL",
            "ROUNDED_VOXEL_LIGHTING",
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
            "VIBE_INTENSITY": "1.10",
            "ATMOSPHERE_DENSITY": "0.82",
            "BLOOM_STRENGTH": "0.40",
            "TERRAIN_COHESION_STRENGTH": "0.78",
            "MATERIAL_DETAIL_STRENGTH": "0.70",
            "VOXEL_ROUNDNESS": "0.40",
            "VISION_FOCUS_DISTANCE": "64.0",
            "DISTANT_BLUR_STRENGTH": "0.52",
            "ASTIGMATISM_STRENGTH": "0.22",
            "SURVIVAL_EFFECT_STRENGTH": "0.72",
        },
        "off": {"TAA_ENABLED", "EMISSIVE_ORES"},
        "on": {
            "SSAO_ENABLED",
            "VOLUMETRIC_LIGHTING",
            "FXAA_ENABLED",
            "BLOOM_ENABLED",
            "AURORA_ENABLED",
            "RAIN_EFFECTS",
            "WAVING_FOLIAGE",
            "WAVING_WATER",
            "MATERIAL_DETAIL",
            "ROUNDED_VOXEL_LIGHTING",
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
            "VIBE_INTENSITY": "1.30",
            "ATMOSPHERE_DENSITY": "1.00",
            "BLOOM_STRENGTH": "0.55",
            "TERRAIN_COHESION_STRENGTH": "0.90",
            "MATERIAL_DETAIL_STRENGTH": "0.85",
            "VOXEL_ROUNDNESS": "0.55",
            "VISION_FOCUS_DISTANCE": "56.0",
            "DISTANT_BLUR_STRENGTH": "0.62",
            "ASTIGMATISM_STRENGTH": "0.28",
            "SURVIVAL_EFFECT_STRENGTH": "0.78",
            "MOTION_STABILITY": "0.62",
        },
        "off": {"FXAA_ENABLED", "EMISSIVE_ORES"},
        "on": {
            "SSAO_ENABLED",
            "VOLUMETRIC_LIGHTING",
            "TAA_ENABLED",
            "BLOOM_ENABLED",
            "AURORA_ENABLED",
            "RAIN_EFFECTS",
            "WAVING_FOLIAGE",
            "WAVING_WATER",
            "MATERIAL_DETAIL",
            "ROUNDED_VOXEL_LIGHTING",
        },
        "feature_defines": {"IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE"},
    },
}

for profile in PROFILES.values():
    profile["on"].update(
        {
            "DISTANT_BLUR",
            "OCULAR_ASTIGMATISM",
            "SURVIVAL_VISION",
            "NATURAL_TERRAIN_COHESION",
        }
    )

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


def profile_contract_errors() -> list[str]:
    properties = (SHADERS / "shaders.properties").read_text(encoding="utf-8")
    errors: list[str] = []
    for name, profile in PROFILES.items():
        match = re.search(rf"(?m)^profile\.{name}\s*=\s*(.+)$", properties)
        if match is None:
            errors.append(f"missing profile.{name} in shaders.properties")
            continue
        tokens = match.group(1).split()
        numbers = {
            key: value
            for token in tokens
            if "=" in token
            for key, value in (token.split("=", 1),)
        }
        enabled = {
            token for token in tokens if "=" not in token and not token.startswith("!")
        }
        disabled = {token[1:] for token in tokens if token.startswith("!")}
        for key, expected in profile["numbers"].items():
            if numbers.get(key) != expected:
                errors.append(
                    f"profile.{name} {key}: expected {expected}, got {numbers.get(key)!r}"
                )
        for key in profile["on"]:
            if key not in enabled:
                errors.append(f"profile.{name} must enable {key}")
        for key in profile["off"]:
            if key not in disabled:
                errors.append(f"profile.{name} must disable {key}")
    return errors


def main() -> int:
    contract_errors = profile_contract_errors()
    if contract_errors:
        for error in contract_errors:
            print(f"FAIL profile contract: {error}", file=sys.stderr)
        return 1
    print("PASS shaders.properties profile contract")

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
