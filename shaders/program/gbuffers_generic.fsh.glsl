#include "/lib/buffers.glsl"
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/materials.glsl"

#ifdef HAS_TEXTURE
uniform sampler2D gtexture;
#endif

#ifdef HAS_LIGHTMAP
uniform sampler2D lightmap;
#endif

uniform float alphaTestRef;
uniform vec4 entityColor;

in vec2 vTexcoord;
in vec2 vLmcoord;
in vec4 vColor;
in vec3 vWorldPosition;
in vec3 vWorldNormal;

#ifdef FORWARD_TRANSLUCENT

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
#ifdef HAS_TEXTURE
    vec4 texel = texture(gtexture, vTexcoord) * vColor;
#else
    vec4 texel = vColor;
#endif

#ifdef APPLY_ENTITY_COLOR
    texel.rgb = mix(texel.rgb, entityColor.rgb, entityColor.a);
#endif

#ifdef ALPHA_CUTOUT
    if (texel.a < max(alphaTestRef, 0.08)) discard;
#endif

    vec3 color = srgbToLinear(texel.rgb);
#ifdef HAS_LIGHTMAP
    vec3 lm = texture(lightmap, vLmcoord).rgb;
    color *= max(lm, vec3(0.055));
#else
    color *= 0.85;
#endif

#ifdef EMISSIVE_PASS
    color += srgbToLinear(texel.rgb) * 3.8;
#endif

    outColor = vec4(color, texel.a);
}

#else

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormalRoughness;
layout(location = 2) out vec4 outLightMaterial;

void main() {
#ifdef HAS_TEXTURE
    vec4 texel = texture(gtexture, vTexcoord) * vColor;
#else
    vec4 texel = vColor;
#endif

#ifdef APPLY_ENTITY_COLOR
    texel.rgb = mix(texel.rgb, entityColor.rgb, entityColor.a);
#endif

#ifdef ALPHA_CUTOUT
    if (texel.a < max(alphaTestRef, 0.08)) discard;
#endif

    float emission = 0.0;
#ifdef EMISSIVE_PASS
    emission = 1.0;
#endif

    outAlbedo = vec4(srgbToLinear(texel.rgb), texel.a);
    outNormalRoughness =
        vec4(normalize(vWorldNormal) * 0.5 + 0.5,
             emission > 0.5 ? 0.12 : 0.68);
    outLightMaterial =
        vec4(saturate(vLmcoord), emission,
             encodeMaterial(MAT_ENTITY));
}

#endif
