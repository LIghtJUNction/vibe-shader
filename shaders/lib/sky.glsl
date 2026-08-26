#ifndef VIBE_SHADER_SKY
#define VIBE_SHADER_SKY

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/vibe.glsl"

uniform float frameTimeCounter;
uniform float rainStrength;
uniform int worldTime;

float starLayer(vec3 rd, float scale, float threshold) {
    vec3 cell = floor(rd * scale);
    vec3 local = fract(rd * scale) - 0.5;
    float h = hash13(cell);
    float star = smoothstep(0.078, 0.0, length(local.xy));
    star *= smoothstep(threshold, 1.0, h);
    star *= mix(0.45, 1.65, hash13(cell + 13.7));
    return star;
}

vec3 starField(vec3 rd, float night) {
    float stars = starLayer(rd, 420.0, 0.985);
    stars += 0.34 * starLayer(rd.yzx, 760.0, 0.993);
    float cellHash = hash13(floor(rd * 420.0));
    float twinkle = 0.68 + 0.32 *
        sin(frameTimeCounter * 1.8 + cellHash * TAU);
    vec3 tint = mix(vec3(0.48, 0.70, 1.0),
                    vec3(1.0, 0.67, 0.40), cellHash);
    return tint * stars * twinkle * night;
}

float highCirrus(vec3 rd, float time) {
    if (rd.y <= 0.015) return 0.0;
    vec2 sphereUv = vec2(atan(rd.z, rd.x) / TAU,
                         asin(clamp(rd.y, -1.0, 1.0)) / PI);
    vec2 wind = vec2(time * 0.0017, -time * 0.00045);
    float broad = fbm2(sphereUv * vec2(6.0, 17.0) + wind);
    float streak = valueNoise2(sphereUv * vec2(18.0, 54.0) +
                               wind * 4.0);
    float cloud = smoothstep(0.54, 0.73,
                             broad * 0.78 + streak * 0.22);
    return cloud * smoothstep(0.02, 0.26, rd.y) *
           (1.0 - smoothstep(0.78, 1.0, rd.y));
}

vec3 overworldSky(vec3 rd, vec3 sunDir, vec3 moonDir) {
    float sunHeight = sunDir.y;
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);

    float up = saturate(rd.y * 0.5 + 0.5);
    float horizon = pow(1.0 - saturate(abs(rd.y)), 3.2);
    vec3 sky = mix(vibeSkyHorizon(sunHeight, rainStrength),
                   vibeSkyZenith(sunHeight, rainStrength),
                   pow(up, 0.50));

    vec2 rayHorizon = rd.xz / max(length(rd.xz), 1e-5);
    vec2 sunHorizon = sunDir.xz / max(length(sunDir.xz), 1e-5);
    float sunSide = pow(saturate(dot(rayHorizon, sunHorizon)), 5.0);
    float oppositeSide = pow(saturate(dot(rayHorizon, -sunHorizon)), 3.0);
    vec3 duskColor = mix(vibeAccentB(), vibeSunColor(sunHeight,
                                                     rainStrength), 0.58);
    sky += duskColor * horizon * twilight *
           (0.15 + sunSide * 0.74) * TWILIGHT_BOOST;
    sky += vibeAccentA() * horizon * twilight *
           oppositeSide * 0.055 * TWILIGHT_BOOST;

    float mu = saturate(dot(rd, sunDir));
    float sunDisk = smoothstep(0.99972, 0.99993, mu);
    float coreHalo = pow(mu, 640.0) * 2.4;
    float wideHalo = pow(mu, 38.0) * 0.20;
    vec3 sunColor = vibeSunColor(sunHeight, rainStrength);
    sky += sunColor * (sunDisk * 22.0 + coreHalo + wideHalo) * day;

    // A soft atmospheric aureole gives the sky a clear visual anchor without
    // turning the whole screen into bloom.
    float aureole = exp(-(1.0 - mu) * 16.0) * horizon;
    sky += sunColor * aureole * (0.16 + twilight * 0.35) * day;

    float moonMu = saturate(dot(rd, moonDir));
    float moonDisk = smoothstep(0.99968, 0.99992, moonMu);
    float moonCut = smoothstep(
        0.99946, 0.99976,
        dot(rd, normalize(moonDir + vec3(0.024, 0.011, 0.0))));
    sky += vec3(0.40, 0.62, 1.08) * moonDisk *
           (1.0 - 0.72 * moonCut) * night * 3.8;
    sky += vec3(0.10, 0.22, 0.58) *
           pow(moonMu, 90.0) * night * 0.68;

    sky += starField(rd, night * smoothstep(-0.08, 0.24, rd.y));

    float cirrus = highCirrus(rd, frameTimeCounter);
    float cirrusLight = 0.25 + 0.75 *
        pow(saturate(dot(rd, sunDir) * 0.5 + 0.5), 5.0);
    vec3 cirrusColor = mix(vibeSkyHorizon(sunHeight, rainStrength),
                           sunColor, cirrusLight);
    sky = mix(sky, cirrusColor * (0.62 + day * 0.35),
              cirrus * (1.0 - rainStrength) * 0.20);

#ifdef AURORA_ENABLED
    float pole = smoothstep(0.03, 0.72, rd.y) * night;
    vec2 auroraUv = vec2(atan(rd.z, rd.x) / TAU, rd.y);
    float band = fbm2(vec2(auroraUv.x * 7.0 +
                           frameTimeCounter * 0.011,
                           auroraUv.y * 4.2));
    float curtain = pow(saturate(1.0 - abs(
        auroraUv.y - 0.43 - (band - 0.5) * 0.19) * 8.5), 3.0);
    float folds = 0.55 + 0.45 * sin(auroraUv.x * 31.0 +
                                   frameTimeCounter * 0.08 +
                                   band * 8.0);
    vec3 auroraColor = mix(vibeAccentA(), vibeAccentB(),
                           0.5 + 0.5 *
                           sin(auroraUv.x * 17.0));
    sky += auroraColor * curtain * folds * pole *
           (0.26 + VIBE_INTENSITY * 0.20);
#endif

    sky = mix(sky, vec3(0.17, 0.19, 0.21),
              rainStrength * 0.70);
    return max(sky, vec3(0.0));
}

vec3 netherSky(vec3 rd) {
    float horizon = pow(1.0 - abs(rd.y), 2.0);
    vec3 p = rd * 4.5;
    p.xz += vec2(frameTimeCounter * 0.018,
                 -frameTimeCounter * 0.011);
    float smoke = fbm3(p);
    float veins = pow(saturate(fbm3(p * 2.1) - 0.43), 3.0);
    vec3 base = mix(vec3(0.010, 0.0015, 0.001),
                    vec3(0.20, 0.016, 0.003),
                    horizon * 0.7 + smoke * 0.35);
    base += vec3(1.55, 0.065, 0.006) * veins *
            (0.4 + 0.6 * horizon);
    base += vibeAccentB() * veins * 0.04;

    vec3 cell = floor(rd * 220.0 +
                      vec3(0.0, frameTimeCounter * 2.0, 0.0));
    float ember = smoothstep(0.995, 1.0, hash13(cell));
    base += vec3(2.5, 0.24, 0.012) * ember * horizon;
    return base;
}

vec3 endSky(vec3 rd) {
    vec3 base = vec3(0.002, 0.001, 0.012);
    float nebula = fbm3(rd * 4.0 +
                       vec3(frameTimeCounter * 0.006, 0.0, 0.0));
    float filament = pow(saturate(nebula - 0.42), 2.2);
    base += mix(vec3(0.08, 0.012, 0.22),
                vec3(0.01, 0.28, 0.42),
                valueNoise3(rd * 7.0)) * filament * 1.7;
    base += starField(rd, 1.0) * 1.5;

    vec3 singularityDir = normalize(vec3(0.18, 0.12, -1.0));
    float d = acos(clamp(dot(rd, singularityDir), -1.0, 1.0));
    float disk = 1.0 - smoothstep(0.050, 0.061, d);
    float ring = exp(-abs(d - 0.078) * 170.0);
    float outer = exp(-abs(d - 0.105) * 45.0);
    base *= 1.0 - disk;
    base += vibeAccentB() * ring * 3.4;
    base += vibeAccentA() * outer * 0.68;

    vec3 axis = normalize(cross(singularityDir,
                                vec3(0.0, 1.0, 0.0)));
    float jet = pow(saturate(dot(rd, axis)), 64.0) +
                pow(saturate(dot(rd, -axis)), 64.0);
    base += vibeAccentA() * jet * 0.48;
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
