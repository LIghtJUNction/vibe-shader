float starLayer(vec3 rd, float scale, float threshold) {
    vec3 cell = floor(rd * scale);
    vec3 local = fract(rd * scale) - 0.5;
    float h = hash13(cell);
    float star = (1.0 - smoothstep(0.0, 0.078, length(local.xy)));
    star *= smoothstep(threshold, 1.0, h);
    star *= mix(0.45, 1.65, hash13(cell + 13.7));
    return star;
}

vec3 starField(vec3 rd, float night) {
    float stars = starLayer(rd, 420.0, 0.985);
    stars += 0.34 * starLayer(rd.yzx, 760.0, 0.993);
    float cellHash = hash13(floor(rd * 420.0));
    float twinkle = 0.68 + 0.32 *
        sin(frameTimeCounter * 1.8 + cellHash * TAU);
    vec3 tint = mix(vec3(0.48, 0.70, 1.0),
                    vec3(1.0, 0.67, 0.40), cellHash);
    return tint * stars * twinkle * night;
}
