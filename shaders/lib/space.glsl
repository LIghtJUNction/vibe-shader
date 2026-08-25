#ifndef VIBE_SHADER_SPACE
#define VIBE_SHADER_SPACE

vec3 viewPositionFromDepth(vec2 uv, float depth, mat4 inverseProjection) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = inverseProjection * clip;
    return view.xyz / max(view.w, 1e-7);
}

vec2 projectViewToUv(vec3 viewPosition, mat4 projection) {
    vec4 clip = projection * vec4(viewPosition, 1.0);
    return clip.xy / max(abs(clip.w), 1e-7) * 0.5 + 0.5;
}

vec3 playerToWorld(vec3 playerPosition, vec3 cameraPosition) {
    return playerPosition + cameraPosition;
}

vec3 viewToPlayer(vec3 viewPosition, mat4 inverseModelView) {
    return (inverseModelView * vec4(viewPosition, 1.0)).xyz;
}

vec3 playerToView(vec3 playerPosition, mat4 modelView) {
    return (modelView * vec4(playerPosition, 1.0)).xyz;
}

vec3 viewDirectionWorld(vec2 uv, mat4 inverseProjection, mat4 inverseModelView) {
    vec3 view = viewPositionFromDepth(uv, 1.0, inverseProjection);
    vec3 player = (inverseModelView * vec4(view, 0.0)).xyz;
    return normalize(player);
}

#endif
