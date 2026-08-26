#include "/lib/buffers.glsl"
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/materials.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

in vec2 vTexcoord;
in vec2 vLmcoord;
in vec4 vColor;
in vec3 vWorldPosition;
in vec3 vWorldNormal;
flat in float vMaterial;
flat in float vIntrinsicEmission;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormalRoughness;
layout(location = 2) out vec4 outLightMaterial;

float materialRoughness(float materialId) {
    if (materialEquals(materialId, MAT_METAL)) return 0.30;
    if (materialEquals(materialId, MAT_GLASS)) return 0.12;
    if (materialEquals(materialId, MAT_ICE)) return 0.18;
    if (materialEquals(materialId, MAT_LAVA)) return 0.90;
    if (materialEquals(materialId, MAT_PORTAL)) return 0.58;
    if (materialEquals(materialId, MAT_LEAVES) ||
        materialEquals(materialId, MAT_PLANT)) return 0.92;
    if (materialEquals(materialId, MAT_STONE)) return 0.84;
    if (materialEquals(materialId, MAT_SOIL)) return 0.93;
    if (materialEquals(materialId, MAT_WOOD)) return 0.78;
    if (materialEquals(materialId, MAT_SAND)) return 0.96;
    if (materialEquals(materialId, MAT_SNOW)) return 0.89;
    if (isOreMaterial(materialId)) return 0.78;
    // Unclassified blocks remain diffuse-first. Rain lowers roughness slightly
    // without turning every surface into polished wax.
    return mix(0.86, 0.58, rainStrength * 0.35);
}

vec3 cohesiveTerrainColor(vec3 albedo, float materialId,
                          vec3 worldPosition, vec3 worldNormal) {
#ifndef NATURAL_TERRAIN_COHESION
    return albedo;
#else
    if (materialEquals(materialId, MAT_METAL) ||
        materialEquals(materialId, MAT_GLASS) ||
        materialEquals(materialId, MAT_ICE) ||
        materialEquals(materialId, MAT_LAVA) ||
        materialEquals(materialId, MAT_PORTAL) ||
        isOreMaterial(materialId)) return albedo;

    // A continuous low-frequency field crosses block boundaries. It avoids
    // a per-block checkerboard while leaving the resource-pack texture intact.
    vec3 stablePosition = mod(worldPosition, 4096.0);
    float field = 0.5 + 0.25 * sin(stablePosition.x * 0.041 +
                                   stablePosition.z * 0.027) +
                  0.25 * sin(stablePosition.z * 0.033 -
                             stablePosition.y * 0.029 + 1.7);
    vec3 mineralTint = mix(vec3(0.965, 0.985, 1.025),
                           vec3(1.035, 1.018, 0.958), field);
    vec3 organicTint = mix(vec3(0.945, 1.018, 0.960),
                           vec3(1.028, 1.012, 0.948), field);
    bool organic = materialEquals(materialId, MAT_LEAVES) ||
                   materialEquals(materialId, MAT_PLANT);
    vec3 tint = organic ? organicTint : mineralTint;
    if (materialEquals(materialId, MAT_SOIL)) {
        tint = mix(vec3(0.970, 0.995, 0.965),
                   vec3(1.035, 0.982, 0.925), field);
    } else if (materialEquals(materialId, MAT_WOOD)) {
        tint = mix(vec3(0.975, 0.990, 1.012),
                   vec3(1.038, 1.008, 0.950), field);
    } else if (materialEquals(materialId, MAT_SAND)) {
        tint = mix(vec3(0.985, 1.000, 1.015),
                   vec3(1.030, 1.015, 0.970), field);
    } else if (materialEquals(materialId, MAT_SNOW)) {
        tint = mix(vec3(0.965, 0.990, 1.040),
                   vec3(1.018, 1.012, 0.990), field);
    }
    float upward = saturate(worldNormal.y * 0.5 + 0.5);
    float weight = TERRAIN_COHESION_STRENGTH * mix(0.52, 0.82, upward);
    return albedo * mix(vec3(1.0), tint, weight);
#endif
}

float materialDetailAmount(float materialId) {
    if (materialEquals(materialId, MAT_SOIL)) return 1.00;
    if (materialEquals(materialId, MAT_STONE)) return 0.82;
    if (materialEquals(materialId, MAT_WOOD)) return 0.62;
    if (materialEquals(materialId, MAT_SAND)) return 0.48;
    if (materialEquals(materialId, MAT_SNOW)) return 0.24;
    if (materialEquals(materialId, MAT_LEAVES) ||
        materialEquals(materialId, MAT_PLANT)) return 0.34;
    if (materialEquals(materialId, MAT_METAL)) return 0.22;
    if (materialEquals(materialId, MAT_GLASS) ||
        materialEquals(materialId, MAT_LAVA) ||
        materialEquals(materialId, MAT_PORTAL)) return 0.0;
    return isOreMaterial(materialId) ? 0.72 : 0.52;
}

vec3 detailedSurfaceNormal(vec3 baseNormal, vec4 centerSample,
                           float materialId, float cameraDistance,
                           inout vec3 albedo, inout float roughness) {
#ifndef MATERIAL_DETAIL
    return normalize(baseNormal);
#else
    float distanceFade = 1.0 - smoothstep(30.0, 78.0, cameraDistance);
    float strength = materialDetailAmount(materialId) *
                     MATERIAL_DETAIL_STRENGTH * distanceFade;
    if (strength < 0.002) return normalize(baseNormal);

    vec2 uvDx = dFdx(vTexcoord);
    vec2 uvDy = dFdy(vTexcoord);
    vec2 atlasPixel = 1.0 / vec2(textureSize(gtexture, 0));
    vec3 sampleU = textureGrad(gtexture,
        vTexcoord + vec2(atlasPixel.x, 0.0), uvDx, uvDy).rgb;
    vec3 sampleV = textureGrad(gtexture,
        vTexcoord + vec2(0.0, atlasPixel.y), uvDx, uvDy).rgb;
    float heightCenter = luminance(centerSample.rgb);
    float heightU = luminance(sampleU);
    float heightV = luminance(sampleV);

    vec3 normal = normalize(baseNormal);
    vec3 positionDx = dFdx(vWorldPosition);
    vec3 positionDy = dFdy(vWorldPosition);
    vec3 perpendicularY = cross(positionDy, normal);
    vec3 perpendicularX = cross(normal, positionDx);
    vec3 tangent = perpendicularY * uvDx.x + perpendicularX * uvDy.x;
    vec3 bitangent = perpendicularY * uvDx.y + perpendicularX * uvDy.y;
    float inverseScale = inversesqrt(max(
        max(dot(tangent, tangent), dot(bitangent, bitangent)), 1e-8));
    tangent *= inverseScale;
    bitangent *= inverseScale;

    vec2 heightGradient = vec2(heightU, heightV) - heightCenter;
    normal = normalize(normal -
        (tangent * heightGradient.x + bitangent * heightGradient.y) *
        strength * 2.35);

    float cavity = saturate(((heightU + heightV) * 0.5 -
                             heightCenter) * 3.2);
    albedo *= 1.0 - cavity * strength * 0.14;
    roughness = saturate(roughness +
        (0.52 - heightCenter) * strength * 0.075);
    return normal;
#endif
}

float materialEmission(float materialId, vec3 textureColor) {
    float luma = luminance(textureColor);
    if (materialEquals(materialId, MAT_LAVA)) return 1.0;
    if (materialEquals(materialId, MAT_EMISSIVE_WARM)) {
        return smoothstep(0.08, 0.72, luma);
    }
    if (materialEquals(materialId, MAT_EMISSIVE_COOL)) {
        return smoothstep(0.06, 0.64, luma);
    }
    if (materialEquals(materialId, MAT_PORTAL)) return 1.0;
    if (materialEquals(materialId, MAT_SCULK)) {
        float cyan = saturate(textureColor.b + textureColor.g -
                              textureColor.r * 1.35);
        return smoothstep(0.08, 0.65, cyan);
    }
#ifdef EMISSIVE_ORES
    if (isOreMaterial(materialId)) {
        float chroma = max(textureColor.r,
                       max(textureColor.g, textureColor.b)) -
                       min(textureColor.r,
                       min(textureColor.g, textureColor.b));
        float crystal = smoothstep(0.08, 0.42, chroma);
        float micro = smoothstep(0.82, 0.98,
            hash13(floor(vWorldPosition * 16.0) +
                   floor(frameTimeCounter * 2.0)));
        return crystal * (0.14 + 0.46 * micro);
    }
#endif
    return 0.0;
}

void main() {
    float cameraDistance = length(vWorldPosition - cameraPosition);
#ifdef NATURAL_TERRAIN_COHESION
    float filterScale = mix(1.0, 1.42,
        smoothstep(28.0, 132.0, cameraDistance));
    vec4 atlasSample = textureGrad(gtexture, vTexcoord,
        dFdx(vTexcoord) * filterScale,
        dFdy(vTexcoord) * filterScale);
#else
    vec4 atlasSample = texture(gtexture, vTexcoord);
#endif
    vec4 texel = vec4(atlasSample.rgb * vColor.rgb * vColor.a,
                       atlasSample.a);
    if (texel.a < max(alphaTestRef, 0.08)) {
        discard;
    }

    vec3 albedo = srgbToLinear(texel.rgb);
    albedo = cohesiveTerrainColor(albedo, vMaterial,
                                  vWorldPosition, vWorldNormal);
    float roughness = materialRoughness(vMaterial);
    vec3 surfaceNormal = detailedSurfaceNormal(
        vWorldNormal, atlasSample, vMaterial, cameraDistance,
        albedo, roughness);
    float emission = max(materialEmission(vMaterial, texel.rgb),
                         vIntrinsicEmission * 0.85);

    outAlbedo = vec4(albedo, texel.a);
    outNormalRoughness =
        vec4(surfaceNormal * 0.5 + 0.5, roughness);
    outLightMaterial =
        vec4(saturate(vLmcoord), emission, encodeMaterial(vMaterial));
}
