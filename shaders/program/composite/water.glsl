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
    float depthFactor = saturate(thickness / 12.0);
    vec2 refractionOffset = normalView.xy *
        mix(0.0018, 0.0105, depthFactor) * qualityScale;
    refractionOffset *= water ? 1.0 : 0.34;

#if WATER_QUALITY >= 2
    vec3 refracted = sampleChromaticRefraction(uv, refractionOffset);
#else
    vec3 refracted = sampleLayeredBackground(
        uv + refractionOffset);
#endif

    if (water) {
        float absorptionScale = mix(0.30, 0.075, WATER_CLARITY);
        vec3 absorption = vec3(0.20, 0.058, 0.025);
        vec3 transmittance = exp(-absorption * thickness *
                                 absorptionScale);
        vec3 scatter = mix(vec3(0.003, 0.034, 0.046),
                           tintData.rgb, 0.24) *
                       (vec3(1.0) - transmittance) * 1.22;
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
        refracted += vec3(0.12, 0.30, 0.25) * caustic * 0.34;
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
    reflection = mix(skyReflection, reflection, ssrConfidence);

    float f0 = water ? 0.020 : (ice ? 0.040 : 0.055);
    float fresnel = f0 + (1.0 - f0) * pow5(1.0 - nDotV);
    if (!water) fresnel = mix(fresnel, 0.62, 0.24);

#ifndef DIM_NETHER
#ifndef DIM_END
    vec3 lightDirection = normalize(
        mat3(gbufferModelViewInverse) * shadowLightPosition);
    vec3 halfVector = normalize(viewDirection +
        normalize(mat3(gbufferModelView) * lightDirection));
    float sparkle = pow(saturate(dot(normalView, halfVector)),
                        water ? 360.0 : 150.0);
    reflection += vibeSunColor(sunDirWorld.y, rainStrength) *
                  sparkle * (1.0 + rainStrength * 0.55) * 3.2;
#endif
#endif

#if WATER_QUALITY >= 2
    float shoreline = water
        ? 1.0 - smoothstep(0.08, 0.92, thickness)
        : 0.0;
    float foamNoise = valueNoise2(surfaceWorld.xz * 3.1 +
                                  frameTimeCounter * 0.16);
#if WATER_QUALITY >= 3
    foamNoise = mix(foamNoise,
                    valueNoise2(surfaceWorld.xz * 8.4 -
                                frameTimeCounter * 0.29), 0.30);
#endif
    float foam = shoreline * smoothstep(0.46, 0.69, foamNoise);
    vec3 foamColor = mix(vec3(0.56, 0.77, 0.79),
                         vibeAccentA() * 0.60, 0.16) * foam * 0.62;
#else
    float foam = 0.0;
    vec3 foamColor = vec3(0.0);
#endif

    vec3 result = mix(refracted, reflection,
                      saturate(fresnel + foam * 0.12));
    result += foamColor;

    if (water) {
        result = mix(baseScene, result, WATER_OPACITY);
    } else {
        float alpha = clamp(tintData.a, 0.12, 0.96);
        result = mix(baseScene, result, alpha);
    }
    return result;
}

