#ifndef VIBE_SHADER_TIDAL
#define VIBE_SHADER_TIDAL

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

// Surface-local plankton, not luminous water tint. Coordinates remain attached
// to the water as the camera moves; distance filtering prevents subpixel crawl.
vec3 tidalRadiance(vec3 worldPos, float thickness, float horizontal,
                   float distanceToEye, float sunHeight, float time) {
#if WATER_QUALITY < 1 || defined DIM_NETHER
    return vec3(0.0);
#else
#ifdef DIM_END
    float night = 1.0;
#else
    float night = 1.0 - smoothstep(-0.16, 0.015, sunHeight);
#endif
    float visibility = night * horizontal * TIDAL_GLOW *
        (1.0 - smoothstep(28.0, 76.0, distanceToEye)) *
        smoothstep(0.04, 0.45, thickness);
    if (visibility < 0.001) return vec3(0.0);
    vec2 p = worldPos.xz;
    float t = time * PHENOMENA_SPEED;
    float colony = smoothstep(0.45, 0.73, valueNoise2(p * 0.19));
    // Domain-warp the interference so it does not read as a square lattice.
    p += vec2(valueNoise2(p * 0.45 + t * 0.016),
              valueNoise2(p * 0.45 - vec2(3.1, t * 0.02))) * 2.1;
    float wave = sin(dot(p, vec2(1.73, 0.81)) + t * 0.38) +
                 sin(dot(p, vec2(-0.92, 1.47)) - t * 0.29);
    float width = mix(0.045, 0.14, saturate(distanceToEye / 50.0));
    float threads = exp(-sqr(wave / width)) * (0.045 / width);
    float crest = 0.55 + 0.45 * sin(dot(p, vec2(0.17, -0.23)) + t * 0.21);
    vec3 pearl = mix(vec3(0.06, 0.42, 0.36), vec3(0.30, 0.58, 0.51), crest);
    return pearl * threads * colony * visibility * 0.72;
#endif
}

#endif
