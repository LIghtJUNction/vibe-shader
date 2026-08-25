#include "/lib/buffers.glsl"
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
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
    vec3 cell = fract(worldPosition + normal * 0.003);
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
    return 1.0 - smoothstep(0.018, 0.075, distanceToEdge);
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
    vec3 low = vec3(0.055, 0.006, 0.002);
    vec3 high = vec3(0.18, 0.018, 0.004);
    return mix(low, high, saturate(normal.y * 0.5 + 0.5));
#elif defined DIM_END
    vec3 low = vec3(0.012, 0.006, 0.035);
    vec3 high = vec3(0.055, 0.035, 0.15);
    return mix(low, high, saturate(normal.y * 0.5 + 0.5));
#else
    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                 sunPosition);
    float day = smoothstep(-0.08, 0.08, sunDirWorld.y);
    vec3 nightAmbient = mix(vec3(0.018, 0.025, 0.065),
                            vec3(0.07, 0.10, 0.19),
                            saturate(normal.y * 0.5 + 0.5));
    vec3 dayAmbient = mix(vec3(0.10, 0.13, 0.18),
                          vec3(0.34, 0.48, 0.70),
                          saturate(normal.y * 0.5 + 0.5));
    return mix(nightAmbient, dayAmbient, day) *
           mix(0.22, 1.0, skyLight);
#endif
}

vec3 shadeSurface(vec2 uv, vec3 albedo, vec3 worldNormal,
                  float roughness, vec2 lightmapValue,
                  float emissionMask, float materialId,
                  vec3 viewPosition, vec3 worldPosition) {
    vec3 normal = normalize(worldNormal);
    vec3 viewDirection = normalize(cameraPosition - worldPosition);
    vec3 viewNormal = normalize(mat3(gbufferModelView) * normal);

    float blockLight = saturate((lightmapValue.x - 0.03) / 0.94);
    float skyLight = saturate((lightmapValue.y - 0.03) / 0.94);
    blockLight = blockLight * blockLight;

    float ao = screenSpaceAO(uv, viewPosition, viewNormal);
    vec3 ambient = dimensionAmbient(normal, skyLight);
    vec3 warmBlockLight = vec3(1.35, 0.39, 0.065) *
                          blockLight * 1.45;

    vec3 direct = vec3(0.0);
    vec3 specular = vec3(0.0);

#ifndef DIM_NETHER
#ifndef DIM_END
    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                 sunPosition);
    vec3 moonDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                  moonPosition);
    vec3 lightDirWorld =
        normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    float sunHeight = sunDirWorld.y;
    float day = smoothstep(-0.08, 0.08, sunHeight);
    float sunset = exp(-abs(sunHeight) * 10.0);
    vec3 daylight = mix(vec3(0.16, 0.28, 0.66),
                        mix(vec3(1.35, 0.27, 0.055),
                            vec3(1.08, 0.89, 0.66),
                            smoothstep(0.00, 0.32, sunHeight)),
                        day);
    daylight += vec3(0.55, 0.08, 0.015) * sunset * day;

    float nDotL = saturate(dot(normal, lightDirWorld));
    vec3 shadow = softShadowAt(worldPosition, normal, lightDirWorld,
                               cameraPosition, shadowModelView,
                               shadowProjection, shadowtex0,
                               shadowtex1, shadowcolor0,
                               gl_FragCoord.xy, float(frameCounter));

    float cloudShade = cloudShadowAt(worldPosition, frameTimeCounter,
                                     rainStrength);
    shadow *= mix(1.0, cloudShade, day * 0.78);
    direct = daylight * nDotL * shadow *
             mix(0.10, 1.0, skyLight);

    float wetSurface = wetness *
        smoothstep(0.48, 0.94, normal.y) *
        (1.0 - float(materialEquals(materialId, MAT_LEAVES)));
    roughness = mix(roughness, 0.065, wetSurface * 0.82);
    albedo *= mix(1.0, 0.69, wetSurface * 0.58);

    vec3 halfVector = normalize(viewDirection + lightDirWorld);
    float nDotH = saturate(dot(normal, halfVector));
    float nDotV = saturate(dot(normal, viewDirection));
    float exponent = mix(180.0, 7.0, roughness * roughness);
    float distribution = pow(nDotH, exponent) *
                         (exponent + 2.0) / (TAU + 1e-4);
    bool metal = materialEquals(materialId, MAT_METAL);
    vec3 f0 = metal ? mix(vec3(0.12), albedo, 0.78) :
                      vec3(0.028);
    vec3 fresnel = f0 + (1.0 - f0) * pow5(1.0 - nDotV);
    specular = daylight * distribution * fresnel *
               nDotL * shadow * mix(0.18, 1.0, skyLight);

    // Held torches and lanterns act as a cheap camera-local point light.
    float heldLight = float(max(heldBlockLightValue,
                                heldBlockLightValue2)) / 15.0;
    float cameraDistance = length(worldPosition - cameraPosition);
    vec3 toCamera = normalize(cameraPosition - worldPosition);
    float heldDiffuse = saturate(dot(normal, toCamera));
    warmBlockLight += vec3(1.8, 0.52, 0.09) *
                      heldLight * heldLight *
                      exp(-cameraDistance * 0.16) *
                      (0.25 + 0.75 * heldDiffuse) * 6.0;
#else
    vec3 pseudoLight = normalize(vec3(-0.35, 0.82, 0.44));
    float diffuse = 0.22 + 0.78 * saturate(dot(normal, pseudoLight));
    direct = vec3(0.11, 0.05, 0.26) * diffuse;
#endif
#else
    vec3 pseudoLight = normalize(vec3(0.28, 0.72, -0.61));
    float diffuse = 0.25 + 0.75 * saturate(dot(normal, pseudoLight));
    direct = vec3(0.42, 0.045, 0.008) * diffuse;
#endif

    vec3 emission = materialEmissionColor(materialId, albedo,
                                          emissionMask, worldPosition,
                                          normal, viewDirection);

    vec3 color = albedo * (ambient * ao + warmBlockLight + direct) +
                 specular + emission;

#ifdef BLOCK_EDGE_ACCENT
    if (isTerrainMaterial(materialId) &&
        !materialEquals(materialId, MAT_LEAVES) &&
        !materialEquals(materialId, MAT_PLANT)) {
        float edge = blockEdgeMask(worldPosition, normal);
        vec3 edgeTint = isOreMaterial(materialId)
            ? oreColor(materialId)
            : mix(vec3(0.025, 0.055, 0.10),
                  vec3(0.40, 0.62, 0.82), skyLight);
        color *= 1.0 - edge * EDGE_STRENGTH * 0.72;
        color += edgeTint * edge * EDGE_STRENGTH *
                 (0.12 + emissionMask * 1.4);
    }
#endif

    color = mix(color, color * vec3(0.45, 0.70, 0.36) + vec3(0.03),
                nightVision * 0.72);
    color *= 1.0 - blindness;
    return max(color, vec3(0.0));
}

void main() {
    float depth = texture(depthtex1, vTexcoord).r;
    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                 sunPosition);
    vec3 moonDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                  moonPosition);
    vec3 rdWorld = viewDirectionWorld(vTexcoord,
                                      gbufferProjectionInverse,
                                      gbufferModelViewInverse);

    vec3 color;
    if (depth >= 0.999999) {
        color = renderDimensionSky(rdWorld, sunDirWorld, moonDirWorld);
    } else {
        vec4 albedoData = texture(colortex0, vTexcoord);
        vec4 normalData = texture(colortex1, vTexcoord);
        vec4 materialData = texture(colortex2, vTexcoord);

        vec3 viewPosition =
            viewPositionFromDepth(vTexcoord, depth,
                                  gbufferProjectionInverse);
        vec3 playerPosition =
            viewToPlayer(viewPosition, gbufferModelViewInverse);
        vec3 worldPosition = playerPosition + cameraPosition;

        vec3 worldNormal =
            normalize(normalData.rgb * 2.0 - 1.0);
        float materialId = decodeMaterial(materialData.a);

        color = shadeSurface(vTexcoord, albedoData.rgb, worldNormal,
                             normalData.a, materialData.rg,
                             materialData.b, materialId,
                             viewPosition, worldPosition);

        float distanceToCamera = length(viewPosition);
#ifdef DIM_NETHER
        float fogAmount = 1.0 - exp(-distanceToCamera * 0.026);
#elif defined DIM_END
        float fogAmount = 1.0 - exp(-distanceToCamera * 0.0065);
#else
        float normalizedDistance = distanceToCamera / max(far, 1.0);
        float fogAmount = 1.0 - exp(-pow(normalizedDistance * 1.25, 3.0) *
                                      (1.1 + rainStrength * 2.4));
#endif
        vec3 fogColor = renderDimensionSky(rdWorld,
                                           sunDirWorld, moonDirWorld);
        color = mix(color, fogColor, saturate(fogAmount));
    }

    outScene = vec4(color, 1.0);
    outOpaqueCopy = vec4(color, 1.0);
}
