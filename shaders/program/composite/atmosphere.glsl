vec3 wetSurfaceReflection(vec2 uv, vec3 scene,
                          vec3 rdWorld,
                          vec3 sunDirWorld, vec3 moonDirWorld) {
#if SSR_STEPS == 0
    return scene;
#else
    if (wetness < 0.08) return scene;

    float depth = texture(depthtex1, uv).r;
    if (depth >= 0.999999) return scene;

    vec4 normalData = texture(colortex1, uv);
    vec4 materialData = texture(colortex2, uv);
    vec3 normalWorld = normalize(normalData.rgb * 2.0 - 1.0);
    float materialId = decodeMaterial(materialData.a);
    if (!isTerrainMaterial(materialId) ||
        normalWorld.y < 0.68 ||
        materialEquals(materialId, MAT_LEAVES) ||
        materialEquals(materialId, MAT_PLANT)) {
        return scene;
    }

    float puddle = wetness * smoothstep(0.68, 0.96, normalWorld.y);
    float roughness = mix(normalData.a, 0.16, puddle * 0.72);
    if (roughness > 0.42) return scene;

    vec3 viewPosition =
        viewPositionFromDepth(uv, depth, gbufferProjectionInverse);
    vec3 normalView = normalize(mat3(gbufferModelView) * normalWorld);
    vec3 reflectedView = reflect(normalize(viewPosition), normalView);

    float confidence;
    vec2 hitUv;
    vec3 reflection = traceScreenReflection(
        viewPosition + normalView * 0.06,
        reflectedView, confidence, hitUv);

    vec3 skyReflection = renderDimensionSky(
        reflect(rdWorld, normalWorld),
        sunDirWorld, moonDirWorld);
    reflection = mix(skyReflection, reflection, confidence);

    float fresnel = 0.025 + 0.975 *
        pow5(1.0 - saturate(dot(normalView,
                               normalize(-viewPosition))));
    float amount = puddle * mix(0.04, 0.27, fresnel) *
                   (1.0 - roughness);
    return mix(scene, reflection, saturate(amount));
#endif
}

vec3 volumetricSunLight(vec3 rdWorld, float maxDistance,
                        vec3 lightDirection, vec3 lightColor) {
#ifndef VOLUMETRIC_LIGHTING
    return vec3(0.0);
#else
#ifdef DIM_NETHER
    return vec3(0.0);
#elif defined DIM_END
    return vec3(0.0);
#else
    float endDistance = min(maxDistance, SHADOW_DISTANCE * 0.92);
    if (endDistance <= 1.0) return vec3(0.0);

    float jitter = interleavedGradientNoise(gl_FragCoord.xy,
                                            float(frameCounter));
    float stepLength = endDistance / float(VOLUME_STEPS);
    float t = stepLength * (0.35 + 0.65 * jitter);
    float accumulation = 0.0;

    float forwardPhase = pow(saturate(dot(rdWorld, lightDirection)),
                             18.0) * 1.14 + 0.064;

    for (int i = 0; i < VOLUME_STEPS; ++i) {
        vec3 sampleWorld = cameraPosition + rdWorld * t;
        float heightHaze = exp(-max(sampleWorld.y - 58.0, 0.0) / 115.0);
        float noise = valueNoise3(sampleWorld * 0.018 +
                                  vec3(frameTimeCounter * 0.01, 0.0, 0.0));
        float density = heightHaze * mix(0.42, 1.0, noise) *
                        (0.00105 + rainStrength * 0.0020) *
                        ATMOSPHERE_DENSITY;
        float visibility = quickShadowAt(sampleWorld, cameraPosition,
                                         shadowModelView,
                                         shadowProjection,
                                         shadowtex0);
        accumulation += density * visibility * stepLength;
        t += stepLength;
    }

    return lightColor * accumulation * forwardPhase;
#endif
#endif
}

float rainLayer(vec2 fragCoord, float scale, float speed, float seed) {
    vec2 p = fragCoord / scale;
    p.x += p.y * 0.14;
    float column = floor(p.x);
    float random = hash11(column + seed);
    float x = abs(fract(p.x) - 0.5 - (random - 0.5) * 0.55);
    float y = fract(p.y + frameTimeCounter * speed +
                    random * 8.0);
    float streak = smoothstep(0.055, 0.0, x) *
                   smoothstep(0.72, 0.08, y);
    return streak * smoothstep(0.18, 0.95, random);
}

vec3 applyRainOverlay(vec3 scene) {
#ifndef RAIN_EFFECTS
    return scene;
#else
    if (rainStrength <= 0.01 || isEyeInWater != 0) return scene;
    float rain = 0.0;
    rain += rainLayer(gl_FragCoord.xy, 9.0, 3.7, 1.0);
    rain += 0.65 * rainLayer(gl_FragCoord.xy + 41.0,
                             14.0, 2.7, 17.0);
    rain += 0.35 * rainLayer(gl_FragCoord.xy + 113.0,
                             22.0, 2.0, 47.0);
    vec3 rainColor = mix(vec3(0.16, 0.24, 0.31),
                         vec3(0.65, 0.82, 1.0),
                         saturate(thunderStrength * 2.0));
    return scene + rainColor * rain * rainStrength * 0.30;
#endif
}

