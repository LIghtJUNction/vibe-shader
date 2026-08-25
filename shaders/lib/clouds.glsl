#ifndef VIBE_SHADER_CLOUDS
#define VIBE_SHADER_CLOUDS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#if CLOUD_QUALITY == 0
    #define CLOUD_STEPS 0
#elif CLOUD_QUALITY == 1
    #define CLOUD_STEPS 8
#elif CLOUD_QUALITY == 2
    #define CLOUD_STEPS 14
#else
    #define CLOUD_STEPS 22
#endif

float voxelCloudDensity(vec3 worldPos, float time, float rain) {
    const float cloudBottom = 116.0;
    const float cloudTop = 174.0;
    float h = saturate((worldPos.y - cloudBottom) / (cloudTop - cloudBottom));
    float heightShape = smoothstep(0.0, 0.14, h) *
                        (1.0 - smoothstep(0.68, 1.0, h));

    vec3 wind = vec3(time * 0.82, 0.0, time * 0.31);
    vec3 p = (worldPos + wind) * vec3(0.011, 0.019, 0.011);

    // Slight quantization keeps the clouds recognisably voxel-like.
    vec3 blockP = floor(p * 34.0) / 34.0;
    float broad = fbm3(p * 0.72);
    float detail = valueNoise3(blockP * 5.2);
    float erosion = valueNoise3(p * 9.0 + 17.0);

    float coverage = CLOUD_COVERAGE - rain * 0.13;
    float shape = broad * 0.78 + detail * 0.22 - erosion * 0.11;
    return smoothstep(coverage, coverage + 0.17, shape) * heightShape;
}

vec4 renderVoxelClouds(vec3 cameraWorld, vec3 rdWorld, float maxDistance,
                       vec3 sunDirWorld, float time, float rain,
                       vec2 fragCoord, float frameIndex) {
#if CLOUD_STEPS == 0
    return vec4(0.0);
#else
    const float cloudBottom = 116.0;
    const float cloudTop = 174.0;

    float invY = 1.0 / (abs(rdWorld.y) < 1e-5 ?
                       (rdWorld.y < 0.0 ? -1e-5 : 1e-5) : rdWorld.y);
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

    vec3 accumColor = vec3(0.0);
    float transmittance = 1.0;
    float sunUp = saturate(sunDirWorld.y * 4.0 + 0.35);
    vec3 ambientColor = mix(vec3(0.055, 0.075, 0.14),
                            vec3(0.44, 0.58, 0.78), sunUp);
    vec3 sunColor = mix(vec3(0.18, 0.27, 0.58),
                        vec3(1.20, 0.80, 0.48), sunUp);

    for (int i = 0; i < CLOUD_STEPS; ++i) {
        vec3 p = cameraWorld + rdWorld * t;
        float density = voxelCloudDensity(p, time, rain);
        if (density > 0.001) {
            float sunProbe = voxelCloudDensity(p + sunDirWorld * 7.0, time, rain);
            float selfShadow = exp(-sunProbe * 3.2);
            float powder = 1.0 - exp(-density * 5.0);
            vec3 lighting = ambientColor +
                            sunColor * selfShadow * (0.35 + 0.65 * sunUp);
            lighting += vec3(0.24, 0.31, 0.46) * powder * 0.20;

            float alpha = 1.0 - exp(-density * stepLength * 0.095);
            vec3 sampleColor = lighting * (0.65 + 0.35 * density);
            accumColor += transmittance * sampleColor * alpha;
            transmittance *= 1.0 - alpha;
            if (transmittance < 0.015) break;
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
    vec2 p = (worldPos.xz + vec2(time * 0.82, time * 0.31)) * 0.011;
    float cloud = fbm2(p * 0.72);
    float coverage = CLOUD_COVERAGE - rain * 0.13;
    return mix(1.0, 0.54, smoothstep(coverage, coverage + 0.12, cloud));
#endif
}

#endif
