#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from PIL import Image
from release_version import SEMVER_RE

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"
INCLUDE_RE = re.compile(r'^\s*#include\s+["<]([^">]+)[">]\s*$', re.M)

errors: list[str] = []
notes: list[str] = []


def fail(msg: str) -> None:
    errors.append(msg)


def resolve(path: Path, stack: tuple[Path, ...] = ()) -> None:
    if path in stack:
        fail(
            "include cycle: "
            + " -> ".join(str(p.relative_to(ROOT)) for p in (*stack, path))
        )
        return
    try:
        text = path.read_text(encoding="utf-8")
    except Exception as exc:
        fail(f"cannot read {path.relative_to(ROOT)}: {exc}")
        return
    for inc in INCLUDE_RE.findall(text):
        target = SHADERS / inc.lstrip("/")
        if not target.is_file():
            fail(f"{path.relative_to(ROOT)} includes missing {inc}")
        else:
            resolve(target, (*stack, path))


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
        resolve(p)

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
if "flip.composite.colortex3 = true" not in props:
    fail("composite must flip colortex3 from accumulator to bloom output")
layer_blend = (
    "blend.gbuffers_water.colortex3 = "
    "SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA"
)
if layer_blend not in props:
    fail("water layer accumulator must use straight-alpha compositing")
if "outWaterColor" in water_program or "RENDERTARGETS: 0,4" in water_program:
    fail("legacy double-blended water path is still present")
notes.append("water path: nearest metadata 4/7 + layered accumulator 3")

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
