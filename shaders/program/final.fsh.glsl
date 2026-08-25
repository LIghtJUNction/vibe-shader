#include "/lib/buffers.glsl"
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/vibe.glsl"

uniform sampler2D colortex0;
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
uniform int frameCounter;
uniform int isEyeInWater;

in vec2 vTexcoord;

const bool colortex3MipmapEnabled = true;

layout(location = 0) out vec4 outColor;

vec3 sampleScene(vec2 uv) {
    return texture(colortex0, saturate(uv)).rgb;
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
    return (lumaB < lumaMin || lumaB > lumaMax) ? rgbA : rgbB;
#endif
}

vec3 multiScaleBloom(vec2 uv) {
#ifndef BLOOM_ENABLED
    return vec3(0.0);
#else
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 bloom = vec3(0.0);
    bloom += textureLod(colortex3, uv, 1.0).rgb * 0.30;
    bloom += textureLod(colortex3, uv, 2.0).rgb * 0.24;
    bloom += textureLod(colortex3, uv, 3.0).rgb * 0.19;
    bloom += textureLod(colortex3, uv, 4.0).rgb * 0.15;
    bloom += textureLod(colortex3, uv, 5.0).rgb * 0.10;

    // Anamorphic streaks are deliberately sparse to preserve the block image.
    vec3 streak = vec3(0.0);
    for (int i = 1; i <= 5; ++i) {
        float f = float(i);
        vec2 d = vec2(px.x * f * f * 3.6, 0.0);
        streak += textureLod(colortex3, saturate(uv + d), 2.0).rgb;
        streak += textureLod(colortex3, saturate(uv - d), 2.0).rgb;
    }
    bloom += streak * 0.025;
    return bloom * BLOOM_STRENGTH;
#endif
}

vec2 lightScreenPosition(vec3 viewPosition) {
    vec4 clip = gbufferProjection * vec4(viewPosition, 1.0);
    if (clip.w <= 0.0) return vec2(-8.0);
    return clip.xy / clip.w * 0.5 + 0.5;
}

vec3 lensArtifacts(vec2 uv) {
#if defined(DIM_NETHER) || defined(DIM_END)
    return vec3(0.0);
#else
    vec2 lightUv = lightScreenPosition(sunPosition);
    if (any(lessThan(lightUv, vec2(0.0))) ||
        any(greaterThan(lightUv, vec2(1.0)))) return vec3(0.0);

    float sky = step(0.99998, texture(depthtex0, lightUv).r);
    vec2 axis = uv - lightUv;
    float halo = exp(-dot(axis, axis) * 5.5);
    vec2 ghostA = uv - (vec2(1.0) - lightUv) * 0.65 - lightUv * 0.35;
    vec2 ghostB = uv - (vec2(0.5) + (vec2(0.5) - lightUv) * 0.72);
    float g1 = exp(-dot(ghostA, ghostA) * 140.0);
    float g2 = exp(-dot(ghostB, ghostB) * 85.0);
    float cross = exp(-abs(axis.x) * 180.0) * exp(-abs(axis.y) * 8.0) +
                  exp(-abs(axis.y) * 180.0) * exp(-abs(axis.x) * 8.0);
    vec3 flare = vec3(1.0, 0.52, 0.18) * halo * 0.020;
    flare += vec3(0.12, 0.52, 1.0) * g1 * 0.055;
    flare += vec3(1.0, 0.10, 0.34) * g2 * 0.035;
    flare += vec3(1.0, 0.70, 0.34) * cross * 0.020;
    return flare * sky * (1.0 - rainStrength);
#endif
}

vec3 gradeColor(vec3 color, float sunHeight) {
    return applyVibePostGrade(color, sunHeight, rainStrength);
}

void main() {
    vec2 uv = vTexcoord;
    vec2 centered = uv - 0.5;

    // Subpixel spectral split only affects bright contrast boundaries.
    vec2 chromaOffset = centered * 0.00115 * dot(centered, centered);
    vec3 scene = fxaaResolve(uv);
    float highlight = smoothstep(0.9, 2.5, luminance(scene));
    vec3 splitScene = scene;
    splitScene.r = sampleScene(uv + chromaOffset).r;
    splitScene.b = sampleScene(uv - chromaOffset).b;
    scene = mix(scene, splitScene, highlight * 0.42);

    scene += multiScaleBloom(uv);
    scene += lensArtifacts(uv);

#ifdef DIM_NETHER
    scene *= vec3(1.12, 0.82, 0.74);
    scene += vec3(0.08, 0.005, 0.0) * (0.5 + 0.5 * sin(frameTimeCounter * 1.7));
#elif defined DIM_END
    scene *= vec3(0.94, 0.90, 1.16);
#endif

    if (isEyeInWater == 1) scene *= vec3(0.78, 1.03, 1.08);
    if (isEyeInWater == 2) scene *= vec3(1.34, 0.58, 0.31);

    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                 sunPosition);
    scene = gradeColor(max(scene * TONEMAP_EXPOSURE, vec3(0.0)),
                       sunDirWorld.y);
    scene = acesTonemap(scene);

    float vignette = 1.0 - dot(centered, centered) * 0.42;
    vignette *= 1.0 - pow(saturate(abs(centered.x) * 1.75), 4.0) * 0.10;
    scene *= saturate(vignette);

#ifdef FILMIC_GRAIN
    float grain = hash12(gl_FragCoord.xy + float(frameCounter) * 19.19) - 0.5;
    scene += grain * (0.010 + rainStrength * 0.006) *
             (0.35 + 0.65 * (1.0 - luminance(scene)));
#endif

    scene = linearToSrgb(saturate(scene));
    outColor = vec4(scene, 1.0);
}
