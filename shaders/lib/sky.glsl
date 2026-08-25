#ifndef VIBE_SHADER_SKY
#define VIBE_SHADER_SKY

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform float frameTimeCounter;
uniform float rainStrength;
uniform int worldTime;

float starLayer(vec3 rd, float scale, float threshold) {
    vec3 cell = floor(rd * scale);
    vec3 local = fract(rd * scale) - 0.5;
    float h = hash13(cell);
    float star = smoothstep(0.085, 0.0, length(local.xy));
    star *= smoothstep(threshold, 1.0, h);
    star *= mix(0.55, 1.55, hash13(cell + 13.7));
    return star;
}

vec3 starField(vec3 rd, float night) {
    float stars = starLayer(rd, 420.0, 0.985);
    stars += 0.35 * starLayer(rd.yzx, 720.0, 0.993);
    float twinkle = 0.72 + 0.28 * sin(frameTimeCounter * 2.0 +
                                      hash13(floor(rd * 420.0)) * TAU);
    vec3 tint = mix(vec3(0.55, 0.72, 1.0), vec3(1.0, 0.72, 0.45),
                    hash13(floor(rd * 190.0)));
    return tint * stars * twinkle * night;
}

vec3 overworldSky(vec3 rd, vec3 sunDir, vec3 moonDir) {
    float sunHeight = sunDir.y;
    float day = smoothstep(-0.08, 0.06, sunHeight);
    float night = 1.0 - smoothstep(-0.16, 0.04, sunHeight);
    float horizon = pow(1.0 - saturate(abs(rd.y)), 4.0);
    float up = saturate(rd.y * 0.5 + 0.5);

    vec3 dayZenith = vec3(0.075, 0.28, 0.64);
    vec3 dayHorizon = vec3(0.52, 0.73, 0.98);
    vec3 nightZenith = vec3(0.003, 0.006, 0.028);
    vec3 nightHorizon = vec3(0.035, 0.045, 0.105);

    vec3 skyDay = mix(dayHorizon, dayZenith, pow(up, 0.42));
    vec3 skyNight = mix(nightHorizon, nightZenith, pow(up, 0.65));

    float sunset = exp(-abs(sunHeight) * 14.0) * day;
    vec2 rayHorizon = rd.xz / max(length(rd.xz), 1e-5);
    vec2 sunHorizon = sunDir.xz / max(length(sunDir.xz), 1e-5);
    float sunSide = pow(saturate(dot(rayHorizon, sunHorizon)), 8.0);
    vec3 sunsetColor = vec3(1.25, 0.25, 0.045) * horizon * sunset *
                       (0.22 + 0.78 * sunSide);

    vec3 sky = mix(skyNight, skyDay, day) + sunsetColor;

    float mu = saturate(dot(rd, sunDir));
    float sunDisk = smoothstep(0.99978, 0.99994, mu);
    float sunHalo = pow(mu, 512.0) * 1.8 + pow(mu, 32.0) * 0.22;
    vec3 sunColor = mix(vec3(1.35, 0.28, 0.05), vec3(1.0, 0.86, 0.60),
                        smoothstep(-0.02, 0.28, sunHeight));
    sky += sunColor * (sunDisk * 18.0 + sunHalo) * day;

    float moonMu = saturate(dot(rd, moonDir));
    float moonDisk = smoothstep(0.99978, 0.99994, moonMu);
    float moonCut = smoothstep(0.99955, 0.99978,
                              dot(rd, normalize(moonDir + vec3(0.025, 0.012, 0.0))));
    sky += vec3(0.45, 0.66, 1.0) * moonDisk * (1.0 - 0.72 * moonCut) * night * 3.0;
    sky += vec3(0.16, 0.26, 0.55) * pow(moonMu, 96.0) * night * 0.5;

    sky += starField(rd, night * smoothstep(-0.1, 0.22, rd.y));

#ifdef AURORA_ENABLED
    float pole = smoothstep(0.0, 0.72, rd.y) * night;
    vec2 auroraUv = vec2(atan(rd.z, rd.x) / TAU, rd.y);
    float band = fbm2(vec2(auroraUv.x * 7.0 + frameTimeCounter * 0.012,
                           auroraUv.y * 4.0));
    float curtain = pow(saturate(1.0 - abs(auroraUv.y - 0.42 -
                         (band - 0.5) * 0.18) * 8.0), 3.0);
    vec3 auroraColor = mix(vec3(0.02, 1.15, 0.58), vec3(0.35, 0.12, 1.2),
                           0.5 + 0.5 * sin(auroraUv.x * 18.0));
    sky += auroraColor * curtain * pole * 0.38;
#endif

    sky = mix(sky, vec3(0.20, 0.25, 0.30), rainStrength * 0.72);
    return max(sky, vec3(0.0));
}

vec3 netherSky(vec3 rd) {
    float horizon = pow(1.0 - abs(rd.y), 2.0);
    vec3 p = rd * 4.5;
    p.xz += vec2(frameTimeCounter * 0.018, -frameTimeCounter * 0.011);
    float smoke = fbm3(p);
    float veins = pow(saturate(fbm3(p * 2.1) - 0.43), 3.0);
    vec3 base = mix(vec3(0.012, 0.002, 0.001), vec3(0.19, 0.018, 0.004),
                    horizon * 0.7 + smoke * 0.35);
    base += vec3(1.4, 0.075, 0.008) * veins * (0.4 + 0.6 * horizon);

    vec3 cell = floor(rd * 220.0 + vec3(0.0, frameTimeCounter * 2.0, 0.0));
    float ember = smoothstep(0.995, 1.0, hash13(cell));
    base += vec3(2.5, 0.28, 0.015) * ember * horizon;
    return base;
}

vec3 endSky(vec3 rd) {
    vec3 base = vec3(0.002, 0.001, 0.012);
    float nebula = fbm3(rd * 4.0 + vec3(frameTimeCounter * 0.006, 0.0, 0.0));
    float filament = pow(saturate(nebula - 0.42), 2.2);
    base += mix(vec3(0.08, 0.012, 0.22), vec3(0.01, 0.28, 0.42),
                valueNoise3(rd * 7.0)) * filament * 1.6;
    base += starField(rd, 1.0) * 1.4;

    vec3 singularityDir = normalize(vec3(0.18, 0.12, -1.0));
    float d = acos(clamp(dot(rd, singularityDir), -1.0, 1.0));
    float disk = 1.0 - smoothstep(0.050, 0.061, d);
    float ring = exp(-abs(d - 0.078) * 170.0);
    float outer = exp(-abs(d - 0.105) * 45.0);
    base *= 1.0 - disk;
    base += vec3(1.6, 0.08, 0.82) * ring * 3.0;
    base += vec3(0.08, 0.75, 1.8) * outer * 0.55;

    vec3 axis = normalize(cross(singularityDir, vec3(0.0, 1.0, 0.0)));
    float jet = pow(saturate(dot(rd, axis)), 64.0) +
                pow(saturate(dot(rd, -axis)), 64.0);
    base += vec3(0.15, 0.65, 2.4) * jet * 0.45;
    return base;
}

vec3 renderDimensionSky(vec3 rd, vec3 sunDir, vec3 moonDir) {
#ifdef DIM_NETHER
    return netherSky(rd);
#elif defined DIM_END
    return endSky(rd);
#else
    return overworldSky(rd, sunDir, moonDir);
#endif
}

#endif
