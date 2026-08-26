vec3 shadeSurface(vec2 uv, vec3 albedo, vec3 worldNormal,
                  float roughness, vec2 lightmapValue,
                  float emissionMask, float materialId,
                  vec3 viewPosition, vec3 worldPosition) {
    vec3 normal = roundedVoxelNormal(uv, viewPosition,
                                     worldNormal, materialId);
    vec3 viewDirection = normalize(cameraPosition - worldPosition);
    vec3 viewNormal = normalize(mat3(gbufferModelView) * normal);

    float blockLight = saturate((lightmapValue.x - 0.03) / 0.94);
    float skyLight = saturate((lightmapValue.y - 0.03) / 0.94);
    blockLight = pow(blockLight, 1.45);

    float baseLuma = luminance(albedo);
    albedo *= mix(0.98, 1.04, smoothstep(0.025, 0.52, baseLuma));

    float ao = mix(0.42, 1.0,
                   screenSpaceAO(uv, viewPosition, viewNormal));
    vec3 ambient = dimensionAmbient(normal, skyLight);
    vec3 warmBlockLight = vec3(1.08, 0.72, 0.40) *
        blockLight * 1.24;

    vec3 direct = vec3(0.0);
    vec3 specular = vec3(0.0);

#ifndef DIM_NETHER
#ifndef DIM_END
    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                 sunPosition);
    vec3 moonDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                  moonPosition);
    vec3 lightDirWorld =
        normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    float sunHeight = sunDirWorld.y;
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);
    vec3 moonlight = vec3(0.16, 0.27, 0.56) *
                     mix(1.0, 0.72, rainStrength);
    vec3 daylight = mix(moonlight,
                        vibeSunColor(sunHeight, rainStrength), day);
    daylight += vibeAccentB() * twilight *
                0.065 * TWILIGHT_BOOST;

    float rawNdotL = saturate(dot(normal, lightDirWorld));
    float wrappedNdotL = saturate((rawNdotL + 0.12) / 1.12);
    float nDotL = mix(rawNdotL, wrappedNdotL,
                      roughness * 0.38);
    vec3 shadow = softShadowAt(worldPosition, normal, lightDirWorld,
                               cameraPosition, shadowModelView,
                               shadowProjection, shadowtex0,
                               shadowtex1, shadowcolor0,
                               gl_FragCoord.xy, float(frameCounter));

    float cloudShade = cloudShadowAt(worldPosition, frameTimeCounter,
                                     rainStrength);
    shadow *= mix(1.0, cloudShade, day * 0.78);
    direct = daylight * nDotL * shadow *
             mix(0.10, 1.0, skyLight);

    float wetSurface = wetness *
        smoothstep(0.48, 0.94, normal.y) *
        (1.0 - float(materialEquals(materialId, MAT_LEAVES)));
    roughness = mix(roughness, 0.22, wetSurface * 0.60);
    albedo *= mix(1.0, 0.76, wetSurface * 0.46);

    vec3 halfVector = normalize(viewDirection + lightDirWorld);
    float nDotH = saturate(dot(normal, halfVector));
    float nDotV = saturate(dot(normal, viewDirection));
    float exponent = mix(96.0, 2.0, pow(roughness, 0.72));
    float distribution = pow(nDotH, exponent) *
                         (exponent + 2.0) / (TAU + 1e-4);
    bool metal = materialEquals(materialId, MAT_METAL);
    bool reflective = metal || materialEquals(materialId, MAT_ICE);
    vec3 f0 = metal ? mix(vec3(0.10), albedo, 0.74) :
                      vec3(mix(0.012, 0.024, wetSurface));
    vec3 fresnel = f0 + (1.0 - f0) * pow5(1.0 - nDotV);
    float specularScale = metal ? 0.92 :
                          mix(0.10, 0.30, wetSurface);
    specular = daylight * distribution * fresnel *
               nDotL * shadow * mix(0.18, 1.0, skyLight) *
               specularScale;
    float rim = pow5(1.0 - nDotV) * skyLight;
    float rimResponse = max(float(reflective), wetSurface * 0.35);
    specular += mix(vibeAccentA(), vec3(0.36, 0.50, 0.78), day) *
                rim * (0.010 + twilight * 0.016) *
                rimResponse * VIBE_INTENSITY;

    // Held torches and lanterns act as a cheap camera-local point light.
    float heldLight = float(max(heldBlockLightValue,
                                heldBlockLightValue2)) / 15.0;
    float cameraDistance = length(worldPosition - cameraPosition);
    vec3 toCamera = normalize(cameraPosition - worldPosition);
    float heldDiffuse = saturate(dot(normal, toCamera));
    warmBlockLight += vec3(1.48, 0.82, 0.34) *
        heldLight * heldLight *
                      exp(-cameraDistance * 0.16) *
                      (0.25 + 0.75 * heldDiffuse) * 6.0;
#else
    vec3 pseudoLight = normalize(vec3(-0.35, 0.82, 0.44));
    float diffuse = 0.22 + 0.78 * saturate(dot(normal, pseudoLight));
    direct = vec3(0.11, 0.05, 0.26) * diffuse;
#endif
#else
    vec3 pseudoLight = normalize(vec3(0.28, 0.72, -0.61));
    float diffuse = 0.25 + 0.75 * saturate(dot(normal, pseudoLight));
    direct = vec3(0.42, 0.045, 0.008) * diffuse;
#endif

    vec3 emission = materialEmissionColor(materialId, albedo,
                                          emissionMask, worldPosition,
                                          normal, viewDirection);

    vec3 color = albedo * (ambient * ao + warmBlockLight + direct) +
                 specular + emission;

    color = mix(color, color * vec3(0.45, 0.70, 0.36) + vec3(0.03),
                nightVision * 0.72);
    color *= 1.0 - blindness;
    return max(color, vec3(0.0));
}

