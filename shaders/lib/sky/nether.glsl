vec3 netherAtmosphere(vec3 rd) {
    float horizon = pow(1.0 - abs(rd.y), 2.0);
    vec3 p = rd * 4.5;
    p.xz += vec2(frameTimeCounter * 0.018,
                 -frameTimeCounter * 0.011);
    float smoke = fbm3(p);
    float veins = pow(saturate(fbm3(p * 2.1) - 0.43), 3.0);
    vec3 base = mix(vec3(0.010, 0.0015, 0.001),
                    vec3(0.20, 0.016, 0.003),
                    horizon * 0.7 + smoke * 0.35);
    base += vec3(1.55, 0.065, 0.006) * veins *
            (0.4 + 0.6 * horizon);
    base += vibeAccentB() * veins * 0.04;

    return base;
}

vec3 netherSky(vec3 rd) {
    vec3 base = netherAtmosphere(rd);
    float horizon = pow(1.0 - abs(rd.y), 2.0);
    vec3 cell = floor(rd * 220.0 +
                      vec3(0.0, frameTimeCounter * 2.0, 0.0));
    float ember = smoothstep(0.995, 1.0, hash13(cell));
    base += vec3(2.5, 0.24, 0.012) * ember * horizon;
    return base;
}
