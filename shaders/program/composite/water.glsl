#include "/lib/tidal.glsl"

vec3 shadeWaterOrGlass(vec2 uv, vec3 baseScene, vec4 surfaceData,
                       vec4 tintData, vec3 rdWorld,
                       vec3 sunDirWorld, vec3 moonDirWorld) {
    float surfaceClass = floor(surfaceData.b * 8.0 + 0.5);
    bool water = abs(surfaceClass - 1.0) < 0.25;
    bool glass = abs(surfaceClass - 2.0) < 0.25;
    bool ice = abs(surfaceClass - 3.0) < 0.25;
    bool portal = abs(surfaceClass - 4.0) < 0.25;
    bool lava = abs(surfaceClass - 5.0) < 0.25;

    float translucentDepth = surfaceData.a;
    vec3 surfaceView = viewPositionFromDepth(
        uv, translucentDepth, gbufferProjectionInverse);
    vec3 surfacePlayer = viewToPlayer(surfaceView,
                                      gbufferModelViewInverse);
    vec3 surfaceWorld = surfacePlayer + cameraPosition;

    vec3 normalWorld = octDecode(surfaceData.rg);
    vec3 normalView = normalize(mat3(gbufferModelView) * normalWorld);
    vec3 viewDirection = normalize(-surfaceView);
    float nDotV = saturate(dot(normalView, viewDirection));

    float opaqueDepth = texture(depthtex1, uv).r;
    vec3 opaqueView = opaqueDepth < 0.999999
        ? viewPositionFromDepth(uv, opaqueDepth,
                                gbufferProjectionInverse)
        : surfaceView + normalize(surfaceView) * 96.0;
    float thickness = max(length(opaqueView - surfaceView), 0.0);
    float horizontalWater = water
        ? smoothstep(0.30, 0.76, abs(normalWorld.y))
        : 1.0;
    if (water) {
        // Depth-buffer thickness is invalid for a thin vertical waterfall: the
        // opaque wall can be many metres behind it. Cap only vertical sheets.
        thickness = mix(min(thickness, 0.34), thickness,
                        horizontalWater);
    }

    if (lava) {
        float cells = valueNoise2(surfaceWorld.xz * 1.65 +
                                  frameTimeCounter * 0.14);
        float veins = pow(saturate(cells - 0.34), 2.0);
        vec3 lavaColor = tintData.rgb +
                         vec3(2.8, 0.085, 0.0) * veins;
        float rim = pow5(1.0 - nDotV);
        return baseScene * 0.10 + lavaColor * (0.88 + rim * 0.22);
    }

    if (portal) {
        vec2 portalUv = surfaceWorld.xy * vec2(0.115, 0.175);
        float vortex = fbm2(portalUv +
                           vec2(frameTimeCounter * 0.085,
                               -frameTimeCounter * 0.13));
        float codeBand = 1.0 - smoothstep(
            0.02, 0.12,
            abs(fract(portalUv.y * 3.4 + vortex * 0.7) - 0.5));
        vec3 portalColor = mix(vec3(0.12, 0.008, 0.70),
                               vec3(1.65, 0.025, 3.25), vortex);
        portalColor += vibeAccentA() * codeBand * 0.42;
        portalColor += tintData.rgb * 0.35;
        float rim = pow5(1.0 - nDotV);
        return baseScene * 0.18 + portalColor * (0.78 + rim * 0.62);
    }

    float qualityScale = WATER_QUALITY == 0 ? 0.20 :
                         (WATER_QUALITY == 1 ? 0.52 :
                         (WATER_QUALITY == 2 ? 0.92 : 1.20));
    float depthFactor = saturate(thickness / 9.0);
    vec2 refractionOffset = normalView.xy *
        mix(0.0007, 0.0042, depthFactor) * qualityScale;
    refractionOffset *= water ? 1.0 : 0.34;

#if WATER_QUALITY >= 2
    vec3 refracted = water
        ? sampleLayeredBackground(uv + refractionOffset)
        : sampleChromaticRefraction(uv, refractionOffset);
#else
    vec3 refracted = sampleLayeredBackground(uv + refractionOffset);
#endif

    if (water) {
        float absorptionScale = mix(0.42, 0.12, WATER_CLARITY);
        vec3 absorption = vec3(0.28, 0.090, 0.040);
        vec3 transmittance = exp(-absorption * thickness *
                                 absorptionScale);
        vec3 scatter = mix(vec3(0.002, 0.018, 0.024),
                           tintData.rgb, 0.08) *
                       (vec3(1.0) - transmittance) * 0.62;
        refracted = refracted * transmittance + scatter;

#if WATER_QUALITY >= 2
        float causticA = sin(surfaceWorld.x * 2.35 +
                             frameTimeCounter * 1.22) *
                          sin(surfaceWorld.z * 2.05 -
                              frameTimeCounter * 1.05);
        float causticB = sin((surfaceWorld.x + surfaceWorld.z) * 3.4 -
                             frameTimeCounter * 1.64);
        float caustic = pow(saturate(causticA * 0.42 +
                                     causticB * 0.18 + 0.42), 5.0);
        caustic *= exp(-thickness * 0.16) *
                   saturate(sunDirWorld.y * 3.0 + 0.2);
        refracted += vec3(0.10, 0.25, 0.21) * caustic * 0.12;
#endif
    } else {
        vec3 glassTint = clamp(tintData.rgb * 1.12,
                               vec3(0.035), vec3(1.0));
        float tintStrength = ice
            ? 0.55
            : clamp(0.24 + tintData.a * 0.92, 0.24, 0.90);
        refracted *= mix(vec3(1.0), glassTint, tintStrength);
    }

    vec3 incidentView = normalize(surfaceView);
    vec3 reflectedView = reflect(incidentView, normalView);
    float ssrConfidence;
    vec2 hitUv;
    vec3 reflection = traceScreenReflection(
        surfaceView + normalView * 0.075,
        reflectedView, ssrConfidence, hitUv);

    vec3 reflectedWorld = reflect(rdWorld, normalWorld);
    vec3 skyReflection = renderDimensionSky(reflectedWorld,
                                             sunDirWorld,
                                             moonDirWorld);
    if (water) ssrConfidence *= mix(0.12, 0.52,
                                     horizontalWater);
    reflection = mix(skyReflection, reflection, ssrConfidence);

    float f0 = water ? 0.018 : (ice ? 0.040 : 0.055);
    float fresnel = f0 + (1.0 - f0) * pow5(1.0 - nDotV);
    if (water) fresnel *= mix(0.16, 0.72, horizontalWater);
    else fresnel = mix(fresnel, 0.62, 0.24);

#ifndef DIM_NETHER
#ifndef DIM_END
    vec3 lightDirection = normalize(
        mat3(gbufferModelViewInverse) * shadowLightPosition);
    vec3 halfVector = normalize(viewDirection +
        normalize(mat3(gbufferModelView) * lightDirection));
    float sparkle = pow(saturate(dot(normalView, halfVector)),
                        water ? 240.0 : 150.0);
    reflection += vibeSunColor(sunDirWorld.y, rainStrength) *
                  sparkle * (1.0 + rainStrength * 0.35) *
                  (water ? 0.90 * horizontalWater : 2.20);
#endif
#endif

#if WATER_QUALITY >= 2
    float shoreline = water
        ? 1.0 - smoothstep(0.035, 0.34, thickness)
        : 0.0;
    float foamNoise = valueNoise2(surfaceWorld.xz * 3.1 +
                                  frameTimeCounter * 0.16);
#if WATER_QUALITY >= 3
    foamNoise = mix(foamNoise,
                    valueNoise2(surfaceWorld.xz * 8.4 -
                                frameTimeCounter * 0.29), 0.30);
#endif
    float foam = shoreline * horizontalWater *
                 smoothstep(0.64, 0.80, foamNoise);
    vec3 foamColor = mix(vec3(0.56, 0.72, 0.72),
                         vibeAccentA() * 0.42, 0.10) * foam * 0.20;
#else
    float foam = 0.0;
    vec3 foamColor = vec3(0.0);
#endif

    vec3 result = mix(refracted, reflection,
                      saturate(fresnel + foam * 0.12));
    result += foamColor;
    if (water) {
        result += tidalRadiance(surfaceWorld, thickness, horizontalWater,
                                 length(surfaceView), sunDirWorld.y,
                                 frameTimeCounter);
    }

    if (water) {
        result = mix(baseScene, result,
                     clamp(tintData.a, 0.0, 1.0));
    } else {
        float alpha = clamp(tintData.a, 0.12, 0.96);
        result = mix(baseScene, result, alpha);
    }
    return result;
}

