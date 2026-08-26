#ifndef VIBE_SHADER_CLOUDS
#define VIBE_SHADER_CLOUDS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/vibe.glsl"

#if CLOUD_QUALITY == 0
    #define CLOUD_STEPS 0
#elif CLOUD_QUALITY == 1
    #define CLOUD_STEPS 6
#elif CLOUD_QUALITY == 2
    #define CLOUD_STEPS 12
#else
    #define CLOUD_STEPS 18
#endif

float fastCloudFbm(vec3 p) {
    return valueNoise3(p) * 0.68 +
           valueNoise3(p * 2.07 + vec3(7.1, 3.8, 5.4)) * 0.32;
}

float cloudHeightShape(float worldY) {
    const float cloudBottom = 108.0;
    const float cloudTop = 176.0;
    float h = saturate((worldY - cloudBottom) /
                       (cloudTop - cloudBottom));
    return smoothstep(0.0, 0.11, h) *
           (1.0 - smoothstep(0.72, 1.0, h));
}

float coarseCloudDensity(vec3 worldPos, float time, float rain) {
    vec3 wind = vec3(time * 0.72, 0.0, time * 0.24);
    vec3 p = (worldPos + wind) * vec3(0.0088, 0.015, 0.0088);
    float broad = valueNoise3(p * 0.82);
    float detail = valueNoise3(p * 1.91 + vec3(4.7, 8.2, 2.9));
    float shape = broad * 0.76 + detail * 0.24;
    float coverage = CLOUD_COVERAGE - rain * 0.12;
    return smoothstep(coverage - 0.025, coverage + 0.17, shape) *
           cloudHeightShape(worldPos.y);
}

float voxelCloudDensity(vec3 worldPos, float time, float rain) {
    float heightShape = cloudHeightShape(worldPos.y);

    vec3 wind = vec3(time * 0.72, 0.0, time * 0.24);
    vec3 p = (worldPos + wind) * vec3(0.0088, 0.015, 0.0088);

    float broad = fastCloudFbm(p * 0.82);
    float billow = 1.0 - abs(valueNoise3(p * 2.15) * 2.0 - 1.0);
    vec3 voxelP = floor(p * 38.0) / 38.0;
    float voxelDetail = hash13(floor(voxelP * 190.0) + 9.4);
    float erosion = valueNoise3(p * 3.6 + vec3(12.0, 4.0, 8.0));

    float shape = broad * 0.64 + billow * 0.22 +
                  voxelDetail * 0.12 - erosion * 0.10;
    float coverage = CLOUD_COVERAGE - rain * 0.12;
    float density = smoothstep(coverage, coverage + 0.13, shape);

    float baseNoise = valueNoise2(worldPos.xz * 0.016 +
                                  vec2(time * 0.013, -time * 0.008));
    density *= mix(0.72, 1.15, baseNoise);
    density *= heightShape;
    return saturate(density);
}

vec4 renderVoxelClouds(vec3 cameraWorld, vec3 rdWorld,
                       float maxDistance, vec3 sunDirWorld,
                       float time, float rain, vec2 fragCoord,
                       float frameIndex) {
#if CLOUD_STEPS == 0
    return vec4(0.0);
#else
    const float cloudBottom = 108.0;
    const float cloudTop = 176.0;

    float safeY = abs(rdWorld.y) < 1e-5
        ? (rdWorld.y < 0.0 ? -1e-5 : 1e-5)
        : rdWorld.y;
    float invY = 1.0 / safeY;
    float t0 = (cloudBottom - cameraWorld.y) * invY;
    float t1 = (cloudTop - cameraWorld.y) * invY;
    if (t0 > t1) {
        float tmp = t0;
        t0 = t1;
        t1 = tmp;
    }
    t0 = max(t0, 0.0);
    t1 = min(t1, maxDistance);
    if (t1 <= t0) return vec4(0.0);

    float jitter = interleavedGradientNoise(fragCoord, frameIndex);
    float stepLength = (t1 - t0) / float(CLOUD_STEPS);
    float t = t0 + stepLength * jitter;

    float sunHeight = sunDirWorld.y;
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);
    vec3 ambientTop = vibeSkyHorizon(sunHeight, rain) * 0.72 +
                      vibeSkyZenith(sunHeight, rain) * 0.38;
    vec3 ambientBottom = mix(vec3(0.035, 0.045, 0.065),
                             vec3(0.14, 0.16, 0.18), day);
    vec3 sunColor = vibeSunColor(sunHeight, rain);

    float forward = pow(saturate(dot(rdWorld, sunDirWorld)), 12.0);
    float backward = pow(saturate(dot(rdWorld, -sunDirWorld)), 3.0);

    vec3 accumColor = vec3(0.0);
    float transmittance = 1.0;

    for (int i = 0; i < CLOUD_STEPS; ++i) {
        vec3 p = cameraWorld + rdWorld * t;
        float density = voxelCloudDensity(p, time, rain);
        if (density > 0.001) {
            float sunProbe = coarseCloudDensity(
                p + sunDirWorld * 14.0, time, rain);
            float selfShadow = exp(-sunProbe * 3.25);
            float h = saturate((p.y - cloudBottom) /
                               (cloudTop - cloudBottom));
            vec3 ambient = mix(ambientBottom, ambientTop,
                               smoothstep(0.08, 0.82, h));

            float powder = 1.0 - exp(-density * 4.8);
            float silver = selfShadow *
                (0.25 + forward * 2.4 + backward * 0.18);
            vec3 lighting = ambient * (0.58 + powder * 0.30) +
                            sunColor * silver * day;
            lighting += vibeAccentB() * twilight *
                        forward * 0.055;

            float alpha = 1.0 - exp(-density * stepLength * 0.082);
            vec3 sampleColor = lighting *
                               (0.58 + density * 0.46);
            accumColor += transmittance * sampleColor * alpha;
            transmittance *= 1.0 - alpha;
            if (transmittance < 0.012) break;
        }
        t += stepLength;
    }

    return vec4(accumColor, 1.0 - transmittance);
#endif
}

float cloudShadowAt(vec3 worldPos, float time, float rain) {
#if CLOUD_STEPS == 0
    return 1.0;
#else
    vec2 p = (worldPos.xz + vec2(time * 0.72,
                                 time * 0.24)) * 0.0088;
    float broad = valueNoise2(p * 0.82);
    float detail = valueNoise2(p * 2.05 + 8.0);
    float cloud = broad * 0.72 + detail * 0.28;
    float coverage = CLOUD_COVERAGE - rain * 0.12;
    float shadow = smoothstep(coverage - 0.02,
                              coverage + 0.11, cloud);
    return mix(1.0, 0.48, shadow);
#endif
}

#endif
