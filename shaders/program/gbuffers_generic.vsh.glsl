#include "/lib/buffers.glsl"
#include "/lib/common.glsl"
#include "/lib/materials.glsl"

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

out vec2 vTexcoord;
out vec2 vLmcoord;
out vec4 vColor;
out vec3 vWorldPosition;
out vec3 vWorldNormal;

void main() {
    // Use an explicit transform so the loader can rewrite the vertex input cleanly.
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;

    vec3 viewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 playerPosition =
        (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;

    vWorldPosition = playerPosition + cameraPosition;
    vWorldNormal = normalize(mat3(gbufferModelViewInverse) *
                             normalize(gl_NormalMatrix * gl_Normal));
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;
}
