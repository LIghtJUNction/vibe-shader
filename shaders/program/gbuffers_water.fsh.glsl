#include "/lib/buffers.glsl"
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/materials.glsl"
#include "/lib/geometry.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform float frameTimeCounter;
uniform float rainStrength;

in vec2 vTexcoord;
in vec2 vLmcoord;
in vec4 vColor;
in vec3 vWorldPosition;
in vec3 vWorldNormal;
flat in float vMaterial;

/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 outWaterColor;
layout(location = 1) out vec4 outWaterData;

void main() {
    vec4 atlasSample = texture(gtexture, vTexcoord);
    vec4 texel = vec4(atlasSample.rgb * vColor.rgb * vColor.a,
                       atlasSample.a);
    if (texel.a < max(alphaTestRef, 0.02)) discard;

    vec3 normal = normalize(vWorldNormal);
#if WATER_QUALITY > 0
    if (normal.y > 0.55) {
        vec3 waveNormal = waterNormalFromWorld(vWorldPosition.xz,
                                                frameTimeCounter);
#if WATER_QUALITY >= 2
        float rainMicro = rainStrength *
            sin(vWorldPosition.x * 18.0 + frameTimeCounter * 12.0) *
            sin(vWorldPosition.z * 21.0 - frameTimeCounter * 10.0);
        waveNormal.xz += rainMicro * 0.025;
#endif
#if WATER_QUALITY >= 3
        vec3 fineNormal = waterNormalFromWorld(vWorldPosition.xz * 2.31 + 7.4,
                                                frameTimeCounter * 1.37);
        waveNormal.xz += fineNormal.xz * 0.22;
#endif
        float normalBlend = WATER_QUALITY == 1 ? 0.55 :
                            (WATER_QUALITY == 2 ? 0.82 : 0.90);
        normal = normalize(mix(normal, waveNormal, normalBlend));
    }
#endif

    bool isWater = materialEquals(vMaterial, MAT_WATER);
    bool isLava = materialEquals(vMaterial, MAT_LAVA);
    bool isPortal = materialEquals(vMaterial, MAT_PORTAL);
    bool isIce = materialEquals(vMaterial, MAT_ICE);

    float surfaceClass = isWater ? 1.0 :
                         (isIce ? 3.0 :
                         (isPortal ? 4.0 :
                         (isLava ? 5.0 : 2.0)));

    vec3 placeholder = vec3(0.0);
    float opacity = texel.a * 0.48;
    if (isWater) {
        placeholder = vec3(0.012, 0.055, 0.075);
        opacity = 0.12;
    } else if (isLava) {
        float pulse = 0.82 + 0.18 * sin(frameTimeCounter * 2.1 +
                                        vWorldPosition.x * 0.7 +
                                        vWorldPosition.z * 0.6);
        placeholder = vec3(3.8, 0.31, 0.012) * pulse;
        opacity = 0.94;
    } else if (isPortal) {
        placeholder = srgbToLinear(texel.rgb) * 2.8 +
                      vec3(0.28, 0.01, 1.25);
        opacity = 0.78;
    } else if (isIce) {
        placeholder = srgbToLinear(texel.rgb) * vec3(0.48, 0.78, 1.0);
        opacity = 0.42;
    } else {
        placeholder = srgbToLinear(texel.rgb) * 0.42;
    }

    outWaterColor = vec4(placeholder, opacity);
    outWaterData = vec4(octEncode(normal), surfaceClass / 8.0,
                        gl_FragCoord.z);
}
