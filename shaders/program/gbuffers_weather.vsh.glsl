out vec2 vTexcoord;
out vec4 vColor;
void main() {
    // Use an explicit transform so the loader can rewrite the vertex input cleanly.
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor = gl_Color;
}
