#ifndef VIBE_SHADER_CELESTIAL
#define VIBE_SHADER_CELESTIAL

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

// Finite-width angular lines; no longitude branch cut, screen UV, history,
// texture fetch, or additional render target. The world axes never follow the eye.
float celestialLine(float distanceToLine, float width) {
    float x = distanceToLine / max(width, 0.0015);
    return exp(-x * x);
}

vec3 meridianRadiance(vec3 rd, float sunHeight, float time, float rain) {
#if CELESTIAL_QUALITY == 0
    return vec3(0.0);
#else
    float night = 1.0 - smoothstep(-0.18, 0.04, sunHeight);
    float dusk = exp(-abs(sunHeight + 0.035) * 9.0);
    float visibility = (night * 0.42 + dusk * 0.78) *
                       (1.0 - rain) * smoothstep(-0.025, 0.12, rd.y);
    if (visibility < 0.001 || CELESTIAL_STRENGTH == 0.0) return vec3(0.0);

    const vec3 axis = vec3(0.0, 0.8, 0.6);
    const vec3 along = vec3(1.0, 0.0, 0.0);
    const vec3 across = vec3(0.0, -0.6, 0.8);
    vec2 orbit = vec2(dot(rd, along), dot(rd, across));
    float t = time * PHENOMENA_SPEED * 0.055;
    float fold = sin(orbit.x * 5.0 + orbit.y * 2.0 + t) * 0.023;
    fold += sin(orbit.y * 9.0 - orbit.x * 3.0 - t * 0.7) * 0.009;
    float latitude = dot(rd, axis) - fold;
    float veil = celestialLine(latitude, 0.042);
    float seam = celestialLine(latitude + 0.016, 0.0035);
    float edge = celestialLine(latitude - 0.031, 0.006);
    float grain = valueNoise3(rd * 46.0 + vec3(t * 0.3));
    float filaments = 0.70 + 0.30 * sin(latitude * 140.0 + grain * 9.0 + orbit.x * 13.0 + t);
    vec3 ivory = vec3(1.10, 0.79, 0.42);
    vec3 opal = mix(vec3(0.13, 0.46, 0.58), vec3(0.60, 0.22, 0.18),
                    saturate(orbit.x * 0.5 + 0.5));
    vec3 light = ivory * (veil * filaments * 0.26 + seam * 0.72);
    light += opal * edge * 0.48;
    light *= mix(0.56, 1.0, grain);
#if CELESTIAL_QUALITY >= 2
    // A second, broken silk sheet, not another full-screen glow layer.
    float gap = smoothstep(0.33, 0.68, valueNoise3(rd * 8.0));
    float echo = celestialLine(latitude - 0.072 - fold * 0.5, 0.010);
    light += opal * echo * gap * 0.22;
#endif
#if VIBE_MODE == 0
    visibility *= 0.30;
#elif VIBE_MODE == 1
    visibility *= 0.65;
#endif
    return light * visibility * CELESTIAL_STRENGTH;
#endif
}

#endif
