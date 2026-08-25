#include "/lib/buffers.glsl"
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/materials.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform float rainStrength;
uniform float frameTimeCounter;

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
    if (materialEquals(materialId, MAT_METAL)) return 0.18;
    if (materialEquals(materialId, MAT_GLASS)) return 0.08;
    if (materialEquals(materialId, MAT_ICE)) return 0.10;
    if (materialEquals(materialId, MAT_LAVA)) return 0.45;
    if (materialEquals(materialId, MAT_PORTAL)) return 0.12;
    if (materialEquals(materialId, MAT_LEAVES) ||
        materialEquals(materialId, MAT_PLANT)) return 0.82;
    if (isOreMaterial(materialId)) return 0.48;
    return mix(0.70, 0.46, rainStrength * 0.35);
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
    vec4 atlasSample = texture(gtexture, vTexcoord);
    vec4 texel = vec4(atlasSample.rgb * vColor.rgb * vColor.a,
                       atlasSample.a);
    if (texel.a < max(alphaTestRef, 0.08)) {
        discard;
    }

    vec3 albedo = srgbToLinear(texel.rgb);
    float roughness = materialRoughness(vMaterial);
    float emission = max(materialEmission(vMaterial, texel.rgb),
                         vIntrinsicEmission * 0.85);

    outAlbedo = vec4(albedo, texel.a);
    outNormalRoughness =
        vec4(normalize(vWorldNormal) * 0.5 + 0.5, roughness);
    outLightMaterial =
        vec4(saturate(vLmcoord), emission, encodeMaterial(vMaterial));
}
