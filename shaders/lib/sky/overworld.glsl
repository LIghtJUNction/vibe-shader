float highCirrus(vec3 rd, float time) {
    if (rd.y <= 0.015) return 0.0;
    // Project the upper sky onto a continuous plane. Unlike atan-based
    // longitude, this has no fixed seam at the azimuth branch cut.
    vec2 cloudUv = rd.xz / max(rd.y, 0.12);
    vec2 wind = vec2(time * 0.0017, -time * 0.00045);
    float broad = fbm2(cloudUv * 0.42 + wind);
    float streak = valueNoise2(cloudUv * vec2(1.35, 0.55) +
                               wind * 4.0);
    float cloud = smoothstep(0.54, 0.73,
                             broad * 0.78 + streak * 0.22);
    return cloud * smoothstep(0.02, 0.26, rd.y) *
           (1.0 - smoothstep(0.78, 1.0, rd.y));
}

vec3 overworldSky(vec3 rd, vec3 sunDir, vec3 moonDir) {
    float sunHeight = sunDir.y;
    float day, twilight, night;
    vibeTimeFactors(sunHeight, day, twilight, night);

    float up = saturate(rd.y * 0.5 + 0.5);
    float horizon = pow(1.0 - saturate(abs(rd.y)), 3.2);
    vec3 sky = mix(vibeSkyHorizon(sunHeight, rainStrength),
                   vibeSkyZenith(sunHeight, rainStrength),
                   pow(up, 0.50));

    vec2 rayHorizon = rd.xz / max(length(rd.xz), 1e-5);
    vec2 sunHorizon = sunDir.xz / max(length(sunDir.xz), 1e-5);
    float sunSide = pow(saturate(dot(rayHorizon, sunHorizon)), 5.0);
    float oppositeSide = pow(saturate(dot(rayHorizon, -sunHorizon)), 3.0);
    vec3 duskColor = mix(vibeAccentB(), vibeSunColor(sunHeight,
                                                     rainStrength), 0.58);
    sky += duskColor * horizon * twilight *
           (0.15 + sunSide * 0.74) * TWILIGHT_BOOST;
    sky += vibeAccentA() * horizon * twilight *
           oppositeSide * 0.055 * TWILIGHT_BOOST;

    float mu = saturate(dot(rd, sunDir));
    float sunDisk = smoothstep(0.99972, 0.99993, mu);
    float coreHalo = pow(mu, 640.0) * 2.4;
    float wideHalo = pow(mu, 38.0) * 0.20;
    vec3 sunColor = vibeSunColor(sunHeight, rainStrength);
    sky += sunColor * (sunDisk * 22.0 + coreHalo + wideHalo) * day;

    // A soft atmospheric aureole gives the sky a clear visual anchor without
    // turning the whole screen into bloom.
    float aureole = exp(-(1.0 - mu) * 16.0) * horizon;
    sky += sunColor * aureole * (0.16 + twilight * 0.35) * day;

    float moonMu = saturate(dot(rd, moonDir));
    float moonDisk = smoothstep(0.99968, 0.99992, moonMu);
    float moonCut = smoothstep(
        0.99946, 0.99976,
        dot(rd, normalize(moonDir + vec3(0.024, 0.011, 0.0))));
    sky += vec3(0.40, 0.62, 1.08) * moonDisk *
           (1.0 - 0.72 * moonCut) * night * 3.8;
    sky += vec3(0.10, 0.22, 0.58) *
           pow(moonMu, 90.0) * night * 0.68;

    sky += starField(rd, night * smoothstep(-0.08, 0.24, rd.y));

    sky += meridianRadiance(rd, sunHeight, frameTimeCounter, rainStrength);

    float cirrus = highCirrus(rd, frameTimeCounter);
    float cirrusLight = 0.25 + 0.75 *
        pow(saturate(dot(rd, sunDir) * 0.5 + 0.5), 5.0);
    vec3 cirrusColor = mix(vibeSkyHorizon(sunHeight, rainStrength),
                           sunColor, cirrusLight);
    sky = mix(sky, cirrusColor * (0.62 + day * 0.35),
              cirrus * (1.0 - rainStrength) * 0.20);

#ifdef AURORA_ENABLED
    float pole = smoothstep(0.03, 0.72, rd.y) * night;
    // Continuous sky-plane projection: no atan longitude and therefore no
    // azimuth branch-cut seam when the view crosses +/-pi.
    vec2 auroraPlane = rd.xz / max(rd.y + 0.28, 0.34);
    vec2 auroraWind = vec2(frameTimeCounter * 0.010,
                           -frameTimeCounter * 0.0035);
    float band = fbm2(auroraPlane * vec2(0.62, 0.48) +
                      auroraWind);
    float curtain = pow(saturate(1.0 - abs(
        rd.y - 0.43 - (band - 0.5) * 0.20) * 8.2), 3.0);
    float foldPhase = dot(auroraPlane, vec2(7.3, 5.1));
    float folds = 0.55 + 0.45 * sin(foldPhase +
                                   frameTimeCounter * 0.08 +
                                   band * 8.0);
    float colorPhase = dot(auroraPlane, vec2(3.7, -2.9));
    vec3 auroraColor = mix(vibeAccentA(), vibeAccentB(),
                           0.5 + 0.5 * sin(colorPhase));
    sky += auroraColor * curtain * folds * pole *
           (0.26 + VIBE_INTENSITY * 0.20) *
           (CELESTIAL_QUALITY > 0 ? mix(1.0, 0.36, saturate(CELESTIAL_STRENGTH)) : 1.0);
#endif

    sky = mix(sky, vec3(0.17, 0.19, 0.21),
              rainStrength * 0.70);
    return max(sky, vec3(0.0));
}
