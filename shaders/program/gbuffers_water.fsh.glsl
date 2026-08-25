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

/* RENDERTARGETS: 4,7 */
layout(location = 0) out vec4 outSurfaceData;
layout(location = 1) out vec4 outSurfaceTint;

const bool colortex4Clear = true;
const bool colortex7Clear = true;

void main() {
    vec4 atlasSample = texture(gtexture, vTexcoord);
    vec4 texel = vec4(atlasSample.rgb * vColor.rgb * vColor.a,
                       atlasSample.a * vColor.a);
    if (texel.a < max(alphaTestRef, 0.02)) discard;

    vec3 normal = normalize(vWorldNormal);
#if WATER_QUALITY > 0
    if (normal.y > 0.52 && materialEquals(vMaterial, MAT_WATER)) {
        vec3 waveNormal = waterNormalFromWorld(vWorldPosition.xz,
                                                frameTimeCounter);
#if WATER_QUALITY >= 2
        float rainMicro = rainStrength *
            sin(vWorldPosition.x * 17.0 + frameTimeCounter * 11.0) *
            sin(vWorldPosition.z * 19.0 - frameTimeCounter * 9.0);
        waveNormal.xz += rainMicro * 0.020;
#endif
#if WATER_QUALITY >= 3
        vec3 fineNormal = waterNormalFromWorld(
            vWorldPosition.xz * 2.43 + 11.7,
            frameTimeCounter * 1.31);
        waveNormal.xz += fineNormal.xz * 0.20;
#endif
        float normalBlend = WATER_QUALITY == 1 ? 0.46 :
                            (WATER_QUALITY == 2 ? 0.72 : 0.84);
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

    vec3 tint = srgbToLinear(max(texel.rgb, vec3(0.0)));
    float opacity = texel.a;

    if (isWater) {
        tint = mix(vec3(0.004, 0.040, 0.052), tint, 0.16);
        opacity = 1.0;
    } else if (isLava) {
        float pulse = 0.84 + 0.16 * sin(frameTimeCounter * 2.0 +
                                        vWorldPosition.x * 0.63 +
                                        vWorldPosition.z * 0.57);
        tint = vec3(4.4, 0.30, 0.010) * pulse;
        opacity = 1.0;
    } else if (isPortal) {
        tint = tint * 1.8 + vec3(0.20, 0.008, 1.20);
        opacity = max(opacity, 0.76);
    } else if (isIce) {
        tint = mix(tint, vec3(0.13, 0.42, 0.68), 0.42);
        opacity = mix(0.34, 0.58, opacity);
    } else {
        opacity = clamp(opacity, 0.08, 0.72);
    }

    outSurfaceData = vec4(octEncode(normal), surfaceClass / 8.0,
                          gl_FragCoord.z);
    outSurfaceTint = vec4(tint, opacity);
}
