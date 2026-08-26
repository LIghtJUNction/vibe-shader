void main() {
    vec2 uv = vTexcoord;
    vec3 scene = texture(colortex0, uv).rgb;
    vec4 accumulatedLayers = texture(colortex3, uv);

    float opaqueDepth = texture(depthtex1, uv).r;
    float fullDepth = texture(depthtex0, uv).r;
    vec4 surfaceData = texture(colortex4, uv);
    vec4 tintData = texture(colortex7, uv);

    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                 sunPosition);
    vec3 moonDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                  moonPosition);
    vec3 rdWorld = viewDirectionWorld(uv,
                                      gbufferProjectionInverse,
                                      gbufferModelViewInverse);

    bool skyPixel = fullDepth >= 0.999999;
    bool translucentPixel = surfaceData.a > 0.00001 &&
                            surfaceData.b > 0.00001;
    vec3 viewPosition = skyPixel
        ? viewPositionFromDepth(uv, 1.0,
                                gbufferProjectionInverse)
        : viewPositionFromDepth(uv, fullDepth,
                                gbufferProjectionInverse);
    vec3 playerPosition = viewToPlayer(viewPosition,
                                       gbufferModelViewInverse);
    vec3 worldPosition = skyPixel
        ? cameraPosition + rdWorld * max(far, 256.0)
        : cameraPosition + playerPosition;
    float surfaceDistance = skyPixel
        ? max(far, 256.0)
        : length(viewPosition);
    float reactiveMask = translucentPixel ? 1.0 : 0.0;

    if (translucentPixel) {
        scene = resolveLayersBehindNearest(scene, tintData,
                                           accumulatedLayers);
        scene = shadeWaterOrGlass(uv, scene, surfaceData, tintData,
                                  rdWorld, sunDirWorld,
                                  moonDirWorld);
    } else {
        scene = wetSurfaceReflection(uv, scene, rdWorld,
                                     sunDirWorld, moonDirWorld);
    }

#ifndef DIM_NETHER
#ifndef DIM_END
    vec3 lightDirection = normalize(
        mat3(gbufferModelViewInverse) * shadowLightPosition);
    float sunHeight = sunDirWorld.y;
    vec3 shaftColor = vibeSunColor(sunHeight, rainStrength);
    scene += volumetricSunLight(rdWorld, surfaceDistance,
                                lightDirection, shaftColor);

    vec4 clouds = renderVoxelClouds(cameraPosition, rdWorld,
                                    surfaceDistance,
                                    sunDirWorld,
                                    frameTimeCounter,
                                    rainStrength,
                                    gl_FragCoord.xy,
                                    float(frameCounter));
    scene = scene * (1.0 - clouds.a) + clouds.rgb;
    reactiveMask = max(reactiveMask, clouds.a * 0.92);
#endif
#endif

    scene += vec3(0.56, 0.68, 0.90) *
             thunderStrength * rainStrength * 0.48;

    scene = applyEyeMedium(scene, worldPosition,
                           surfaceDistance);

    float depthNorm = skyPixel ? 1.0 :
                      saturate(surfaceDistance / max(far, 1.0));
    reactiveMask = max(reactiveMask,
                       rainStrength * 0.65 +
                       float(isEyeInWater != 0));
    scene = temporalResolve(uv, scene, worldPosition,
                            depthNorm, skyPixel, reactiveMask);
    scene = applyRainOverlay(scene);

    // Bloom is reserved for genuinely HDR energy. Ordinary sunlit terrain
    // remains diffuse and does not leak a luminous veil into its neighbors.
    float brightGate = smoothstep(1.18, 2.35, luminance(scene));
    vec3 bright = max(scene - vec3(1.05), vec3(0.0)) * 0.46;
    bright += scene * brightGate * 0.075;

    outScene = vec4(max(scene, vec3(0.0)), 1.0);
    outBloom = vec4(max(bright, vec3(0.0)), 1.0);
    outHistory = vec4(max(scene, vec3(0.0)), depthNorm);
}
