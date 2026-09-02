#!/usr/bin/env python3
"""Offline structural and desktop OpenGL validation for vibe-shader."""

from __future__ import annotations

import ctypes
import re
import sys
from ctypes import (
    POINTER,
    byref,
    c_char_p,
    c_int,
    c_uint,
    c_void_p,
    create_string_buffer,
)
from pathlib import Path

PACK_ROOT = Path(__file__).resolve().parents[1]
SHADERS = PACK_ROOT / "shaders"
INCLUDE_RE = re.compile(r'^\s*#include\s+["<]([^">]+)[">]\s*$', re.M)


def resolve_includes(path: Path, stack: tuple[Path, ...] = ()) -> str:
    path = path.resolve()
    if path in stack:
        chain = " -> ".join(str(p.relative_to(PACK_ROOT)) for p in (*stack, path))
        raise RuntimeError(f"include cycle: {chain}")
    text = path.read_text(encoding="utf-8")

    def repl(match: re.Match[str]) -> str:
        include = match.group(1)
        target = SHADERS / include.lstrip("/")
        if not target.is_file():
            raise FileNotFoundError(
                f"{path.relative_to(PACK_ROOT)} includes missing {include}"
            )
        body = resolve_includes(target, (*stack, path))
        return f"\n// BEGIN INCLUDE {include}\n{body}\n// END INCLUDE {include}\n"

    return INCLUDE_RE.sub(repl, text)


def check_directives(source: str, label: str) -> None:
    stack: list[tuple[str, int]] = []
    for n, line in enumerate(source.splitlines(), 1):
        directive = line.strip().split(maxsplit=1)[0] if line.strip() else ""
        if directive in {"#if", "#ifdef", "#ifndef"}:
            stack.append((directive, n))
        elif directive == "#endif":
            if not stack:
                raise RuntimeError(f"{label}:{n}: unmatched #endif")
            stack.pop()
    if stack:
        raise RuntimeError(f"{label}: unclosed directives {stack[-4:]}")


# EGL constants
EGL_NONE = 0x3038
EGL_SURFACE_TYPE = 0x3033
EGL_PBUFFER_BIT = 0x0001
EGL_RENDERABLE_TYPE = 0x3040
EGL_OPENGL_BIT = 0x0008
EGL_RED_SIZE = 0x3024
EGL_GREEN_SIZE = 0x3023
EGL_BLUE_SIZE = 0x3022
EGL_ALPHA_SIZE = 0x3021
EGL_WIDTH = 0x3057
EGL_HEIGHT = 0x3056
EGL_OPENGL_API = 0x30A2
EGL_CONTEXT_MAJOR_VERSION = 0x3098
EGL_CONTEXT_MINOR_VERSION = 0x30FB
EGL_CONTEXT_OPENGL_PROFILE_MASK = 0x30FD
EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT = 0x00000002
EGL_PLATFORM_SURFACELESS_MESA = 0x31DD
EGL_DEFAULT_DISPLAY = c_void_p(0)

# GL constants
GL_VERSION = 0x1F02
GL_VERTEX_SHADER = 0x8B31
GL_FRAGMENT_SHADER = 0x8B30
GL_COMPILE_STATUS = 0x8B81
GL_LINK_STATUS = 0x8B82
GL_INFO_LOG_LENGTH = 0x8B84


class GLValidator:
    def __init__(self) -> None:
        self.egl = ctypes.CDLL("libEGL.so.1")
        self.gl = ctypes.CDLL("libGL.so.1")
        self.display = c_void_p()
        self.surface = c_void_p()
        self.context = c_void_p()
        self._setup_egl()
        self._setup_gl()

    def _setup_egl(self) -> None:
        egl = self.egl
        egl.eglGetProcAddress.argtypes = [c_char_p]
        egl.eglGetProcAddress.restype = c_void_p

        # Prefer a truly headless surfaceless platform.
        get_platform_ptr = egl.eglGetProcAddress(b"eglGetPlatformDisplayEXT")
        if get_platform_ptr:
            get_platform = ctypes.CFUNCTYPE(c_void_p, c_uint, c_void_p, POINTER(c_int))(
                get_platform_ptr
            )
            self.display = c_void_p(
                get_platform(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, None)
            )
        else:
            egl.eglGetDisplay.argtypes = [c_void_p]
            egl.eglGetDisplay.restype = c_void_p
            self.display = c_void_p(egl.eglGetDisplay(EGL_DEFAULT_DISPLAY))
        if not self.display.value:
            raise RuntimeError("eglGetDisplay failed")

        egl.eglInitialize.argtypes = [c_void_p, POINTER(c_int), POINTER(c_int)]
        egl.eglInitialize.restype = c_uint
        major, minor = c_int(), c_int()
        if not egl.eglInitialize(self.display, byref(major), byref(minor)):
            raise RuntimeError("eglInitialize failed")

        egl.eglBindAPI.argtypes = [c_uint]
        egl.eglBindAPI.restype = c_uint
        if not egl.eglBindAPI(EGL_OPENGL_API):
            raise RuntimeError("eglBindAPI(EGL_OPENGL_API) failed")

        attrs = (c_int * 15)(
            EGL_SURFACE_TYPE,
            EGL_PBUFFER_BIT,
            EGL_RENDERABLE_TYPE,
            EGL_OPENGL_BIT,
            EGL_RED_SIZE,
            8,
            EGL_GREEN_SIZE,
            8,
            EGL_BLUE_SIZE,
            8,
            EGL_ALPHA_SIZE,
            8,
            EGL_NONE,
            0,
            0,
        )
        # EGL terminates at EGL_NONE, the trailing entries are harmless.
        config = c_void_p()
        count = c_int()
        egl.eglChooseConfig.argtypes = [
            c_void_p,
            POINTER(c_int),
            POINTER(c_void_p),
            c_int,
            POINTER(c_int),
        ]
        egl.eglChooseConfig.restype = c_uint
        if (
            not egl.eglChooseConfig(self.display, attrs, byref(config), 1, byref(count))
            or count.value < 1
        ):
            raise RuntimeError("eglChooseConfig failed")

        pbuffer_attrs = (c_int * 5)(EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE)
        egl.eglCreatePbufferSurface.argtypes = [c_void_p, c_void_p, POINTER(c_int)]
        egl.eglCreatePbufferSurface.restype = c_void_p
        self.surface = c_void_p(
            egl.eglCreatePbufferSurface(self.display, config, pbuffer_attrs)
        )
        if not self.surface.value:
            raise RuntimeError("eglCreatePbufferSurface failed")

        context_attrs = (c_int * 7)(
            EGL_CONTEXT_MAJOR_VERSION,
            3,
            EGL_CONTEXT_MINOR_VERSION,
            3,
            EGL_CONTEXT_OPENGL_PROFILE_MASK,
            EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT,
            EGL_NONE,
        )
        egl.eglCreateContext.argtypes = [c_void_p, c_void_p, c_void_p, POINTER(c_int)]
        egl.eglCreateContext.restype = c_void_p
        self.context = c_void_p(
            egl.eglCreateContext(self.display, config, c_void_p(0), context_attrs)
        )
        if not self.context.value:
            # Some implementations reject explicit profile attributes; request a default OpenGL context.
            fallback = (c_int * 1)(EGL_NONE)
            self.context = c_void_p(
                egl.eglCreateContext(self.display, config, c_void_p(0), fallback)
            )
        if not self.context.value:
            raise RuntimeError("eglCreateContext failed")

        egl.eglMakeCurrent.argtypes = [c_void_p, c_void_p, c_void_p, c_void_p]
        egl.eglMakeCurrent.restype = c_uint
        if not egl.eglMakeCurrent(
            self.display, self.surface, self.surface, self.context
        ):
            raise RuntimeError("eglMakeCurrent failed")

    def _setup_gl(self) -> None:
        gl = self.gl
        gl.glGetString.argtypes = [c_uint]
        gl.glGetString.restype = c_char_p
        gl.glCreateShader.argtypes = [c_uint]
        gl.glCreateShader.restype = c_uint
        gl.glShaderSource.argtypes = [c_uint, c_int, POINTER(c_char_p), POINTER(c_int)]
        gl.glCompileShader.argtypes = [c_uint]
        gl.glGetShaderiv.argtypes = [c_uint, c_uint, POINTER(c_int)]
        gl.glGetShaderInfoLog.argtypes = [c_uint, c_int, POINTER(c_int), c_char_p]
        gl.glDeleteShader.argtypes = [c_uint]
        gl.glCreateProgram.argtypes = []
        gl.glCreateProgram.restype = c_uint
        gl.glAttachShader.argtypes = [c_uint, c_uint]
        gl.glLinkProgram.argtypes = [c_uint]
        gl.glGetProgramiv.argtypes = [c_uint, c_uint, POINTER(c_int)]
        gl.glGetProgramInfoLog.argtypes = [c_uint, c_int, POINTER(c_int), c_char_p]
        gl.glDeleteProgram.argtypes = [c_uint]
        version = gl.glGetString(GL_VERSION)
        self.version = version.decode("ascii", "replace") if version else "unknown"

    def _shader_log(self, shader: int) -> str:
        length = c_int()
        self.gl.glGetShaderiv(shader, GL_INFO_LOG_LENGTH, byref(length))
        buf = create_string_buffer(max(length.value, 1))
        written = c_int()
        self.gl.glGetShaderInfoLog(shader, len(buf), byref(written), buf)
        return buf.value.decode("utf-8", "replace")

    def _program_log(self, program: int) -> str:
        length = c_int()
        self.gl.glGetProgramiv(program, GL_INFO_LOG_LENGTH, byref(length))
        buf = create_string_buffer(max(length.value, 1))
        written = c_int()
        self.gl.glGetProgramInfoLog(program, len(buf), byref(written), buf)
        return buf.value.decode("utf-8", "replace")

    def compile(self, kind: int, source: str, label: str) -> int:
        shader = self.gl.glCreateShader(kind)
        encoded = source.encode("utf-8")
        src = c_char_p(encoded)
        length = c_int(len(encoded))
        self.gl.glShaderSource(shader, 1, byref(src), byref(length))
        self.gl.glCompileShader(shader)
        ok = c_int()
        self.gl.glGetShaderiv(shader, GL_COMPILE_STATUS, byref(ok))
        if not ok.value:
            log = self._shader_log(shader)
            self.gl.glDeleteShader(shader)
            raise RuntimeError(f"{label} compile failed:\n{log}")
        return shader

    def link(self, vertex: int, fragment: int, label: str) -> None:
        program = self.gl.glCreateProgram()
        self.gl.glAttachShader(program, vertex)
        self.gl.glAttachShader(program, fragment)
        self.gl.glLinkProgram(program)
        ok = c_int()
        self.gl.glGetProgramiv(program, GL_LINK_STATUS, byref(ok))
        if not ok.value:
            log = self._program_log(program)
            self.gl.glDeleteProgram(program)
            raise RuntimeError(f"{label} link failed:\n{log}")
        self.gl.glDeleteProgram(program)


def main() -> int:
    wrappers = sorted(
        p for p in SHADERS.glob("world*/*.*sh") if p.suffix in {".vsh", ".fsh"}
    )
    if not wrappers:
        print("No wrappers found", file=sys.stderr)
        return 2

    resolved: dict[Path, str] = {}
    for path in wrappers:
        source = resolve_includes(path)
        if not source.startswith("#version"):
            raise RuntimeError(f"{path}: #version is not first")
        check_directives(source, str(path.relative_to(PACK_ROOT)))
        resolved[path] = source

    validator = GLValidator()
    pairs = []
    for vsh in sorted(p for p in wrappers if p.suffix == ".vsh"):
        fsh = vsh.with_suffix(".fsh")
        if fsh.exists():
            pairs.append((vsh, fsh))

    errors: list[str] = []
    for vsh, fsh in pairs:
        label = str(vsh.with_suffix("").relative_to(PACK_ROOT))
        vs = fs = 0
        try:
            vs = validator.compile(GL_VERTEX_SHADER, resolved[vsh], label + ".vsh")
            fs = validator.compile(GL_FRAGMENT_SHADER, resolved[fsh], label + ".fsh")
            validator.link(vs, fs, label)
            print("PASS", label)
        except Exception as exc:
            errors.append(str(exc))
            print("FAIL", label, file=sys.stderr)
            print(exc, file=sys.stderr)
        finally:
            if vs:
                validator.gl.glDeleteShader(vs)
            if fs:
                validator.gl.glDeleteShader(fs)

    print(f"OpenGL: {validator.version}")
    print(f"Validated {len(pairs)} linked programs; failures: {len(errors)}")
    if errors:
        (PACK_ROOT / "VALIDATION_ERRORS.txt").write_text(
            "\n\n".join(errors), encoding="utf-8"
        )
        return 1
    (PACK_ROOT / "VALIDATION_ERRORS.txt").unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
