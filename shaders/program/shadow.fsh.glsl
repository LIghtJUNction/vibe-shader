#include "/lib/buffers.glsl"
#include "/lib/shadows.glsl"

uniform sampler2D gtexture;

in vec2 vTexcoord;
in vec4 vColor;

layout(location = 0) out vec4 outShadowColor;

void main() {
    vec4 atlasSample = texture(gtexture, vTexcoord);
    vec4 texel = vec4(atlasSample.rgb * vColor.rgb, atlasSample.a);
    if (texel.a < 0.10) discard;
    outShadowColor = texel;
}
