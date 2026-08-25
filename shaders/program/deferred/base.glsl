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
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

#ifndef DIM_NETHER
#ifndef DIM_END
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
#endif
#endif

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float wetness;
uniform float nightVision;
uniform float blindness;
uniform int frameCounter;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int isEyeInWater;

in vec2 vTexcoord;

/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 outScene;
layout(location = 1) out vec4 outOpaqueCopy;

vec3 oreColor(float materialId) {
    if (materialEquals(materialId, MAT_ORE_DIAMOND))
        return vec3(0.05, 1.35, 1.75);
    if (materialEquals(materialId, MAT_ORE_EMERALD))
        return vec3(0.05, 1.55, 0.35);
    if (materialEquals(materialId, MAT_ORE_REDSTONE))
        return vec3(2.0, 0.035, 0.012);
    if (materialEquals(materialId, MAT_ORE_LAPIS))
        return vec3(0.025, 0.18, 1.8);
    if (materialEquals(materialId, MAT_ORE_GOLD))
        return vec3(1.85, 0.72, 0.055);
    if (materialEquals(materialId, MAT_ORE_COPPER))
        return vec3(1.35, 0.24, 0.055);
    return vec3(0.85, 0.72, 0.62);
}

vec3 materialEmissionColor(float materialId, vec3 albedo,
                           float emissionMask, vec3 worldPosition,
                           vec3 normal, vec3 viewDirection) {
    if (emissionMask <= 0.0001) return vec3(0.0);

    if (materialEquals(materialId, MAT_LAVA)) {
        float pulse = 0.86 + 0.14 *
            sin(frameTimeCounter * 1.7 + worldPosition.x * 0.8 +
                worldPosition.z * 0.67);
        return vec3(4.8, 0.55, 0.035) * emissionMask * pulse;
    }
    if (materialEquals(materialId, MAT_EMISSIVE_WARM)) {
        return vec3(3.2, 0.92, 0.16) * emissionMask;
    }
    if (materialEquals(materialId, MAT_EMISSIVE_COOL)) {
        return vec3(0.18, 1.65, 2.9) * emissionMask;
    }
    if (materialEquals(materialId, MAT_PORTAL)) {
        float portalPulse = 0.72 + 0.28 *
            sin(frameTimeCounter * 3.2 + worldPosition.y * 2.1);
        return vec3(1.7, 0.055, 3.4) * emissionMask * portalPulse;
    }
    if (materialEquals(materialId, MAT_SCULK)) {
        return vec3(0.015, 1.15, 1.45) * emissionMask;
    }
    if (isOreMaterial(materialId)) {
        vec3 reflected = reflect(-viewDirection, normal);
        float glint = pow(saturate(dot(reflected,
                         normalize(vec3(0.43, 0.81, 0.39)))), 48.0);
        float cell = hash13(floor(worldPosition * 16.0));
        float pulse = 0.55 + 0.45 *
            sin(frameTimeCounter * 2.8 + cell * TAU);
        return oreColor(materialId) * emissionMask *
               (0.65 + glint * 3.2) * pulse;
    }
    if (materialEquals(materialId, MAT_ENTITY)) {
        return albedo * emissionMask * 3.5;
    }
    return albedo * emissionMask * 1.5;
}

float blockEdgeMask(vec3 worldPosition, vec3 normal) {
    vec3 cell = fract(worldPosition + normal * 0.004);
    vec2 faceUv;
    vec3 an = abs(normal);
    if (an.x > an.y && an.x > an.z) {
        faceUv = cell.yz;
    } else if (an.y > an.z) {
        faceUv = cell.xz;
    } else {
        faceUv = cell.xy;
    }
    vec2 edgeDistance = min(faceUv, 1.0 - faceUv);
    float distanceToEdge = min(edgeDistance.x, edgeDistance.y);
    float pixelWidth = max(fwidth(faceUv.x), fwidth(faceUv.y));
    float inner = 0.014 + pixelWidth * 0.55;
    float outer = 0.060 + pixelWidth * 1.35;
    return 1.0 - smoothstep(inner, outer, distanceToEdge);
}

float screenSpaceAO(vec2 uv, vec3 viewPosition, vec3 viewNormal) {
#ifndef SSAO_ENABLED
    return 1.0;
#else
    float depthScale = saturate((-viewPosition.z) / 90.0);
    float pixelRadius = mix(10.0, 3.0, depthScale);
    vec2 invResolution = 1.0 / vec2(viewWidth, viewHeight);
    float rotation = interleavedGradientNoise(gl_FragCoord.xy,
                                               float(frameCounter)) * TAU;
    float occlusion = 0.0;
    float validSamples = 0.0;

    const vec2 directions[8] = vec2[](
        vec2(1.0, 0.0), vec2(0.7071, 0.7071),
        vec2(0.0, 1.0), vec2(-0.7071, 0.7071),
        vec2(-1.0, 0.0), vec2(-0.7071, -0.7071),
        vec2(0.0, -1.0), vec2(0.7071, -0.7071)
    );

    mat2 rot = rotate2(rotation);
    for (int i = 0; i < 8; ++i) {
        float ring = 0.45 + 0.55 * float((i & 1) + 1);
        vec2 sampleUv = uv + rot * directions[i] *
                        pixelRadius * ring * invResolution;
        float sampleDepth = texture(depthtex1, sampleUv).r;
        if (sampleDepth >= 0.999999) continue;

        vec3 samplePosition =
            viewPositionFromDepth(sampleUv, sampleDepth,
                                  gbufferProjectionInverse);
        vec3 delta = samplePosition - viewPosition;
        float distanceToSample = length(delta);
        if (distanceToSample < 1e-4) continue;

        vec3 direction = delta / distanceToSample;
        float hemisphere = saturate(dot(viewNormal, direction) - 0.08);
        float attenuation = 1.0 -
            saturate(distanceToSample / mix(1.8, 5.5, depthScale));
        occlusion += hemisphere * attenuation;
        validSamples += 1.0;
    }

    if (validSamples < 0.5) return 1.0;
    return saturate(1.0 - occlusion / validSamples * 2.25);
#endif
}

vec3 dimensionAmbient(vec3 normal, float skyLight) {
#ifdef DIM_NETHER
    vec3 low = vec3(0.050, 0.005, 0.002);
    vec3 high = vec3(0.17, 0.016, 0.004);
    return mix(low, high, saturate(normal.y * 0.5 + 0.5));
#elif defined DIM_END
    vec3 low = vec3(0.010, 0.005, 0.032);
    vec3 high = vec3(0.050, 0.032, 0.14);
    return mix(low, high, saturate(normal.y * 0.5 + 0.5));
#else
    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                 sunPosition);
    vec3 down = vibeAmbientDown(sunDirWorld.y, rainStrength);
    vec3 up = vibeAmbientUp(sunDirWorld.y, rainStrength);
    float hemi = saturate(normal.y * 0.5 + 0.5);
    vec3 ambient = mix(down, up, hemi);
    return ambient * mix(0.18, 1.0, skyLight);
#endif
}

