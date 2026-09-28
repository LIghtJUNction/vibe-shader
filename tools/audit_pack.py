#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys

from PIL import Image
from release_version import SEMVER_RE
from validate_glsl import PACK_ROOT as ROOT, SHADERS, resolve_includes

errors: list[str] = []
notes: list[str] = []


def fail(msg: str) -> None:
    errors.append(msg)


required = [
    ROOT / "README.md",
    ROOT / "LICENSE",
    ROOT / "manifest.json",
    ROOT / "pack.png",
    ROOT / "VALIDATION.md",
    SHADERS / "shaders.properties",
    SHADERS / "block.properties",
    SHADERS / "dimension.properties",
    SHADERS / "lang/en_us.lang",
    SHADERS / "lang/zh_cn.lang",
]
for p in required:
    if not p.is_file():
        fail(f"missing required file: {p.relative_to(ROOT)}")

try:
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    version = str(manifest.get("version", ""))
    if SEMVER_RE.fullmatch(version) is None:
        fail(f"invalid semantic version: {version!r}")
    if manifest.get("name") != "vibe-shader":
        fail("unexpected manifest name")
except Exception as exc:
    fail(f"invalid manifest.json: {exc}")

try:
    with Image.open(ROOT / "pack.png") as im:
        if im.size != (256, 256):
            fail(f"pack.png must be 256x256, got {im.size}")
        notes.append(f"pack.png: {im.size[0]}x{im.size[1]} {im.mode}")
except Exception as exc:
    fail(f"invalid pack.png: {exc}")

all_shader_text = ""
wrapper_pairs = 0
for dim in ("world0", "world-1", "world1"):
    folder = SHADERS / dim
    if not folder.is_dir():
        fail(f"missing {dim}")
        continue
    vertices = sorted(folder.glob("*.vsh"))
    fragments = sorted(folder.glob("*.fsh"))
    vnames = {p.stem for p in vertices}
    fnames = {p.stem for p in fragments}
    for name in sorted(vnames - fnames):
        fail(f"{dim}/{name}.vsh has no fragment pair")
    for name in sorted(fnames - vnames):
        fail(f"{dim}/{name}.fsh has no vertex pair")
    wrapper_pairs += len(vnames & fnames)
    for p in (*vertices, *fragments):
        text = p.read_text(encoding="utf-8")
        all_shader_text += "\n" + text
        if not text.startswith("#version 330 compatibility\n"):
            fail(f"{p.relative_to(ROOT)} lacks first-line #version 330 compatibility")
        try:
            resolve_includes(p)
        except Exception as exc:
            fail(str(exc))

if wrapper_pairs != 90:
    fail(f"expected 90 wrapper pairs, got {wrapper_pairs}")
notes.append(f"linked wrapper pairs: {wrapper_pairs}")

for token in ("iquilez", "voxellines", "shadertoy.com"):
    if token in all_shader_text.lower():
        fail(f"forbidden borrowed-source marker present: {token}")

# Iris rewrites direct gl_Vertex references, but ftransform() can leave an internal
# compatibility gl_Vertex active alongside iris_Position on stricter drivers.
program_vertex_text = "\n".join(
    p.read_text(encoding="utf-8") for p in (SHADERS / "program").glob("*.vsh.glsl")
)
if re.search(r"\bftransform\s*\(", program_vertex_text):
    fail(
        "ftransform() present in a vertex program; may collide with Iris iris_Position"
    )
notes.append("Iris attribute collision guard: no ftransform()")

# Voxel outlines and their travelling pulse were intentionally removed after
# runtime review. Keep the shader path and UI free of stale toggles.
shader_config_text = "\n".join(
    p.read_text(encoding="utf-8")
    for p in SHADERS.rglob("*")
    if p.is_file() and p.suffix in {".glsl", ".fsh", ".vsh", ".properties", ".lang"}
)
for token in (
    "BLOCK_EDGE_ACCENT",
    "EDGE_STRENGTH",
    "VIBE_PULSE",
    "PULSE_STRENGTH",
    "blockEdgeMask",
    "vibeSignal",
):
    if token in shader_config_text:
        fail(f"removed voxel-outline path is still present: {token}")
notes.append("voxel outlines and code pulse removed")

# Check option localization coverage.
settings = (SHADERS / "lib/settings.glsl").read_text(encoding="utf-8")
macros = set(re.findall(r"^#define\s+([A-Z][A-Z0-9_]+)", settings, re.M))
props = (SHADERS / "shaders.properties").read_text(encoding="utf-8")
ui_tokens = set()
for line in props.splitlines():
    if line.startswith(("screen.", "sliders")):
        ui_tokens.update(re.findall(r"\b[A-Z][A-Z0-9_]+\b", line))
ui_tokens &= macros
for lang_name in ("en_us.lang", "zh_cn.lang"):
    lang = (SHADERS / "lang" / lang_name).read_text(encoding="utf-8")
    keys = set(re.findall(r"^option\.([A-Z][A-Z0-9_]*)=", lang, re.M))
    missing = sorted(ui_tokens - keys)
    if missing:
        fail(f"{lang_name} missing option labels: {missing}")
notes.append(f"localized options checked: {len(ui_tokens)}")

# Human-vision effects must remain depth based and driven by Iris's verified
# player-status uniforms. Camera-style film grain is intentionally excluded.
vision_text = (SHADERS / "lib/vision.glsl").read_text(encoding="utf-8")
final_text = (SHADERS / "program/final.fsh.glsl").read_text(encoding="utf-8")
for token in (
    "applyDepthAwareVisionBlur",
    "ocularAstigmatism",
    "applyAdaptiveVisionMood",
    "physiologicalVignette",
):
    if token not in vision_text:
        fail(f"human-vision pipeline is missing: {token}")
for uniform in (
    "currentPlayerHealth",
    "currentPlayerHunger",
    "nightVision",
    "blindness",
    "darknessFactor",
    "is_hurt",
):
    if uniform not in final_text:
        fail(f"final pass is missing Iris player-status uniform: {uniform}")
if "FILMIC_GRAIN" in shader_config_text:
    fail("camera-style film grain must not replace physiological low-light noise")
if (
    "VISION_BLUR_KERNEL[4]" not in vision_text
    or "for (int i = 0; i < 4; ++i)" not in vision_text
):
    fail("optimized human-vision blur must remain a four-tap kernel")
terrain_text = (SHADERS / "program/gbuffers_terrain.fsh.glsl").read_text(
    encoding="utf-8"
)
for token in (
    "NATURAL_TERRAIN_COHESION",
    "cohesiveTerrainColor",
    "MATERIAL_DETAIL",
    "detailedSurfaceNormal",
    "textureGrad",
):
    if token not in terrain_text:
        fail(f"natural terrain cohesion path is missing: {token}")
cloud_text = (SHADERS / "lib/clouds.glsl").read_text(encoding="utf-8")
for token in ("#define CLOUD_STEPS 12", "fastCloudFbm", "coarseCloudDensity"):
    if token not in cloud_text:
        fail(f"optimized volumetric-cloud path is missing: {token}")
if "fbm3(" in cloud_text:
    fail("volumetric cloud march must not call four-octave fbm3 per step")
composite_text = (SHADERS / "program/composite/base.glsl").read_text(encoding="utf-8")
if "#define VOLUME_STEPS 6" not in composite_text:
    fail("High volumetric-light integration must remain at six steps")
sky_text = resolve_includes(SHADERS / "lib/sky.glsl")
if "atan(" in sky_text:
    fail("sky effects must not use discontinuous azimuth longitude")
lighting_text = (SHADERS / "program/deferred/lighting.glsl").read_text(encoding="utf-8")
composite_main = (SHADERS / "program/composite/main.glsl").read_text(encoding="utf-8")
if "specularScale" not in lighting_text or "vec3(1.05)" not in composite_main:
    fail("diffuse-first matte lighting or HDR-only bloom gate is missing")
deferred_base = (SHADERS / "program/deferred/base.glsl").read_text(
    encoding="utf-8"
)
if "roundedVoxelNormal" not in deferred_base or "VOXEL_ROUNDNESS" not in props:
    fail("edge-gated rounded voxel lighting is missing")
if "applyPerceptualLocalContrast" not in final_text:
    fail("perceptual local contrast for HDR separation is missing")
if re.search(r"(?m)^#define\s+EMISSIVE_ORES\b", settings):
    fail("emissive ores must remain opt-in for natural matte materials")
notes.append("seamless sky, matte materials, rounded lighting, and HDR separation present")

# Check material block IDs do not collide.
block_text = (SHADERS / "block.properties").read_text(encoding="utf-8")
ids = re.findall(r"^block\.(-?\d+)\s*=", block_text, re.M)
if len(ids) != len(set(ids)):
    fail("duplicate block IDs in block.properties")
notes.append(f"material block groups: {len(ids)}")

# Water keeps the nearest metadata separate while preserving farther layers.
water_program = (SHADERS / "program/gbuffers_water.fsh.glsl").read_text(
    encoding="utf-8"
)
if "/* RENDERTARGETS: 4,7,3 */" not in water_program:
    fail("water program must target nearest metadata 4/7 and layer accumulator 3")
if "outLayerComposite" not in water_program:
    fail("water program is missing the layered translucency output")
if "const bool colortex3Clear = true;" not in water_program:
    fail("water layer accumulator must clear at frame start")
clear_color = re.search(
    r"const\s+vec4\s+colortex3ClearColor\s*=\s*vec4\s*\(([^)]*)\)",
    water_program,
)
if clear_color is None or len(clear_color.group(1).split(",")) != 4:
    fail("colortex3ClearColor must use four scalar components for Iris")
if "flip.composite.colortex3 = true" not in props:
    fail("composite must flip colortex3 from accumulator to bloom output")
layer_blend = (
    "blend.gbuffers_water.colortex3 = "
    "SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA"
)
if layer_blend not in props:
    fail("water layer accumulator must use straight-alpha compositing")
if not re.search(
    r"#ifdef\s+IRIS_FEATURE_PER_BUFFER_BLENDING[\s\S]*"
    r"blend\.gbuffers_water\.colortex3[\s\S]*#else[\s\S]*"
    r"blend\.gbuffers_water\s*=\s*off[\s\S]*#endif",
    props,
):
    fail("per-buffer blend directives must have an Iris feature fallback")
if "outWaterColor" in water_program or "RENDERTARGETS: 0,4" in water_program:
    fail("legacy double-blended water path is still present")
geometry_text = (SHADERS / "lib/geometry.glsl").read_text(encoding="utf-8")
water_shading = (SHADERS / "program/composite/water.glsl").read_text(encoding="utf-8")
if "worldPos.y += waterHeight" in geometry_text:
    fail("water geometry displacement creates visible planar facets")
for token in (
    "absorptionScale",
    "horizontalWater",
    "min(thickness, 0.34)",
    "clamp(tintData.a, 0.0, 1.0)",
):
    if token not in water_shading:
        fail(f"natural water response is missing: {token}")
notes.append("layered water uses flat geometry, absorption, and restrained SSR")

for errname in ("VALIDATION_ERRORS.txt", "PROFILE_VALIDATION_ERRORS.txt"):
    if (ROOT / errname).exists():
        fail(f"failure artifact exists: {errname}")

print("vibe-shader pack audit")
for note in notes:
    print("PASS", note)
print(f"Files: {sum(1 for p in ROOT.rglob('*') if p.is_file())}")
print(f"Failures: {len(errors)}")
if errors:
    for e in errors:
        print("FAIL", e, file=sys.stderr)
    sys.exit(1)
sys.exit(0)
