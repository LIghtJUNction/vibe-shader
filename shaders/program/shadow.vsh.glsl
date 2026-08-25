#include "/lib/buffers.glsl"
#include "/lib/geometry.glsl"
#include "/lib/shadows.glsl"

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

in vec2 mc_Entity;
in vec4 at_midBlock;

out vec2 vTexcoord;
out vec4 vColor;

void main() {
    vec3 shadowViewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 playerPosition =
        (shadowModelViewInverse * vec4(shadowViewPosition, 1.0)).xyz;
    vec3 worldPosition = playerPosition + cameraPosition;

    worldPosition = applyVoxelAnimation(worldPosition, mc_Entity.x,
                                        gl_MultiTexCoord0.xy,
                                        at_midBlock.xyz,
                                        frameTimeCounter);
    playerPosition = worldPosition - cameraPosition;

    gl_Position = shadowProjection * shadowModelView *
                  vec4(playerPosition, 1.0);
    gl_Position.xyz = distortShadowClipPosition(gl_Position.xyz);

    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor = gl_Color;
}
