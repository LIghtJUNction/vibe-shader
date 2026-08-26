#ifndef VIBE_SHADER_VIBE
#define VIBE_SHADER_VIBE

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

void vibeTimeFactors(float sunHeight, out float day, out float twilight,
                     out float night) {
    day = smoothstep(-0.055, 0.095, sunHeight);
    night = 1.0 - smoothstep(-0.16, 0.025, sunHeight);
    twilight = exp(-abs(sunHeight) * 7.5) * (1.0 - night * 0.34);
}

vec3 vibeAccentA() {
#if VIBE_MODE == 0
    return vec3(0.18, 0.42, 0.74);
#elif VIBE_MODE == 1
    return vec3(1.10, 0.34, 0.075);
#elif VIBE_MODE == 2
    return vec3(0.035, 0.88, 1.35);
#else
    return vec3(0.08, 0.95, 1.65);
#endif
}

vec3 vibeAccentB() {
#if VIBE_MODE == 0
    return vec3(0.74, 0.55, 0.32);
#elif VIBE_MODE == 1
    return vec3(1.35, 0.78, 0.24);
#elif VIBE_MODE == 2
    return vec3(1.15, 0.055, 0.82);
#else
    return vec3(1.55, 0.19, 0.045);
#endif
}

vec3 vibeSunColor(float sunHeight, float rain) {
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);
#if VIBE_MODE == 0
    vec3 horizon = vec3(1.20, 0.42, 0.14);
    vec3 noon = vec3(1.03, 0.92, 0.76);
#elif VIBE_MODE == 1
    vec3 horizon = vec3(1.65, 0.24, 0.035);
    vec3 noon = vec3(1.16, 0.88, 0.58);
#elif VIBE_MODE == 2
    vec3 horizon = vec3(1.42, 0.20, 0.18);
    vec3 noon = vec3(1.02, 0.86, 0.67);
#else
    vec3 horizon = vec3(1.70, 0.16, 0.025);
    vec3 noon = vec3(1.02, 0.75, 0.48);
#endif
    vec3 color = mix(horizon, noon, smoothstep(0.015, 0.42, sunHeight));
    color = mix(color, vec3(0.62, 0.72, 0.84), rain * 0.70);
    return color;
}

vec3 vibeSkyZenith(float sunHeight, float rain) {
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);
#if VIBE_MODE == 0
    vec3 dayColor = vec3(0.070, 0.255, 0.585);
    vec3 nightColor = vec3(0.003, 0.007, 0.028);
#elif VIBE_MODE == 1
    vec3 dayColor = vec3(0.060, 0.235, 0.500);
    vec3 nightColor = vec3(0.004, 0.006, 0.021);
#elif VIBE_MODE == 2
    vec3 dayColor = vec3(0.045, 0.245, 0.570);
    vec3 nightColor = vec3(0.006, 0.004, 0.035);
#else
    vec3 dayColor = vec3(0.025, 0.155, 0.390);
    vec3 nightColor = vec3(0.002, 0.004, 0.024);
#endif
    vec3 color = mix(nightColor, dayColor, day);
    color += vibeAccentB() * twilight * 0.034 * TWILIGHT_BOOST;
    return mix(color, vec3(0.115, 0.145, 0.185), rain * 0.82);
}

vec3 vibeSkyHorizon(float sunHeight, float rain) {
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);
#if VIBE_MODE == 0
    vec3 dayColor = vec3(0.46, 0.67, 0.88);
    vec3 nightColor = vec3(0.026, 0.040, 0.090);
#elif VIBE_MODE == 1
    vec3 dayColor = vec3(0.58, 0.67, 0.73);
    vec3 nightColor = vec3(0.030, 0.032, 0.065);
#elif VIBE_MODE == 2
    vec3 dayColor = vec3(0.38, 0.67, 0.88);
    vec3 nightColor = vec3(0.028, 0.025, 0.105);
#else
    vec3 dayColor = vec3(0.24, 0.47, 0.72);
    vec3 nightColor = vec3(0.012, 0.024, 0.072);
#endif
    vec3 color = mix(nightColor, dayColor, day);
    color += mix(vibeAccentA(), vibeAccentB(), 0.62) * twilight *
             0.19 * TWILIGHT_BOOST;
    return mix(color, vec3(0.19, 0.21, 0.23), rain * 0.80);
}

vec3 vibeAmbientUp(float sunHeight, float rain) {
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);
#if VIBE_MODE == 0
    vec3 daylight = vec3(0.29, 0.40, 0.55);
#elif VIBE_MODE == 1
    vec3 daylight = vec3(0.27, 0.35, 0.44);
#elif VIBE_MODE == 2
    vec3 daylight = vec3(0.25, 0.38, 0.55);
#else
    vec3 daylight = vec3(0.18, 0.30, 0.48);
#endif
    vec3 moonlight = mix(vec3(0.035, 0.050, 0.105),
                         vibeAccentA() * 0.055, 0.45);
    vec3 ambient = mix(moonlight, daylight, day);
    ambient += vibeAccentB() * twilight * 0.030 * TWILIGHT_BOOST;
    return mix(ambient, vec3(0.15, 0.17, 0.19), rain * 0.62);
}

vec3 vibeAmbientDown(float sunHeight, float rain) {
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);
#if VIBE_MODE == 0
    vec3 daylight = vec3(0.075, 0.090, 0.110);
#elif VIBE_MODE == 1
    vec3 daylight = vec3(0.080, 0.074, 0.066);
#elif VIBE_MODE == 2
    vec3 daylight = vec3(0.060, 0.075, 0.105);
#else
    vec3 daylight = vec3(0.040, 0.058, 0.095);
#endif
    vec3 nightColor = vec3(0.010, 0.014, 0.035);
    return mix(mix(nightColor, daylight, day),
               vec3(0.085, 0.090, 0.095), rain * 0.56);
}

vec3 vibeFogColor(vec3 rd, vec3 sunDir, float sunHeight, float rain) {
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);
    float up = saturate(rd.y * 0.5 + 0.5);
    float horizon = pow(1.0 - saturate(abs(rd.y)), 2.6);
    vec3 fog = mix(vibeSkyHorizon(sunHeight, rain),
                   vibeSkyZenith(sunHeight, rain), pow(up, 0.52));
    float towardSun = pow(saturate(dot(rd, sunDir)), 10.0);
    fog += vibeSunColor(sunHeight, rain) * towardSun * horizon *
           (0.09 * day + twilight * 0.48 * TWILIGHT_BOOST);
    return fog;
}

vec3 applyVibePostGrade(vec3 color, float sunHeight, float rain) {
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);
    float y = luminance(color);

#if VIBE_MODE == 0
    vec3 shadowTint = vec3(-0.005, 0.003, 0.008);
    vec3 highlightTint = vec3(0.012, 0.006, -0.005);
    float saturation = 1.08;
    float contrast = 1.02;
#elif VIBE_MODE == 1
    vec3 shadowTint = vec3(-0.008, 0.006, 0.010);
    vec3 highlightTint = vec3(0.024, 0.010, -0.010);
    float saturation = 1.12;
    float contrast = 1.04;
#elif VIBE_MODE == 2
    vec3 shadowTint = vec3(-0.010, 0.006, 0.020);
    vec3 highlightTint = vec3(0.020, 0.004, 0.006);
    float saturation = 1.16;
    float contrast = 1.04;
#else
    vec3 shadowTint = vec3(-0.010, 0.007, 0.028);
    vec3 highlightTint = vec3(0.030, 0.004, -0.012);
    float saturation = 1.15;
    float contrast = 1.06;
#endif

    float shadowWeight = 1.0 - smoothstep(0.04, 0.58, y);
    float highlightWeight = smoothstep(0.42, 2.4, y);
    color += shadowTint * shadowWeight * VIBE_INTENSITY;
    color += highlightTint * highlightWeight * VIBE_INTENSITY;
    color += vibeAccentB() * twilight * highlightWeight * 0.016 *
             VIBE_INTENSITY * TWILIGHT_BOOST;
    float shadowLift = shadowWeight * 0.014 *
                       mix(0.65, 1.0, VIBE_INTENSITY);
    color += vec3(shadowLift * 0.92, shadowLift * 0.97,
                  shadowLift * 1.06);
    color = mix(vec3(luminance(color)), color,
                mix(1.0, saturation, VIBE_INTENSITY));
    color = (color - 0.18) * mix(1.0, contrast, VIBE_INTENSITY) + 0.18;
    color = mix(color, color * vec3(0.92, 0.97, 1.03), rain * 0.18);
    return max(color, vec3(0.0));
}

#endif
