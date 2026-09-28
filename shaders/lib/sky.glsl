#ifndef VIBE_SHADER_SKY
#define VIBE_SHADER_SKY

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/vibe.glsl"
#include "/lib/celestial.glsl"

uniform float frameTimeCounter;
uniform float rainStrength;
uniform int worldTime;

#include "/lib/sky/stars.glsl"
#ifdef DIM_NETHER
#include "/lib/sky/nether.glsl"
#elif defined DIM_END
#include "/lib/sky/end.glsl"
#else
#include "/lib/sky/overworld.glsl"
#endif

// One directional radiance function for the visible sky and reflected rays.
vec3 renderDimensionSky(vec3 rd, vec3 sunDir, vec3 moonDir) {
#ifdef DIM_NETHER
    return netherSky(rd);
#elif defined DIM_END
    return endSky(rd);
#else
    return overworldSky(rd, sunDir, moonDir);
#endif
}

// Fog contains atmosphere only. Celestial objects must not show through terrain.
vec3 renderDimensionFog(vec3 rd, vec3 sunDir) {
#ifdef DIM_NETHER
    return netherAtmosphere(rd);
#elif defined DIM_END
    return endAtmosphere(rd);
#else
    return vibeFogColor(rd, sunDir, sunDir.y, rainStrength);
#endif
}

#endif
