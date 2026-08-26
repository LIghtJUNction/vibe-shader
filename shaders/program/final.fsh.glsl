#include "/lib/buffers.glsl"
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/vibe.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float thunderStrength;
uniform float near;
uniform float far;
uniform float currentPlayerHealth;
uniform float currentPlayerHunger;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;
uniform int frameCounter;
uniform int isEyeInWater;
uniform bool is_hurt;

#include "/lib/vision.glsl"

in vec2 vTexcoord;

const bool colortex0MipmapEnabled = true;
const bool colortex3MipmapEnabled = true;

layout(location = 0) out vec4 outColor;

vec3 sampleScene(vec2 uv) {
    return texture(colortex0, saturate(uv)).rgb;
}

vec3 applyPerceptualLocalContrast(vec3 color, vec2 uv) {
    vec3 surround = textureLod(colortex0, uv, 3.0).rgb;
    float centerLuma = luminance(color);
    float surroundLuma = luminance(surround);
    float stopDifference = clamp(
        log2((centerLuma + 0.035) / (surroundLuma + 0.035)),
        -0.72, 0.72);
    float gain = exp2(stopDifference * 0.30);
    return color * gain;
}

vec3 fxaaResolve(vec2 uv) {
#ifndef FXAA_ENABLED
    return sampleScene(uv);
#else
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 rgbM  = sampleScene(uv);
    vec3 rgbNW = sampleScene(uv + vec2(-px.x,  px.y));
    vec3 rgbNE = sampleScene(uv + vec2( px.x,  px.y));
    vec3 rgbSW = sampleScene(uv + vec2(-px.x, -px.y));
    vec3 rgbSE = sampleScene(uv + vec2( px.x, -px.y));

    float lumaM  = luminance(rgbM);
    float lumaNW = luminance(rgbNW);
    float lumaNE = luminance(rgbNE);
    float lumaSW = luminance(rgbSW);
    float lumaSE = luminance(rgbSE);
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

    vec2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
    float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) * 0.03125, 1e-4);
    float reciprocalMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = clamp(dir * reciprocalMin, vec2(-7.0), vec2(7.0)) * px;

    vec3 rgbA = 0.5 * (
        sampleScene(uv + dir * (1.0 / 3.0 - 0.5)) +
        sampleScene(uv + dir * (2.0 / 3.0 - 0.5))
    );
    vec3 rgbB = rgbA * 0.5 + 0.25 * (
        sampleScene(uv + dir * -0.5) +
        sampleScene(uv + dir *  0.5)
    );
    float lumaB = luminance(rgbB);
    vec3 resolved = (lumaB < lumaMin || lumaB > lumaMax)
        ? rgbA : rgbB;
    float contrast = lumaMax - lumaMin;
    float edgeConfidence = saturate(
        contrast / max(lumaMax + 0.08, 0.12) * 1.65);
    vec3 localAverage = (rgbM * 2.0 + rgbNW + rgbNE + rgbSW + rgbSE) /
                        6.0;
    resolved = mix(resolved, localAverage, edgeConfidence * 0.12);
    return mix(rgbM, resolved, edgeConfidence);
#endif
}

vec3 multiScaleBloom(vec2 uv, float night) {
#ifndef BLOOM_ENABLED
    return vec3(0.0);
#else
    vec3 bloom = vec3(0.0);
    bloom += textureLod(colortex3, uv, 1.0).rgb * 0.43;
    bloom += textureLod(colortex3, uv, 3.0).rgb * 0.32;
    bloom += textureLod(colortex3, uv, 5.0).rgb * 0.21;
    bloom += ocularAstigmatism(uv, night);
    return bloom * BLOOM_STRENGTH;
#endif
}

vec2 lightScreenPosition(vec3 viewPosition) {
    vec4 clip = gbufferProjection * vec4(viewPosition, 1.0);
    if (clip.w <= 0.0) return vec2(-8.0);
    return clip.xy / clip.w * 0.5 + 0.5;
}

vec3 ocularSunGlare(vec2 uv) {
#if defined(DIM_NETHER) || defined(DIM_END)
    return vec3(0.0);
#else
    vec2 lightUv = lightScreenPosition(sunPosition);
    if (any(lessThan(lightUv, vec2(0.0))) ||
        any(greaterThan(lightUv, vec2(1.0)))) return vec3(0.0);

    float sky = step(0.99998, texture(depthtex0, lightUv).r);
    vec2 axis = uv - lightUv;
    float halo = exp(-dot(axis, axis) * 15.0);
    float veil = exp(-dot(axis, axis) * 3.2);
    vec3 glare = vec3(1.0, 0.72, 0.43) *
                 (halo * 0.015 + veil * 0.0035);
    return glare * sky * (1.0 - rainStrength);
#endif
}

vec3 gradeColor(vec3 color, float sunHeight) {
    return applyVibePostGrade(color, sunHeight, rainStrength);
}

void main() {
    vec2 uv = vTexcoord;
    vec2 centered = uv - 0.5;
    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                 sunPosition);
    float sunHeight = sunDirWorld.y;
    vec4 eyeState = visionState(sunHeight);
    vec2 opticalUv = applyVisionDizziness(uv, eyeState);

    vec3 scene = fxaaResolve(opticalUv);
    scene = applyDepthAwareVisionBlur(opticalUv, scene, eyeState);
    scene = applyPerceptualLocalContrast(scene, opticalUv);
    scene += multiScaleBloom(opticalUv, eyeState.w);
    scene += ocularSunGlare(opticalUv);

#ifdef DIM_NETHER
    scene *= vec3(1.12, 0.82, 0.74);
    scene += vec3(0.08, 0.005, 0.0) * (0.5 + 0.5 * sin(frameTimeCounter * 1.7));
#elif defined DIM_END
    scene *= vec3(0.94, 0.90, 1.16);
#endif

    if (isEyeInWater == 1) scene *= vec3(0.78, 1.03, 1.08);
    if (isEyeInWater == 2) scene *= vec3(1.34, 0.58, 0.31);

    scene = gradeColor(max(scene * TONEMAP_EXPOSURE, vec3(0.0)),
                       sunHeight);
    vec2 localLight = texture(colortex2, opticalUv).rg;
    scene = applyAdaptiveVisionMood(scene, sunHeight, eyeState,
                                    localLight);
    scene = acesTonemap(scene);

    float vignette = 1.0 - dot(centered, centered) * 0.16;
    vignette *= 1.0 - pow(saturate(abs(centered.x) * 1.75), 4.0) * 0.035;
    vignette *= physiologicalVignette(centered, eyeState);
    scene *= saturate(vignette);

#ifdef SURVIVAL_VISION
    // Rod-dominated sight is noisy in darkness; daylight remains clean.
    float neuralNoise = hash12(gl_FragCoord.xy +
                               float(frameCounter) * 19.19) - 0.5;
    float lowLightNoise = 0.0004 + eyeState.w * 0.0025 +
                          rainStrength * 0.0007;
    scene += neuralNoise * lowLightNoise *
             (0.22 + 0.78 * (1.0 - luminance(scene)));
#endif

    scene = linearToSrgb(saturate(scene));
    outColor = vec4(scene, 1.0);
}
