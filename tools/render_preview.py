#!/usr/bin/env python3
"""Render repository GLSL with Mesa/EGL. These are NOT Minecraft screenshots.

The small float-framebuffer harness is also used by pixel regression tests.
Only the sky and an illustrative infinite water plane are shown, without the
Minecraft geometry, cloud pass, shadows or post-processing pipeline.
"""
from __future__ import annotations

import argparse
import ctypes as ct
import math
from pathlib import Path

from validate_glsl import GLValidator, GL_VERTEX_SHADER, GL_FRAGMENT_SHADER, GL_LINK_STATUS, SHADERS, resolve_includes
from validate_profiles import apply_profile

VERTEX = """#version 330 compatibility
void main() {
    vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
"""


class GLProbe:
    """Owns one EGL context and cached programs; context-manager lifetime."""
    def __init__(self) -> None:
        self.validator = GLValidator()
        self.gl = gl = self.validator.gl
        self.programs: dict[str, int] = {}
        self.closed = False
        uint, integer, pointer = ct.c_uint, ct.c_int, ct.c_void_p
        signatures = {
            'glGenFramebuffers': ([integer, ct.POINTER(uint)], None),
            'glBindFramebuffer': ([uint, uint], None),
            'glDeleteFramebuffers': ([integer, ct.POINTER(uint)], None),
            'glCheckFramebufferStatus': ([uint], uint),
            'glFramebufferTexture2D': ([uint, uint, uint, uint, integer], None),
            'glGenTextures': ([integer, ct.POINTER(uint)], None),
            'glBindTexture': ([uint, uint], None),
            'glDeleteTextures': ([integer, ct.POINTER(uint)], None),
            'glTexParameteri': ([uint, uint, integer], None),
            'glTexImage2D': ([uint, integer, integer, integer, integer, integer, uint, uint, pointer], None),
            'glViewport': ([integer] * 4, None),
            'glUseProgram': ([uint], None),
            'glGetUniformLocation': ([uint, ct.c_char_p], integer),
            'glUniform1f': ([integer, ct.c_float], None),
            'glUniform2f': ([integer, ct.c_float, ct.c_float], None),
            'glUniform3f': ([integer, ct.c_float, ct.c_float, ct.c_float], None),
            'glDrawArrays': ([uint, integer, integer], None),
            'glReadPixels': ([integer, integer, integer, integer, uint, uint, pointer], None),
            'glGetError': ([], uint),
        }
        for name, (args, result) in signatures.items():
            function = getattr(gl, name)
            function.argtypes, function.restype = args, result
        self.fbo, self.texture = uint(), uint()
        gl.glGenFramebuffers(1, ct.byref(self.fbo))
        gl.glGenTextures(1, ct.byref(self.texture))

    def program(self, source: str) -> int:
        if source in self.programs:
            return self.programs[source]
        v = self.validator
        vs = fs = program = 0
        try:
            vs = v.compile(GL_VERTEX_SHADER, VERTEX, 'probe vertex')
            fs = v.compile(GL_FRAGMENT_SHADER, source, 'probe fragment')
            program = self.gl.glCreateProgram()
            self.gl.glAttachShader(program, vs)
            self.gl.glAttachShader(program, fs)
            self.gl.glLinkProgram(program)
            ok = ct.c_int()
            self.gl.glGetProgramiv(program, GL_LINK_STATUS, ct.byref(ok))
            if not ok.value:
                raise RuntimeError(v._program_log(program))
            self.programs[source] = program
            return program
        except Exception:
            if program:
                self.gl.glDeleteProgram(program)
            raise
        finally:
            v.delete_shaders(vs, fs)

    def render(self, body: str, *, dimension: str = 'OVERWORLD',
               numbers: dict[str, str] | None = None, width: int = 64,
               height: int = 32, uniforms: dict | None = None):
        if self.closed:
            raise RuntimeError('probe has been closed')
        if dimension not in {'OVERWORLD', 'NETHER', 'END'}:
            raise ValueError('unknown dimension')
        if not (1 <= width <= 4096 and 1 <= height <= 4096):
            raise ValueError('framebuffer dimensions must be in [1, 4096]')
        source = '#version 330 compatibility\n#define DIM_' + dimension + '\n'
        for lib in ('sky.glsl', 'tidal.glsl', 'geometry.glsl'):
            source += resolve_includes(SHADERS / 'lib' / lib)
        source += '''
uniform vec2 uSize;
uniform vec3 uTarget;
uniform float uSunHeight;
out vec4 probeColor;
void main() {
    vec2 uv = gl_FragCoord.xy / uSize;
    vec2 q = uv * 2.0 - 1.0;
    vec3 rd = vec3(cos(q.x * PI) * cos(q.y * PI * 0.5),
                   sin(q.y * PI * 0.5), sin(q.x * PI) * cos(q.y * PI * 0.5));
''' + body + '\n}\n'
        source = apply_profile(source, {'numbers': numbers or {}, 'on': set(), 'off': set()})
        gl, program = self.gl, self.program(source)
        # RGBA32F keeps NaN, negative radiance and HDR values visible to tests.
        gl.glBindTexture(0x0DE1, self.texture)
        gl.glTexParameteri(0x0DE1, 0x2801, 0x2600)
        gl.glTexParameteri(0x0DE1, 0x2800, 0x2600)
        gl.glTexImage2D(0x0DE1, 0, 0x8814, width, height, 0, 0x1908, 0x1406, None)
        gl.glBindFramebuffer(0x8D40, self.fbo)
        gl.glFramebufferTexture2D(0x8D40, 0x8CE0, 0x0DE1, self.texture, 0)
        if gl.glCheckFramebufferStatus(0x8D40) != 0x8CD5:
            raise RuntimeError('incomplete RGBA32F framebuffer')
        gl.glViewport(0, 0, width, height)
        gl.glUseProgram(program)
        values = {'uSize': (float(width), float(height)), 'uTarget': (0.0, 0.3, -1.0),
                  'uSunHeight': -0.3, 'frameTimeCounter': 40.0, 'rainStrength': 0.0}
        values.update(uniforms or {})
        for name, value in values.items():
            location = gl.glGetUniformLocation(program, name.encode())
            components = value if isinstance(value, tuple) else (value,)
            if len(components) not in (1, 2, 3):
                raise ValueError(f'unsupported uniform: {name}')
            getattr(gl, f'glUniform{len(components)}f')(location, *components)
        gl.glDrawArrays(0x0004, 0, 3)
        pixels = (ct.c_float * (width * height * 4))()
        gl.glReadPixels(0, 0, width, height, 0x1908, 0x1406, pixels)
        error = gl.glGetError()
        if error:
            raise RuntimeError(f'OpenGL error 0x{error:04x}')
        return pixels

    def close(self) -> None:
        if self.closed:
            return
        self.closed = True
        gl = self.gl
        gl.glUseProgram(0)
        for program in self.programs.values():
            gl.glDeleteProgram(program)
        gl.glDeleteFramebuffers(1, ct.byref(self.fbo))
        gl.glDeleteTextures(1, ct.byref(self.texture))
        v, egl = self.validator, self.validator.egl
        egl.eglMakeCurrent(v.display, None, None, None)
        for name, handle in (('eglDestroySurface', v.surface), ('eglDestroyContext', v.context)):
            fn = getattr(egl, name)
            fn.argtypes = [ct.c_void_p, ct.c_void_p]
            fn(v.display, handle)
        egl.eglTerminate.argtypes = [ct.c_void_p]
        egl.eglTerminate(v.display)

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


SCENE = '''
    vec3 forward = normalize(uTarget);
    vec3 right = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
    vec3 up = cross(right, forward);
    rd = normalize(forward + right * q.x * (uSize.x / uSize.y) * 0.62 + up * q.y * 0.62);
    vec3 sunDir = normalize(vec3(-0.8, uSunHeight, -0.6));
    vec3 scene = renderDimensionSky(rd, sunDir, -sunDir);
#ifndef DIM_END
    // An illustrative mathematical plane; this is not the game's composite pass.
    if (rd.y < 0.0) {
        float distanceToPlane = -2.8 / rd.y;
        vec3 pos = vec3(0.0, 2.8, 0.0) + rd * distanceToPlane;
        vec3 normal = waterNormalFromWorld(pos.xz, frameTimeCounter);
        vec3 reflection = renderDimensionSky(reflect(rd, normal), sunDir, -sunDir);
        float fresnel = 0.018 + 0.982 * pow5(1.0 - saturate(dot(-rd, normal)));
        scene = mix(vec3(0.002, 0.009, 0.012), reflection, fresnel);
        scene += tidalRadiance(pos, 4.0, 1.0, distanceToPlane,
                               sunDir.y, frameTimeCounter);
    }
#endif
    probeColor = vec4(scene, 1.0);
'''


def save_png(pixels, path: Path, width: int, height: int) -> None:
    from PIL import Image, ImageDraw
    rgb = bytearray(width * height * 3)
    for i in range(width * height):
        for j in range(3):
            value = float(pixels[4 * i + j])
            if not math.isfinite(value) or value < 0:
                raise ValueError('non-finite or negative rendered radiance')
            tone = (value * (2.51 * value + 0.03)) / (value * (2.43 * value + 0.59) + 0.14)
            rgb[3 * i + j] = round(min(1.0, max(0.0, tone)) ** (1 / 2.2) * 255)
    image = Image.frombytes('RGB', (width, height), bytes(rgb)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    draw = ImageDraw.Draw(image)
    label = 'vibe-shader / MERIDIAN    |    OFFLINE GLSL STUDY - NOT A MINECRAFT SCREENSHOT'
    draw.rectangle((0, height - 28, width, height), fill=(10, 12, 16))
    draw.text((14, height - 21), label, fill=(218, 216, 210))
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('dist/previews'))
    parser.add_argument('--width', type=int, default=1280)
    parser.add_argument('--height', type=int, default=720)
    args = parser.parse_args()
    cases = (
        ('meridian-dusk', 'OVERWORLD', (0.0, 0.36, -1.0), -0.035),
        ('meridian-night', 'OVERWORLD', (0.0, 0.14, -1.0), -0.45),
        ('end-observatory', 'END', (0.18, 0.24, -1.0), -0.45),
    )
    with GLProbe() as probe:
        for name, dim, target, sun in cases:
            pixels = probe.render(SCENE, dimension=dim, width=args.width, height=args.height,
                                  uniforms={'uTarget': target, 'uSunHeight': sun})
            path = args.output / (name + '.png')
            save_png(pixels, path, args.width, args.height)
            print(path)


if __name__ == '__main__':
    main()
