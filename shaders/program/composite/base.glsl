#include "/lib/buffers.glsl"
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/vibe.glsl"
#include "/lib/materials.glsl"
#include "/lib/space.glsl"
#include "/lib/sky.glsl"
#include "/lib/clouds.glsl"
#ifndef DIM_NETHER
#ifndef DIM_END
#include "/lib/shadows.glsl"
#endif
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifndef DIM_NETHER
#ifndef DIM_END
uniform sampler2D shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
#endif
#endif

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float wetness;
uniform float thunderStrength;
uniform int frameCounter;
uniform int isEyeInWater;

in vec2 vTexcoord;

const bool colortex6Clear = false;

/* RENDERTARGETS: 0,3,6 */
layout(location = 0) out vec4 outScene;
layout(location = 1) out vec4 outBloom;
layout(location = 2) out vec4 outHistory;

#if SSR_QUALITY == 0
    #define SSR_STEPS 0
#elif SSR_QUALITY == 1
    #define SSR_STEPS 8
#elif SSR_QUALITY == 2
    #define SSR_STEPS 16
#else
    #define SSR_STEPS 26
#endif

#if SHADOW_QUALITY <= 1
    #define VOLUME_STEPS 6
#elif SHADOW_QUALITY == 2
    #define VOLUME_STEPS 9
#else
    #define VOLUME_STEPS 13
#endif

vec3 dimensionWaterTint() {
#ifdef DIM_NETHER
    return vec3(0.24, 0.018, 0.003);
#elif defined DIM_END
    return vec3(0.018, 0.015, 0.10);
#else
    return vec3(0.012, 0.21, 0.27);
#endif
}

// Translucent terrain is submitted back-to-front. Remove the final (nearest)
// straight-alpha term to recover the already-composited layers behind it.
vec3 resolveLayersBehindNearest(vec3 baseScene,
                                vec4 nearestLayer,
                                vec4 accumulatedLayers) {
    float nearestAlpha = saturate(nearestLayer.a);
    float remaining = 1.0 - nearestAlpha;
    if (remaining <= 0.01) return baseScene;

    float farAlpha = saturate(
        (accumulatedLayers.a - nearestAlpha) / remaining);
    vec3 farPremultiplied =
        (accumulatedLayers.rgb - nearestLayer.rgb * nearestAlpha) /
        remaining;
    farPremultiplied = clamp(farPremultiplied,
                             vec3(0.0), vec3(16.0));
    return farPremultiplied + baseScene * (1.0 - farAlpha);
}

vec3 sampleLayeredBackground(vec2 uv) {
    uv = saturate(uv);
    return resolveLayersBehindNearest(
        texture(colortex5, uv).rgb,
        texture(colortex7, uv),
        texture(colortex3, uv));
}

vec3 sampleChromaticRefraction(vec2 uv, vec2 offset) {
    vec3 c;
    c.r = sampleLayeredBackground(uv + offset * 1.04).r;
    c.g = sampleLayeredBackground(uv + offset).g;
    c.b = sampleLayeredBackground(uv + offset * 0.96).b;
    return c;
}

vec3 traceScreenReflection(vec3 startView, vec3 directionView,
                           out float confidence, out vec2 hitUv) {
    confidence = 0.0;
    hitUv = vec2(-1.0);
#if SSR_STEPS == 0
    return vec3(0.0);
#else
    if (directionView.z > -0.015) return vec3(0.0);

    vec3 rayPosition = startView + directionView * 0.18;
    float stepLength = mix(0.28, 0.75,
                           saturate(length(startView) / 90.0));
    float travelled = 0.0;

    for (int i = 0; i < SSR_STEPS; ++i) {
        rayPosition += directionView * stepLength;
        travelled += stepLength;
        stepLength *= 1.13;

        vec2 uv = projectViewToUv(rayPosition, gbufferProjection);
        if (any(lessThanEqual(uv, vec2(0.002))) ||
            any(greaterThanEqual(uv, vec2(0.998)))) {
            break;
        }

        float sceneDepth = texture(depthtex1, uv).r;
        if (sceneDepth >= 0.999999) continue;

        vec3 scenePosition =
            viewPositionFromDepth(uv, sceneDepth,
                                  gbufferProjectionInverse);
        float delta = scenePosition.z - rayPosition.z;
        float thickness = 0.10 + stepLength * 1.35;

        if (delta > 0.0 && delta < thickness) {
            float edgeFade = saturate(min(min(uv.x, uv.y),
                                          min(1.0 - uv.x,
                                              1.0 - uv.y)) * 12.0);
            float distanceFade = 1.0 -
                saturate(travelled / 95.0);
            confidence = edgeFade * distanceFade;
            hitUv = uv;
            return texture(colortex5, uv).rgb;
        }
    }
    return vec3(0.0);
#endif
}

