out vec2 vTexcoord;

void main() {
    // Use an explicit transform so the loader can rewrite the vertex input cleanly.
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    vTexcoord = gl_MultiTexCoord0.xy;
}
