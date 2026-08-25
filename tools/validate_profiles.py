#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys

from validate_glsl import (
    PACK_ROOT, SHADERS, GLValidator, resolve_includes, check_directives,
    GL_VERTEX_SHADER, GL_FRAGMENT_SHADER,
)

NUMERIC_RE = lambda key: re.compile(rf'(?m)^#define\s+{re.escape(key)}\s+[^\n]+$')
BOOLEAN_RE = lambda key: re.compile(rf'(?m)^(?://)?#define\s+{re.escape(key)}(?:\s.*)?$')

PROFILES = {
    'LOW': {
        'numbers': {'SHADOW_QUALITY':'1','SHADOW_DISTANCE':'96.0','CLOUD_QUALITY':'1','WATER_QUALITY':'1','SSR_QUALITY':'0','BLOOM_STRENGTH':'0.50'},
        'off': {'SSAO_ENABLED','VOLUMETRIC_LIGHTING','TAA_ENABLED','AURORA_ENABLED','BLOCK_EDGE_ACCENT','FILMIC_GRAIN'},
        'on': {'FXAA_ENABLED','BLOOM_ENABLED','RAIN_EFFECTS','WAVING_FOLIAGE','WAVING_WATER','EMISSIVE_ORES'},
    },
    'MEDIUM': {
        'numbers': {'SHADOW_QUALITY':'2','SHADOW_DISTANCE':'128.0','CLOUD_QUALITY':'1','WATER_QUALITY':'2','SSR_QUALITY':'1','BLOOM_STRENGTH':'0.65'},
        'off': {'FILMIC_GRAIN'},
        'on': {'SSAO_ENABLED','VOLUMETRIC_LIGHTING','TAA_ENABLED','FXAA_ENABLED','BLOOM_ENABLED','AURORA_ENABLED','RAIN_EFFECTS','WAVING_FOLIAGE','WAVING_WATER','EMISSIVE_ORES','BLOCK_EDGE_ACCENT'},
    },
    'HIGH': {
        'numbers': {'SHADOW_QUALITY':'2','SHADOW_DISTANCE':'160.0','CLOUD_QUALITY':'2','WATER_QUALITY':'2','SSR_QUALITY':'2','BLOOM_STRENGTH':'0.85'},
        'off': set(),
        'on': {'SSAO_ENABLED','VOLUMETRIC_LIGHTING','TAA_ENABLED','FXAA_ENABLED','BLOOM_ENABLED','AURORA_ENABLED','RAIN_EFFECTS','WAVING_FOLIAGE','WAVING_WATER','EMISSIVE_ORES','BLOCK_EDGE_ACCENT','FILMIC_GRAIN'},
        'feature_defines': {'IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE'},
    },
    'CINEMATIC': {
        'numbers': {'SHADOW_QUALITY':'3','SHADOW_DISTANCE':'224.0','CLOUD_QUALITY':'3','WATER_QUALITY':'3','SSR_QUALITY':'3','BLOOM_STRENGTH':'1.20','MOTION_STABILITY':'0.90'},
        'off': {'FXAA_ENABLED'},
        'on': {'SSAO_ENABLED','VOLUMETRIC_LIGHTING','TAA_ENABLED','BLOOM_ENABLED','AURORA_ENABLED','RAIN_EFFECTS','WAVING_FOLIAGE','WAVING_WATER','EMISSIVE_ORES','BLOCK_EDGE_ACCENT','FILMIC_GRAIN'},
        'feature_defines': {'IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE'},
    },
}

REPRESENTATIVE = {
    'world0': ('gbuffers_terrain','gbuffers_water','deferred','composite','final','shadow'),
    'world-1': ('gbuffers_terrain','gbuffers_water','deferred','composite','final'),
    'world1': ('gbuffers_terrain','gbuffers_water','deferred','composite','final'),
}


def apply_profile(source: str, profile: dict) -> str:
    for key, value in profile['numbers'].items():
        source, count = NUMERIC_RE(key).subn(f'#define {key} {value}', source)
    for key in profile['off']:
        source, count = BOOLEAN_RE(key).subn(f'//#define {key}', source)
    for key in profile['on']:
        source, count = BOOLEAN_RE(key).subn(f'#define {key}', source)
    feature_defines = profile.get('feature_defines', set())
    if feature_defines:
        insertion = ''.join(f'#define {key}\n' for key in sorted(feature_defines))
        source = source.replace('\n', '\n' + insertion, 1)
    return source


def main() -> int:
    validator = GLValidator()
    failures: list[str] = []
    total = 0
    for profile_name, profile in PROFILES.items():
        for dim, programs in REPRESENTATIVE.items():
            for program in programs:
                vsh = SHADERS / dim / f'{program}.vsh'
                fsh = SHADERS / dim / f'{program}.fsh'
                vs = fs = 0
                label = f'{profile_name}:{dim}/{program}'
                try:
                    vsrc = apply_profile(resolve_includes(vsh), profile)
                    fsrc = apply_profile(resolve_includes(fsh), profile)
                    check_directives(vsrc, label+'.vsh')
                    check_directives(fsrc, label+'.fsh')
                    vs = validator.compile(GL_VERTEX_SHADER, vsrc, label+'.vsh')
                    fs = validator.compile(GL_FRAGMENT_SHADER, fsrc, label+'.fsh')
                    validator.link(vs, fs, label)
                    print('PASS', label)
                except Exception as exc:
                    failures.append(str(exc))
                    print('FAIL', label, file=sys.stderr)
                    print(exc, file=sys.stderr)
                finally:
                    if vs: validator.gl.glDeleteShader(vs)
                    if fs: validator.gl.glDeleteShader(fs)
                total += 1
    print(f'OpenGL: {validator.version}')
    print(f'Validated {total} profile-specific linked programs; failures: {len(failures)}')
    if failures:
        (PACK_ROOT/'PROFILE_VALIDATION_ERRORS.txt').write_text('\n\n'.join(failures), encoding='utf-8')
        return 1
    (PACK_ROOT/'PROFILE_VALIDATION_ERRORS.txt').unlink(missing_ok=True)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
