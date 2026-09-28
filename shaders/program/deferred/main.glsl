void main() {
    float depth = texture(depthtex1, vTexcoord).r;
    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                 sunPosition);
    vec3 moonDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                  moonPosition);
    vec3 rdWorld = viewDirectionWorld(vTexcoord,
                                      gbufferProjectionInverse,
                                      gbufferModelViewInverse);

    vec3 color;
    if (depth >= 0.999999) {
        color = renderDimensionSky(rdWorld, sunDirWorld, moonDirWorld);
    } else {
        vec4 albedoData = texture(colortex0, vTexcoord);
        vec4 normalData = texture(colortex1, vTexcoord);
        vec4 materialData = texture(colortex2, vTexcoord);

        vec3 viewPosition =
            viewPositionFromDepth(vTexcoord, depth,
                                  gbufferProjectionInverse);
        vec3 playerPosition =
            viewToPlayer(viewPosition, gbufferModelViewInverse);
        vec3 worldPosition = playerPosition + cameraPosition;

        vec3 worldNormal =
            normalize(normalData.rgb * 2.0 - 1.0);
        float materialId = decodeMaterial(materialData.a);

        color = shadeSurface(vTexcoord, albedoData.rgb, worldNormal,
                             normalData.a, materialData.rg,
                             materialData.b, materialId,
                             viewPosition, worldPosition);

        float distanceToCamera = length(viewPosition);
#ifdef DIM_NETHER
        float fogAmount = 1.0 - exp(-distanceToCamera * 0.024);
        vec3 fogColor = renderDimensionFog(rdWorld, sunDirWorld);
#elif defined DIM_END
        float fogAmount = 1.0 - exp(-distanceToCamera * 0.0058);
        vec3 fogColor = renderDimensionFog(rdWorld, sunDirWorld);
#else
        float normalizedDistance = distanceToCamera / max(far, 1.0);
        float clearDensity = 0.68 + rainStrength * 1.58;
        float distanceFog = 1.0 - exp(
            -pow(normalizedDistance * 1.22, 1.92) *
             clearDensity * ATMOSPHERE_DENSITY);
        float valley = exp(-max(worldPosition.y - 58.0, 0.0) / 42.0);
        float lowMist = (1.0 - exp(-distanceToCamera * 0.0052)) *
                        valley * (0.085 + rainStrength * 0.15) *
                        ATMOSPHERE_DENSITY;
        float fogAmount = min(distanceFog + lowMist,
                              mix(0.88, 0.97, rainStrength));
        vec3 fogColor = vibeFogColor(rdWorld, sunDirWorld,
                                     sunDirWorld.y, rainStrength);
#endif
        color = mix(color, fogColor, saturate(fogAmount));
    }

    outScene = vec4(color, 1.0);
    outOpaqueCopy = vec4(color, 1.0);
}
