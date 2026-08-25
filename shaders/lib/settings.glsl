#ifndef VIBE_SHADER_SETTINGS
#define VIBE_SHADER_SETTINGS

// Core quality controls
#define SHADOW_QUALITY 2 // [0 1 2 3]
#define SHADOW_DISTANCE 160.0 // [64.0 96.0 128.0 160.0 192.0 224.0]
#define CLOUD_QUALITY 2 // [0 1 2 3]
#define WATER_QUALITY 2 // [0 1 2 3]
#define SSR_QUALITY 2 // [0 1 2 3]

// Feature switches
#define SSAO_ENABLED
#define VOLUMETRIC_LIGHTING
#define TAA_ENABLED
#define FXAA_ENABLED
#define BLOOM_ENABLED
#define WAVING_FOLIAGE
#define WAVING_WATER
#define EMISSIVE_ORES
#define BLOCK_EDGE_ACCENT
#define AURORA_ENABLED
#define RAIN_EFFECTS
#define FILMIC_GRAIN

// Artistic controls
#define CLOUD_COVERAGE 0.52 // [0.35 0.42 0.48 0.52 0.58 0.64 0.72]
#define BLOOM_STRENGTH 0.85 // [0.35 0.50 0.65 0.85 1.00 1.20 1.50]
#define WATER_OPACITY 0.62 // [0.35 0.45 0.55 0.62 0.70 0.80]
#define EDGE_STRENGTH 0.22 // [0.00 0.08 0.14 0.22 0.30 0.40]
#define TONEMAP_EXPOSURE 1.05 // [0.70 0.85 1.00 1.05 1.15 1.30 1.50]
#define COLOR_GRADE 1 // [0 1 2]
#define MOTION_STABILITY 0.86 // [0.65 0.72 0.80 0.86 0.90 0.94]

#endif
