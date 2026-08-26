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

/* RENDERTARGETS: 4,7,3 */
layout(location = 0) out vec4 outSurfaceData;
layout(location = 1) out vec4 outSurfaceTint;
layout(location = 2) out vec4 outLayerComposite;

const bool colortex3Clear = true;
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const bool colortex4Clear = true;
const bool colortex7Clear = true;

void main() {
    vec4 atlasSample = texture(gtexture, vTexcoord);
    vec4 texel = vec4(atlasSample.rgb * vColor.rgb,
                       atlasSample.a * vColor.a);
    if (texel.a < max(alphaTestRef, 0.02)) discard;

    bool isWater = materialEquals(vMaterial, MAT_WATER);
    vec3 normal = normalize(vWorldNormal);
#if WATER_QUALITY > 0
#ifdef WAVING_WATER
    if (normal.y > 0.52 && isWater) {
        vec3 waveNormal = waterNormalFromWorld(vWorldPosition.xz,
                                                frameTimeCounter);
#if WATER_QUALITY >= 2
        float rainMicro = rainStrength *
            sin(vWorldPosition.x * 17.0 + frameTimeCounter * 11.0) *
            sin(vWorldPosition.z * 19.0 - frameTimeCounter * 9.0);
        waveNormal.xz += rainMicro * 0.020;
#endif
#if WATER_QUALITY >= 2
        vec3 fineNormal = waterNormalFromWorld(
            vWorldPosition.xz * 2.43 + 11.7,
            frameTimeCounter * 1.31);
        waveNormal.xz += fineNormal.xz * 0.10;
#endif
        float normalBlend = WATER_QUALITY == 1 ? 0.28 :
                            (WATER_QUALITY == 2 ? 0.38 : 0.46);
        normal = normalize(mix(normal, waveNormal, normalBlend));
    } else if (isWater) {
        vec3 tangent = normalize(cross(vec3(0.0, 1.0, 0.0), normal));
        float flowA = sin(dot(vWorldPosition, tangent) * 3.1 -
                          vWorldPosition.y * 1.25 +
                          frameTimeCounter * 2.1);
        float flowB = sin(dot(vWorldPosition, tangent) * 6.7 -
                          vWorldPosition.y * 2.4 +
                          frameTimeCounter * 3.4 + 1.2);
        normal = normalize(normal + tangent * flowA * 0.045 +
                           vec3(0.0, 1.0, 0.0) * flowB * 0.022);
    }
#endif
#endif
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
        float verticalFlow = 1.0 - smoothstep(0.42, 0.72,
                                              abs(vWorldNormal.y));
        float flowVariation = 0.5 + 0.5 * sin(
            vWorldPosition.y * 1.8 - frameTimeCounter * 2.6 +
            dot(vWorldPosition.xz, vec2(1.7, -1.3)));
        tint = mix(vec3(0.004, 0.030, 0.038), tint, 0.08);
        tint *= mix(1.0, mix(0.90, 1.04, flowVariation),
                    verticalFlow * 0.28);
        // A waterfall is a thin sheet, not a full block of opaque blue water.
        opacity = WATER_OPACITY *
                  mix(mix(0.28, 0.38, flowVariation), 1.0,
                      1.0 - verticalFlow);
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
        opacity = clamp(opacity, 0.12, 0.68);
    }

    outSurfaceData = vec4(octEncode(normal), surfaceClass / 8.0,
                          gl_FragCoord.z);
    outSurfaceTint = vec4(tint, opacity);
    // colortex3 uses straight-alpha blending to retain every sorted layer.
    outLayerComposite = vec4(tint, opacity);
}
