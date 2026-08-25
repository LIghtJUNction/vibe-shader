#ifndef VIBE_SHADER_GEOMETRY
#define VIBE_SHADER_GEOMETRY

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/materials.glsl"

float waterHeight(vec2 xz, float time) {
    float a = sin(dot(xz, vec2(0.63, 0.29)) + time * 1.35);
    float b = sin(dot(xz, vec2(-0.31, 0.71)) + time * 1.07 + 1.8);
    float c = sin(length(xz * vec2(0.17, 0.13)) * 2.4 - time * 0.72);
    return (a * 0.045 + b * 0.030 + c * 0.018);
}

vec3 waterNormalFromWorld(vec2 xz, float time) {
    const float e = 0.18;
    float hL = waterHeight(xz - vec2(e, 0.0), time);
    float hR = waterHeight(xz + vec2(e, 0.0), time);
    float hD = waterHeight(xz - vec2(0.0, e), time);
    float hU = waterHeight(xz + vec2(0.0, e), time);
    return normalize(vec3(hL - hR, 2.0 * e, hD - hU));
}

vec3 applyVoxelAnimation(vec3 worldPos, float blockId, vec2 atlasUv,
                         vec3 midBlockOffset, float time) {
    // at_midBlock stores (block center - vertex) in 1/64 block units.
    // This gives stable per-vertex weighting for plants and fluid top edges.
    float topWeight = saturate(0.5 - midBlockOffset.y / 64.0);
#ifdef WAVING_FOLIAGE
    if (abs(blockId - BID_LEAVES) < 0.5) {
        float phase = dot(worldPos.xz, vec2(0.81, 0.57)) + time * 1.35;
        float gust = 0.55 + 0.45 * sin(time * 0.17 + worldPos.x * 0.035);
        worldPos.xz += vec2(sin(phase), cos(phase * 0.83)) * 0.025 * gust;
    }

    if (abs(blockId - BID_PLANT) < 0.5) {
        float phase = dot(worldPos.xz, vec2(0.71, 0.43)) + time * 1.8;
        vec2 sway = vec2(sin(phase), cos(phase * 0.91)) * 0.065;
        worldPos.xz += sway * smoothstep(0.10, 0.90, topWeight);
    }
#endif

#ifdef WAVING_WATER
    if (abs(blockId - BID_WATER) < 0.5) {
        worldPos.y += waterHeight(worldPos.xz, time) *
                      smoothstep(0.08, 0.92, topWeight);
    }
#endif

    return worldPos;
}

#endif
