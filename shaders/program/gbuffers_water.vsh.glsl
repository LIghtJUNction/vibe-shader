#include "/lib/buffers.glsl"
#include "/lib/geometry.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

in vec2 mc_Entity;
in vec4 at_midBlock;

out vec2 vTexcoord;
out vec2 vLmcoord;
out vec4 vColor;
out vec3 vWorldPosition;
out vec3 vWorldNormal;
flat out float vMaterial;

void main() {
    vec3 viewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 playerPosition =
        (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    vec3 worldPosition = playerPosition + cameraPosition;

    worldPosition = applyVoxelAnimation(worldPosition, mc_Entity.x,
                                        gl_MultiTexCoord0.xy,
                                        at_midBlock.xyz,
                                        frameTimeCounter);
    playerPosition = worldPosition - cameraPosition;

    gl_Position = gbufferProjection * gbufferModelView *
                  vec4(playerPosition, 1.0);

    vWorldPosition = worldPosition;
    vWorldNormal = normalize(mat3(gbufferModelViewInverse) *
                             normalize(gl_NormalMatrix * gl_Normal));
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;
    vMaterial = materialFromBlockId(mc_Entity.x);
}
