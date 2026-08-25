vec3 applyEyeMedium(vec3 scene, vec3 worldPosition,
                    float distanceToSurface) {
    if (isEyeInWater == 1) {
        float caustic = sin(worldPosition.x * 2.6 +
                            frameTimeCounter * 1.7) *
                         sin(worldPosition.z * 2.2 -
                             frameTimeCounter * 1.3);
        caustic = pow(saturate(caustic * 0.5 + 0.5), 4.0);
        scene += vec3(0.045, 0.18, 0.16) * caustic * 0.18;
        float fog = 1.0 - exp(-distanceToSurface * 0.028);
        vec3 underwaterFog = mix(vec3(0.006, 0.042, 0.052),
                                 vec3(0.010, 0.070, 0.080),
                                 WATER_CLARITY);
        scene = mix(scene, underwaterFog, saturate(fog) * 0.88);
    } else if (isEyeInWater == 2) {
        float fog = 1.0 - exp(-distanceToSurface * 0.25);
        scene = mix(scene, vec3(1.4, 0.12, 0.005),
                    saturate(fog));
        scene += vec3(2.0, 0.22, 0.008) * 0.25;
    } else if (isEyeInWater == 3) {
        float fog = 1.0 - exp(-distanceToSurface * 0.12);
        scene = mix(scene, vec3(0.72, 0.79, 0.86),
                    saturate(fog));
    }
    return scene;
}

vec3 temporalResolve(vec2 uv, vec3 currentColor,
                     vec3 worldPosition, float currentDepthNorm,
                     bool skyPixel, float reactiveMask) {
#ifndef TAA_ENABLED
    return currentColor;
#else
    // Water, glass, foliage motion, weather and moving clouds need a reactive
    // path. Reusing their history caused the block-shaped trails seen in 0.1.x.
    if (reactiveMask > 0.02 || isEyeInWater != 0) return currentColor;

    vec3 previousPlayer = worldPosition - previousCameraPosition;
    vec3 previousView = (gbufferPreviousModelView *
                         vec4(previousPlayer,
                              skyPixel ? 0.0 : 1.0)).xyz;

    if (skyPixel) {
        previousView = mat3(gbufferPreviousModelView) *
                       normalize(worldPosition - cameraPosition) *
                       1000.0;
    }

    vec4 previousClip = gbufferPreviousProjection *
                        vec4(previousView, 1.0);
    if (previousClip.w <= 0.0 || frameCounter < 2) {
        return currentColor;
    }

    vec2 previousUv = previousClip.xy / previousClip.w * 0.5 + 0.5;
    if (any(lessThanEqual(previousUv, vec2(0.002))) ||
        any(greaterThanEqual(previousUv, vec2(0.998)))) {
        return currentColor;
    }

    vec4 history = texture(colortex6, previousUv);
    float predictedDepth = skyPixel
        ? 1.0
        : saturate(length(previousView) / max(far, 1.0));
    float depthError = abs(history.a - predictedDepth);
    float allowedError = skyPixel ? 0.035 :
                         (0.006 + predictedDepth * 0.018);
    if (depthError > allowedError) return currentColor;

    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 n0 = texture(colortex0, saturate(uv + vec2(px.x, 0.0))).rgb;
    vec3 n1 = texture(colortex0, saturate(uv - vec2(px.x, 0.0))).rgb;
    vec3 n2 = texture(colortex0, saturate(uv + vec2(0.0, px.y))).rgb;
    vec3 n3 = texture(colortex0, saturate(uv - vec2(0.0, px.y))).rgb;

    vec3 neighborhoodMin = min(currentColor,
        min(min(n0, n1), min(n2, n3))) - 0.055;
    vec3 neighborhoodMax = max(currentColor,
        max(max(n0, n1), max(n2, n3))) + 0.075;
    vec3 clampedHistory = clamp(history.rgb,
                                neighborhoodMin,
                                neighborhoodMax);

    float motion = length(previousUv - uv);
    float stability = MOTION_STABILITY * exp(-motion * 92.0);
    stability *= skyPixel ? 0.72 : 1.0;
    return mix(currentColor, clampedHistory,
               saturate(stability));
#endif
}

