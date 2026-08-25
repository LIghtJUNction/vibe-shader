#include "/lib/buffers.glsl"
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/materials.glsl"
#include "/lib/space.glsl"
#include "/lib/sky.glsl"
#include "/lib/clouds.glsl"
#ifndef DIM_NETHER
#ifndef DIM_END
#include "/lib/shadows.glsl"
#endif
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifndef DIM_NETHER
#ifndef DIM_END
uniform sampler2D shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
#endif
#endif

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float wetness;
uniform float thunderStrength;
uniform int frameCounter;
uniform int isEyeInWater;

in vec2 vTexcoord;

const bool colortex6Clear = false;

/* RENDERTARGETS: 0,3,6 */
layout(location = 0) out vec4 outScene;
layout(location = 1) out vec4 outBloom;
layout(location = 2) out vec4 outHistory;

#if SSR_QUALITY == 0
    #define SSR_STEPS 0
#elif SSR_QUALITY == 1
    #define SSR_STEPS 8
#elif SSR_QUALITY == 2
    #define SSR_STEPS 16
#else
    #define SSR_STEPS 26
#endif

#if SHADOW_QUALITY <= 1
    #define VOLUME_STEPS 6
#elif SHADOW_QUALITY == 2
    #define VOLUME_STEPS 9
#else
    #define VOLUME_STEPS 13
#endif

vec3 dimensionWaterTint() {
#ifdef DIM_NETHER
    return vec3(0.24, 0.018, 0.003);
#elif defined DIM_END
    return vec3(0.018, 0.015, 0.10);
#else
    return vec3(0.012, 0.21, 0.27);
#endif
}

vec3 sampleChromaticRefraction(vec2 uv, vec2 offset) {
    vec3 c;
    c.r = texture(colortex5, saturate(uv + offset * 1.04)).r;
    c.g = texture(colortex5, saturate(uv + offset)).g;
    c.b = texture(colortex5, saturate(uv + offset * 0.96)).b;
    return c;
}

vec3 traceScreenReflection(vec3 startView, vec3 directionView,
                           out float confidence, out vec2 hitUv) {
    confidence = 0.0;
    hitUv = vec2(-1.0);
#if SSR_STEPS == 0
    return vec3(0.0);
#else
    if (directionView.z > -0.015) return vec3(0.0);

    vec3 rayPosition = startView + directionView * 0.18;
    float stepLength = mix(0.28, 0.75,
                           saturate(length(startView) / 90.0));
    float travelled = 0.0;

    for (int i = 0; i < SSR_STEPS; ++i) {
        rayPosition += directionView * stepLength;
        travelled += stepLength;
        stepLength *= 1.13;

        vec2 uv = projectViewToUv(rayPosition, gbufferProjection);
        if (any(lessThanEqual(uv, vec2(0.002))) ||
            any(greaterThanEqual(uv, vec2(0.998)))) {
            break;
        }

        float sceneDepth = texture(depthtex1, uv).r;
        if (sceneDepth >= 0.999999) continue;

        vec3 scenePosition =
            viewPositionFromDepth(uv, sceneDepth,
                                  gbufferProjectionInverse);
        float delta = scenePosition.z - rayPosition.z;
        float thickness = 0.10 + stepLength * 1.35;

        if (delta > 0.0 && delta < thickness) {
            float edgeFade = saturate(min(min(uv.x, uv.y),
                                          min(1.0 - uv.x,
                                              1.0 - uv.y)) * 12.0);
            float distanceFade = 1.0 -
                saturate(travelled / 95.0);
            confidence = edgeFade * distanceFade;
            hitUv = uv;
            return texture(colortex5, uv).rgb;
        }
    }
    return vec3(0.0);
#endif
}

vec3 shadeWaterOrGlass(vec2 uv, vec3 baseScene, vec4 waterData,
                       vec3 rdWorld, vec3 sunDirWorld,
                       vec3 moonDirWorld) {
    float surfaceClass = floor(waterData.b * 8.0 + 0.5);
    bool water = abs(surfaceClass - 1.0) < 0.25;
    bool glass = abs(surfaceClass - 2.0) < 0.25;
    bool ice = abs(surfaceClass - 3.0) < 0.25;
    bool portal = abs(surfaceClass - 4.0) < 0.25;
    bool lava = abs(surfaceClass - 5.0) < 0.25;
    float translucentDepth = waterData.a;
    vec3 surfaceView =
        viewPositionFromDepth(uv, translucentDepth,
                              gbufferProjectionInverse);
    vec3 surfacePlayer =
        viewToPlayer(surfaceView, gbufferModelViewInverse);
    vec3 surfaceWorld = surfacePlayer + cameraPosition;

    vec3 normalWorld = octDecode(waterData.rg);
    vec3 normalView = normalize(mat3(gbufferModelView) * normalWorld);
    vec3 viewDirection = normalize(-surfaceView);
    float nDotV = saturate(dot(normalView, viewDirection));

    float opaqueDepth = texture(depthtex1, uv).r;
    vec3 opaqueView = opaqueDepth < 0.999999
        ? viewPositionFromDepth(uv, opaqueDepth,
                                gbufferProjectionInverse)
        : surfaceView + normalize(surfaceView) * 80.0;
    float thickness = max(length(opaqueView - surfaceView), 0.0);

    if (lava) {
        float cells = valueNoise2(surfaceWorld.xz * 1.8 +
                                  frameTimeCounter * 0.16);
        float veins = pow(saturate(cells - 0.38), 2.0);
        vec3 lavaColor = vec3(4.8, 0.36, 0.012) +
                         vec3(2.4, 0.08, 0.0) * veins;
        float rim = pow5(1.0 - nDotV);
        return mix(baseScene, lavaColor + baseScene * 0.18,
                   0.80 + rim * 0.16);
    }

    if (portal) {
        vec2 portalUv = surfaceWorld.xy * vec2(0.13, 0.19);
        float vortex = fbm2(portalUv +
                           vec2(frameTimeCounter * 0.09,
                               -frameTimeCounter * 0.14));
        float rune = pow(saturate(0.60 - abs(fract(portalUv.y * 3.0 +
                          vortex) - 0.5)), 5.0);
        vec3 portalColor = mix(vec3(0.15, 0.005, 0.65),
                               vec3(1.8, 0.04, 3.5), vortex);
        portalColor += vec3(0.12, 1.0, 1.7) * rune * 0.55;
        float rim = pow5(1.0 - nDotV);
        return baseScene * 0.28 + portalColor * (0.72 + rim * 0.55);
    }

    float refractionQuality = WATER_QUALITY == 0 ? 0.18 :
                              (WATER_QUALITY == 1 ? 0.50 :
                              (WATER_QUALITY == 2 ? 1.00 : 1.28));
    vec2 refractionOffset = normalView.xy *
        mix(0.0025, 0.014, saturate(thickness / 8.0)) *
        refractionQuality;
    refractionOffset *= water ? 1.0 : 0.38;
#if WATER_QUALITY >= 2
    vec3 refracted = sampleChromaticRefraction(uv, refractionOffset);
#else
    vec3 refracted = texture(colortex5, saturate(uv + refractionOffset)).rgb;
#endif

    vec3 absorptionColor = water ? dimensionWaterTint() :
                           (ice ? vec3(0.012, 0.055, 0.095) :
                                  vec3(0.003, 0.004, 0.006));
    float absorptionScale = water ? 0.34 : (ice ? 0.13 : 0.035);
    vec3 transmittance = exp(-max(absorptionColor, vec3(0.001)) *
                             thickness * absorptionScale);
    vec3 scatterColor = absorptionColor *
                        (1.0 - transmittance) * 1.45;
    refracted = refracted * transmittance + scatterColor;

    vec3 incidentView = normalize(surfaceView);
    vec3 reflectedView = reflect(incidentView, normalView);
    float ssrConfidence;
    vec2 hitUv;
    vec3 reflection = traceScreenReflection(
        surfaceView + normalView * 0.075,
        reflectedView, ssrConfidence, hitUv);

    vec3 reflectedWorld = reflect(rdWorld, normalWorld);
    vec3 skyReflection =
        renderDimensionSky(reflectedWorld, sunDirWorld, moonDirWorld);
    reflection = mix(skyReflection, reflection, ssrConfidence);

    float f0 = water ? 0.020 : (ice ? 0.040 : 0.055);
    float fresnel = f0 + (1.0 - f0) * pow5(1.0 - nDotV);
    fresnel = mix(fresnel, 0.68, water ? 0.0 : 0.28);

#ifndef DIM_NETHER
#ifndef DIM_END
    vec3 lightDirection =
        normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    vec3 halfVector = normalize(viewDirection +
                                normalize(mat3(gbufferModelView) *
                                          lightDirection));
    float sparkle = pow(saturate(dot(normalView, halfVector)),
                        water ? 420.0 : 180.0);
    reflection += vec3(1.25, 0.95, 0.65) *
                  sparkle * (1.0 + rainStrength * 0.8) * 3.5;
#endif
#endif

#if WATER_QUALITY >= 2
    float shoreline = water
        ? (1.0 - smoothstep(0.12, 1.10, thickness))
        : 0.0;
    float foamNoise = valueNoise2(surfaceWorld.xz * 2.8 +
                                  frameTimeCounter * 0.18);
#if WATER_QUALITY >= 3
    foamNoise = mix(foamNoise,
                    valueNoise2(surfaceWorld.xz * 7.3 -
                                frameTimeCounter * 0.31), 0.28);
#endif
    float foam = shoreline *
                 smoothstep(0.42, 0.72, foamNoise);
    vec3 foamColor = vec3(0.55, 0.82, 0.88) * foam * 0.75;
#else
    float foam = 0.0;
    vec3 foamColor = vec3(0.0);
#endif

    vec3 result = mix(refracted, reflection,
                      saturate(fresnel + foam * 0.18));
    result += foamColor;

    if (!water) {
        result = mix(baseScene, result, ice ? 0.48 : 0.32);
    } else {
        result = mix(baseScene, result, WATER_OPACITY);
    }
    return result;
}

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
    float roughness = mix(normalData.a, 0.055, puddle * 0.88);
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
    float amount = puddle * mix(0.07, 0.48, fresnel) *
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
                             10.0) * 0.85 + 0.12;

    for (int i = 0; i < VOLUME_STEPS; ++i) {
        vec3 sampleWorld = cameraPosition + rdWorld * t;
        float heightHaze = exp(-max(sampleWorld.y - 58.0, 0.0) / 115.0);
        float noise = valueNoise3(sampleWorld * 0.018 +
                                  vec3(frameTimeCounter * 0.01, 0.0, 0.0));
        float density = heightHaze * mix(0.45, 1.0, noise) *
                        (0.0022 + rainStrength * 0.0035);
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

vec3 applyEyeMedium(vec3 scene, vec3 worldPosition,
                    float distanceToSurface) {
    if (isEyeInWater == 1) {
        float caustic = sin(worldPosition.x * 2.6 +
                            frameTimeCounter * 1.7) *
                         sin(worldPosition.z * 2.2 -
                             frameTimeCounter * 1.3);
        caustic = pow(saturate(caustic * 0.5 + 0.5), 4.0);
        scene += vec3(0.03, 0.20, 0.23) * caustic * 0.22;
        float fog = 1.0 - exp(-distanceToSurface * 0.045);
        scene = mix(scene, vec3(0.006, 0.075, 0.105),
                    saturate(fog));
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
                     bool skyPixel) {
#ifndef TAA_ENABLED
    return currentColor;
#else
    vec3 previousPlayer = worldPosition - previousCameraPosition;
    vec3 previousView =
        (gbufferPreviousModelView *
         vec4(previousPlayer, skyPixel ? 0.0 : 1.0)).xyz;

    if (skyPixel) {
        previousView = mat3(gbufferPreviousModelView) *
                       normalize(worldPosition - cameraPosition) *
                       1000.0;
    }

    vec4 previousClip =
        gbufferPreviousProjection * vec4(previousView, 1.0);
    if (previousClip.w <= 0.0 || frameCounter < 2) {
        return currentColor;
    }

    vec2 previousUv =
        previousClip.xy / previousClip.w * 0.5 + 0.5;
    if (any(lessThanEqual(previousUv, vec2(0.001))) ||
        any(greaterThanEqual(previousUv, vec2(0.999)))) {
        return currentColor;
    }

    vec4 history = texture(colortex6, previousUv);
    float predictedDepth = skyPixel
        ? 1.0
        : saturate(length(previousView) / max(far, 1.0));
    float depthError = abs(history.a - predictedDepth);
    float allowedError = skyPixel ? 0.08 :
                         (0.012 + predictedDepth * 0.035);
    if (depthError > allowedError) return currentColor;

    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 n0 = texture(colortex0, uv + vec2(px.x, 0.0)).rgb;
    vec3 n1 = texture(colortex0, uv - vec2(px.x, 0.0)).rgb;
    vec3 n2 = texture(colortex0, uv + vec2(0.0, px.y)).rgb;
    vec3 n3 = texture(colortex0, uv - vec2(0.0, px.y)).rgb;

    vec3 neighborhoodMin =
        min(currentColor, min(min(n0, n1), min(n2, n3))) - 0.12;
    vec3 neighborhoodMax =
        max(currentColor, max(max(n0, n1), max(n2, n3))) + 0.18;
    vec3 clampedHistory =
        clamp(history.rgb, neighborhoodMin, neighborhoodMax);

    float motion = length(previousUv - uv);
    float stability = MOTION_STABILITY *
                      exp(-motion * 58.0);
    stability *= skyPixel ? 0.90 : 1.0;
    return mix(currentColor, clampedHistory,
               saturate(stability));
#endif
}

void main() {
    vec2 uv = vTexcoord;
    vec3 scene = texture(colortex0, uv).rgb;

    float opaqueDepth = texture(depthtex1, uv).r;
    float fullDepth = texture(depthtex0, uv).r;
    vec4 waterData = texture(colortex4, uv);

    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                 sunPosition);
    vec3 moonDirWorld = normalize(mat3(gbufferModelViewInverse) *
                                  moonPosition);
    vec3 rdWorld = viewDirectionWorld(uv,
                                      gbufferProjectionInverse,
                                      gbufferModelViewInverse);

    bool skyPixel = fullDepth >= 0.999999;
    vec3 viewPosition = skyPixel
        ? viewPositionFromDepth(uv, 1.0,
                                gbufferProjectionInverse)
        : viewPositionFromDepth(uv, fullDepth,
                                gbufferProjectionInverse);
    vec3 playerPosition =
        viewToPlayer(viewPosition, gbufferModelViewInverse);
    vec3 worldPosition = skyPixel
        ? cameraPosition + rdWorld * max(far, 256.0)
        : cameraPosition + playerPosition;
    float surfaceDistance = skyPixel
        ? max(far, 256.0)
        : length(viewPosition);

    if (waterData.a > 0.00001 && waterData.b > 0.00001) {
        scene = shadeWaterOrGlass(uv, scene, waterData,
                                  rdWorld, sunDirWorld,
                                  moonDirWorld);
    } else {
        scene = wetSurfaceReflection(uv, scene, rdWorld,
                                     sunDirWorld, moonDirWorld);
    }

#ifndef DIM_NETHER
#ifndef DIM_END
    vec3 lightDirection =
        normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float sunHeight = sunDirWorld.y;
    float day = smoothstep(-0.08, 0.08, sunHeight);
    vec3 shaftColor = mix(vec3(0.16, 0.27, 0.62),
                          vec3(1.12, 0.72, 0.38), day);
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
#endif
#endif

    scene += vec3(0.65, 0.82, 1.15) *
             thunderStrength * rainStrength * 0.85;

    scene = applyEyeMedium(scene, worldPosition,
                           surfaceDistance);

    float depthNorm = skyPixel ? 1.0 :
                      saturate(surfaceDistance / max(far, 1.0));
    scene = temporalResolve(uv, scene, worldPosition,
                            depthNorm, skyPixel);
    scene = applyRainOverlay(scene);

    vec3 bright = max(scene - vec3(0.82), vec3(0.0));
    bright += scene * smoothstep(1.6, 5.0, luminance(scene)) * 0.35;

    outScene = vec4(max(scene, vec3(0.0)), 1.0);
    outBloom = vec4(bright, 1.0);
    outHistory = vec4(max(scene, vec3(0.0)), depthNorm);
}
