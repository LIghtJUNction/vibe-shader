#ifndef VIBE_SHADER_SHADOWS
#define VIBE_SHADER_SHADOWS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#if SHADOW_QUALITY == 0
    #define SHADOW_TAPS 1
    const int shadowMapResolution = 1024;
#elif SHADOW_QUALITY == 1
    #define SHADOW_TAPS 4
    const int shadowMapResolution = 1536;
#elif SHADOW_QUALITY == 2
    #define SHADOW_TAPS 9
    const int shadowMapResolution = 2048;
#else
    #define SHADOW_TAPS 16
    const int shadowMapResolution = 3072;
#endif

const float shadowDistance = SHADOW_DISTANCE;
const float shadowDistanceRenderMul = 1.0;
const float sunPathRotation = -18.0;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

vec3 distortShadowClipPosition(vec3 clipPosition) {
    float factor = length(clipPosition.xy) * 0.86 + 0.14;
    clipPosition.xy /= factor;
    clipPosition.z *= 0.50;
    return clipPosition;
}

vec3 shadowScreenFromWorld(vec3 worldPosition, vec3 cameraPosition,
                           mat4 shadowModelView, mat4 shadowProjection,
                           float bias) {
    vec3 playerPosition = worldPosition - cameraPosition;
    vec4 clip = shadowProjection * shadowModelView *
                vec4(playerPosition, 1.0);
    clip.z -= bias;
    clip.xyz = distortShadowClipPosition(clip.xyz);
    return clip.xyz / max(clip.w, 1e-7) * 0.5 + 0.5;
}

vec3 readTransparentShadow(vec3 shadowScreenPosition,
                           sampler2D shadowtex0,
                           sampler2D shadowtex1,
                           sampler2D shadowcolor0) {
    if (shadowScreenPosition.x <= 0.001 ||
        shadowScreenPosition.x >= 0.999 ||
        shadowScreenPosition.y <= 0.001 ||
        shadowScreenPosition.y >= 0.999 ||
        shadowScreenPosition.z <= 0.0 ||
        shadowScreenPosition.z >= 1.0) {
        return vec3(1.0);
    }

    float allDepth = texture(shadowtex0, shadowScreenPosition.xy).r;
    if (shadowScreenPosition.z <= allDepth) {
        return vec3(1.0);
    }

    float opaqueDepth = texture(shadowtex1, shadowScreenPosition.xy).r;
    if (shadowScreenPosition.z > opaqueDepth) {
        return vec3(0.0);
    }

    vec4 caster = texture(shadowcolor0, shadowScreenPosition.xy);
    vec3 casterTint = max(caster.rgb, vec3(0.02));
    float casterOpacity = saturate(caster.a);
    return mix(vec3(1.0), casterTint, casterOpacity * 0.82);
}

vec3 softShadowAt(vec3 worldPosition, vec3 worldNormal, vec3 lightDirection,
                  vec3 cameraPosition, mat4 shadowModelView,
                  mat4 shadowProjection, sampler2D shadowtex0,
                  sampler2D shadowtex1, sampler2D shadowcolor0,
                  vec2 pixel, float frame) {
#if SHADOW_QUALITY == 0
    return vec3(1.0);
#else
    float normalBias = mix(0.00028, 0.00155,
                           1.0 - saturate(dot(worldNormal, lightDirection)));
    vec3 base = shadowScreenFromWorld(worldPosition + worldNormal * 0.035,
                                      cameraPosition, shadowModelView,
                                      shadowProjection, normalBias);
    vec3 sum = vec3(0.0);
    float angle = interleavedGradientNoise(pixel, frame) * TAU;
    mat2 rotation = rotate2(angle);

    const vec2 kernel[16] = vec2[](
        vec2(-0.6134,  0.6175), vec2( 0.1700, -0.0403),
        vec2(-0.2994, -0.7919), vec2( 0.6457,  0.4932),
        vec2(-0.6518, -0.2200), vec2( 0.4210, -0.7061),
        vec2( 0.7658, -0.1781), vec2(-0.0812,  0.9652),
        vec2(-0.9223,  0.1678), vec2( 0.3215,  0.8763),
        vec2( 0.0021, -0.9953), vec2( 0.9364,  0.2947),
        vec2(-0.4382,  0.8121), vec2( 0.5458,  0.0738),
        vec2(-0.1241, -0.4510), vec2( 0.1820,  0.4930)
    );

    float radiusPixels = mix(0.85, 2.25,
                             saturate(length(worldPosition - cameraPosition) /
                                      SHADOW_DISTANCE));
    for (int i = 0; i < SHADOW_TAPS; ++i) {
        vec2 offset = rotation * kernel[i] *
                      radiusPixels / float(shadowMapResolution);
        vec3 samplePosition = base;
        samplePosition.xy += offset;
        sum += readTransparentShadow(samplePosition, shadowtex0,
                                     shadowtex1, shadowcolor0);
    }
    return sum / float(SHADOW_TAPS);
#endif
}

float quickShadowAt(vec3 worldPosition, vec3 cameraPosition,
                    mat4 shadowModelView, mat4 shadowProjection,
                    sampler2D shadowtex0) {
#if SHADOW_QUALITY == 0
    return 1.0;
#else
    vec3 shadowPosition = shadowScreenFromWorld(worldPosition,
                                                cameraPosition,
                                                shadowModelView,
                                                shadowProjection,
                                                0.00065);
    if (any(lessThanEqual(shadowPosition.xy, vec2(0.001))) ||
        any(greaterThanEqual(shadowPosition.xy, vec2(0.999))) ||
        shadowPosition.z <= 0.0 || shadowPosition.z >= 1.0) {
        return 1.0;
    }
    return step(shadowPosition.z,
                texture(shadowtex0, shadowPosition.xy).r);
#endif
}

#endif
