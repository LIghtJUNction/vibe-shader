#ifndef VIBE_SHADER_VISION
#define VIBE_SHADER_VISION

// Human-vision simulation lives in final.fsh so it never contaminates TAA
// history and never blurs Minecraft's HUD, which is drawn afterwards.
const vec2 VISION_BLUR_KERNEL[4] = vec2[4](
    vec2(-0.326, -0.406),
    vec2(-0.696,  0.457),
    vec2( 0.962, -0.195),
    vec2( 0.519,  0.767)
);

float visionLinearDepth(float depth) {
    float z = depth * 2.0 - 1.0;
    return (2.0 * near * far) /
           max(far + near - z * (far - near), 1e-5);
}

float visionDaylight(float sunHeight) {
#if defined(DIM_NETHER) || defined(DIM_END)
    return 0.58;
#else
    return smoothstep(-0.10, 0.24, sunHeight);
#endif
}

// x: low health, y: hunger, z: acute injury/status impairment, w: night.
vec4 visionState(float sunHeight) {
    float health = currentPlayerHealth < 0.0
        ? 1.0 : saturate(currentPlayerHealth);
    float hunger = currentPlayerHunger < 0.0
        ? 1.0 : saturate(currentPlayerHunger);
    float lowHealth = 1.0 - smoothstep(0.16, 0.52, health);
    float hungerStress = 1.0 - smoothstep(0.10, 0.42, hunger);
    float injury = float(is_hurt) *
        (0.82 + 0.18 * sin(frameTimeCounter * 7.2));
    float statusImpairment = max(blindness, darknessFactor);
    float acute = max(injury, statusImpairment);
    float night = (1.0 - visionDaylight(sunHeight)) *
                  (1.0 - nightVision * 0.94);
    return saturate(vec4(lowHealth, hungerStress, acute, night));
}

vec2 applyVisionDizziness(vec2 uv, vec4 state) {
#ifndef SURVIVAL_VISION
    return uv;
#else
    float dizziness = state.y * 0.52 + state.z * 0.86;
    vec2 motion = vec2(
        sin(frameTimeCounter * 1.37) +
            sin(frameTimeCounter * 0.43) * 0.35,
        cos(frameTimeCounter * 1.09) +
            sin(frameTimeCounter * 0.61) * 0.30
    );
    vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);
    return saturate(uv + motion * pixel * dizziness *
                    SURVIVAL_EFFECT_STRENGTH);
#endif
}

vec3 applyDepthAwareVisionBlur(vec2 uv, vec3 centerColor,
                               vec4 state) {
    float centerDepth = texture(depthtex0, uv).r;
    float centerDistance = visionLinearDepth(centerDepth);
    float blurAmount = 0.0;

#ifdef DISTANT_BLUR
    float focusStart = VISION_FOCUS_DISTANCE * 0.58;
    float focusEnd = VISION_FOCUS_DISTANCE * 1.85;
    float distanceBlur = smoothstep(focusStart, focusEnd,
                                    centerDistance);
    blurAmount += distanceBlur * DISTANT_BLUR_STRENGTH *
                  (0.76 + state.w * 0.54);
#endif

#ifdef SURVIVAL_VISION
    vec2 centered = uv - 0.5;
    float peripheral = smoothstep(0.08, 0.68,
                                  length(centered));
    float physiological = state.x * (0.34 + peripheral * 0.30) +
                          state.y * (0.12 + peripheral * 0.14) +
                          state.z * (0.36 + peripheral * 0.26) +
                          state.w * (0.12 + peripheral * 0.16);
    physiological += max(blindness, darknessFactor) * 0.34;
    blurAmount += physiological * SURVIVAL_EFFECT_STRENGTH;
#endif

    blurAmount = saturate(blurAmount);
    if (blurAmount < 0.008) return centerColor;

    vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);
    float radius = 0.35 + blurAmount * 4.25;
    vec3 mipCenter = textureLod(colortex0, uv,
                                blurAmount * 1.55).rgb;
    vec3 sum = mix(centerColor, mipCenter, 0.72) * 1.20;
    float totalWeight = 1.20;

    // Four depth-aware taps plus the scene mip replace the old eight-tap
    // kernel. Silhouettes remain protected while bandwidth drops sharply.
    for (int i = 0; i < 4; ++i) {
        vec2 tapUv = saturate(
            uv + VISION_BLUR_KERNEL[i] * pixel * radius);
        float tapDepth = texture(depthtex0, tapUv).r;
        float tapDistance = visionLinearDepth(tapDepth);
        float relativeDepth = abs(tapDistance - centerDistance) /
            max(centerDistance * 0.30, 3.0);
        float depthWeight = exp2(-relativeDepth * relativeDepth * 5.0);
        float weight = depthWeight * 0.92;
        sum += textureLod(colortex0, tapUv,
                          blurAmount * 0.80).rgb * weight;
        totalWeight += weight;
    }

    vec3 blurred = sum / max(totalWeight, 1e-4);
    return mix(centerColor, blurred, blurAmount * 0.86);
}

vec3 ocularAstigmatism(vec2 uv, float night) {
#ifndef OCULAR_ASTIGMATISM
    return vec3(0.0);
#else
    vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);
    vec2 primary = normalize(vec2(1.0, 0.26));
    vec3 seed = textureLod(colortex3, uv, 2.0).rgb;
    if (luminance(seed) < 0.012) return vec3(0.0);

    vec3 streak = seed * 0.72;
    float totalWeight = 0.72;
    for (int i = 1; i <= 3; ++i) {
        float f = float(i);
        float weight = 1.0 / (1.0 + f * 0.68);
        vec2 longOffset = primary * pixel * f * f * 2.35;
        streak += textureLod(colortex3,
            saturate(uv + longOffset), 2.0).rgb * weight;
        streak += textureLod(colortex3,
            saturate(uv - longOffset), 2.0).rgb * weight;
        totalWeight += weight * 2.0;
    }

    float strength = ASTIGMATISM_STRENGTH *
                     mix(0.060, 0.112, night);
    return streak / max(totalWeight, 1e-4) * strength;
#endif
}

vec3 applyAdaptiveVisionMood(vec3 color, float sunHeight,
                             vec4 state, vec2 lightmapValue) {
    float y = luminance(color);
    float blockLight = saturate((lightmapValue.x - 0.03) / 0.94);
    float skyLight = saturate((lightmapValue.y - 0.03) / 0.94);
    float daylight = visionDaylight(sunHeight);
#if defined(DIM_NETHER) || defined(DIM_END)
    float rainMood = 0.0;
    float clearDay = 0.0;
#else
    float rainMood = saturate(rainStrength + thunderStrength * 0.35);
    float clearDay = daylight * (1.0 - rainMood);
#endif

    // Clear daylight has a warm illuminant; rain loses saturation and warmth.
    vec3 warmDay = color * vec3(1.055, 1.015, 0.950);
    color = mix(color, warmDay, clearDay * 0.44);
    vec3 overcast = mix(vec3(y), color, 0.64) *
                    vec3(0.86, 0.94, 1.045);
    color = mix(color, overcast, rainMood * 0.72);

    // Scotopic night vision loses color and fine contrast. Night Vision potion
    // is already folded into state.w and therefore restores acuity.
    vec3 nightColor = mix(vec3(y), color, 0.72) *
                      vec3(0.82, 0.90, 1.025) * 0.92;
    color = mix(color, nightColor, state.w * 0.42);

#ifdef SURVIVAL_VISION
    float shelteredWarmth = smoothstep(0.26, 0.88, blockLight) *
                            mix(0.42, 1.0, state.w) *
                            (1.0 - rainMood * 0.32);
    float exposedDark = state.w *
                        (1.0 - smoothstep(0.10, 0.52, blockLight)) *
                        (1.0 - skyLight * 0.28);
    float horror = saturate(exposedDark * 0.68 +
                            state.x * 0.62 +
                            state.z * 0.52 +
                            state.y * 0.18);

    // Darkness, injury and exposure drain warmth and separate the blacks.
    // A real block-light source reverses that response into a warm shelter.
    float horrorLuma = luminance(color);
    vec3 horrorColor = mix(vec3(horrorLuma), color, 0.60) *
                       vec3(0.78, 0.88, 0.92) * 0.84;
    color = mix(color, horrorColor,
                horror * 0.48 * SURVIVAL_EFFECT_STRENGTH);

    vec3 cozyColor = color * vec3(1.12, 1.025, 0.90) +
                     vec3(0.015, 0.008, 0.002);
    color = mix(color, cozyColor,
                shelteredWarmth * 0.48 * SURVIVAL_EFFECT_STRENGTH);
#endif

    // Separate similar mid-tones without changing their luminance hierarchy.
    float finalLuma = luminance(color);
    float chromaRange = max(color.r, max(color.g, color.b)) -
                        min(color.r, min(color.g, color.b));
    float richness = mix(1.16, 1.08,
                         smoothstep(0.025, 0.30, chromaRange));
    color = vec3(finalLuma) + (color - vec3(finalLuma)) * richness;
    return max(color, vec3(0.0));
}

float physiologicalVignette(vec2 centered, vec4 state) {
#ifndef SURVIVAL_VISION
    return 1.0;
#else
    float edge = smoothstep(0.14, 0.72, length(centered));
    float heartbeat = 0.5 + 0.5 * sin(frameTimeCounter * 6.35);
    float loss = state.x * (0.19 + heartbeat * 0.10) +
                 state.z * (0.10 + heartbeat * 0.07) +
                 state.y * 0.045 + state.w * 0.050;
    return 1.0 - edge * loss * SURVIVAL_EFFECT_STRENGTH;
#endif
}

#endif
