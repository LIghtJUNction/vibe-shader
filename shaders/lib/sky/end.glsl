vec3 endAtmosphere(vec3 rd) {
    // Quiet mineral-coloured dust leaves space around the observatory.
    float dust = valueNoise3(rd * 4.0 + vec3(0.0, 2.3, 0.0));
    float horizon = pow(1.0 - abs(rd.y), 3.0);
    return vec3(0.004, 0.006, 0.014) +
           vec3(0.026, 0.018, 0.030) * dust +
           vec3(0.015, 0.024, 0.033) * horizon;
}

vec3 endStarBackdrop(vec3 rd) {
    float nebula = fbm3(rd * 4.0 + vec3(0.0, 4.0, 0.0));
    float filament = pow(saturate(nebula - 0.38), 2.0);
    return endAtmosphere(rd) + starField(rd, 1.0) * 1.25 +
           mix(vec3(0.24, 0.065, 0.018), vec3(0.016, 0.12, 0.17),
               valueNoise3(rd * 7.0)) * filament * 1.4;
}

vec3 endSky(vec3 rd) {
#if CELESTIAL_QUALITY == 0
    return endStarBackdrop(rd);
#else
    // Artistic lens approximation, not a relativistic ray tracer. Project onto
    // a world-fixed celestial tangent plane; reject its opposite hemisphere.
    vec3 center = normalize(vec3(0.18, 0.24, -1.0));
    vec3 right = normalize(cross(center, vec3(0.0, 1.0, 0.0)));
    vec3 up = cross(right, center);
    float forward = dot(rd, center);
    if (forward <= 0.05 || CELESTIAL_STRENGTH == 0.0) return endStarBackdrop(rd);
    vec2 p = vec2(dot(rd, right), dot(rd, up)) / forward;
    p = rotate2(0.22) * p;
    float radius = length(p);
    float lensWeight = (1.0 - smoothstep(0.32, 0.85, radius)) *
                       min(CELESTIAL_STRENGTH, 1.0);
    vec2 bent = p * (1.0 - 0.019 * lensWeight / max(radius * radius, 0.012));
    bent = rotate2(-0.22) * bent;
    vec3 bentRay = normalize(center + right * bent.x + up * bent.y);
    vec3 base = endStarBackdrop(bentRay);

    float hole = 1.0 - smoothstep(0.155, 0.162, radius);
    float photonRing = celestialLine(radius - 0.169, 0.0032);
    vec2 diskPoint = vec2(p.x, p.y * 4.4);
    float diskRadius = length(diskPoint);
    float disk = smoothstep(0.17, 0.24, diskRadius) *
                 (1.0 - smoothstep(0.37, 0.56, diskRadius));
    float t = frameTimeCounter * PHENOMENA_SPEED * 0.07;
    // Rotation expressed as dot products, continuous across the whole annulus.
    vec2 spin = vec2(cos(t), sin(t));
    float shear = dot(diskPoint / max(diskRadius, 0.001), spin);
    float gas = valueNoise2(diskPoint * 36.0 + spin * 0.8);
    float threads = 0.46 + 0.25 * sin(diskRadius * 164.0 + shear * 7.0 + gas * 4.0);
    threads += 0.15 * sin(diskRadius * 79.0 - shear * 11.0);
    threads *= mix(0.70, 1.15, gas);
    vec3 diskTint = mix(vec3(0.55, 0.16, 0.045), vec3(1.40, 1.13, 0.72),
                        1.0 - smoothstep(0.20, 0.52, diskRadius));
    float beaming = clamp(1.0 + p.x * 1.8, 0.5, 1.7);
    vec3 emission = diskTint * disk * threads * beaming * 1.35;
#if CELESTIAL_QUALITY >= 2
    // The far side of the disk is folded into an arch around the dark center.
    float archRadius = length(vec2(p.x, p.y * 0.87));
    float arch = celestialLine(archRadius - 0.205, 0.014);
    arch *= smoothstep(-0.025, 0.075, p.y);
    emission += vec3(0.88, 0.61, 0.30) * arch * 0.70;
    emission += vec3(0.13, 0.35, 0.42) *
                celestialLine(radius - 0.238, 0.004) * 0.25;
#endif
    // The hole occludes the far disk AND the lensed stars; the photon rim does not.
    base = mix(base, vec3(0.0004, 0.0006, 0.0012),
               hole * smoothstep(0.0, 0.35, CELESTIAL_STRENGTH));
    emission = emission * (1.0 - hole) + vec3(1.60, 1.17, 0.64) * photonRing;
    return base + emission * CELESTIAL_STRENGTH;
#endif
}
