#ifndef VIBE_SHADER_MATERIALS
#define VIBE_SHADER_MATERIALS

// Encoded material classes. Keep below 31 for exact recovery from RGBA16F.
const float MAT_DEFAULT       = 1.0;
const float MAT_LEAVES        = 2.0;
const float MAT_PLANT         = 3.0;
const float MAT_WATER         = 4.0;
const float MAT_LAVA          = 5.0;
const float MAT_EMISSIVE_WARM = 6.0;
const float MAT_EMISSIVE_COOL = 7.0;
const float MAT_ORE_DIAMOND   = 8.0;
const float MAT_ORE_EMERALD   = 9.0;
const float MAT_ORE_REDSTONE  = 10.0;
const float MAT_ORE_LAPIS     = 11.0;
const float MAT_ORE_GOLD      = 12.0;
const float MAT_ORE_COPPER    = 13.0;
const float MAT_ORE_IRON      = 14.0;
const float MAT_METAL         = 15.0;
const float MAT_GLASS         = 16.0;
const float MAT_ICE           = 17.0;
const float MAT_PORTAL        = 18.0;
const float MAT_ENTITY        = 19.0;
const float MAT_SCULK         = 20.0;
const float MAT_NETHER        = 21.0;

// block.properties IDs used by mc_Entity.x.
const float BID_LEAVES        = 1001.0;
const float BID_PLANT         = 1002.0;
const float BID_WATER         = 1003.0;
const float BID_LAVA          = 1004.0;
const float BID_EMISSIVE_WARM = 1005.0;
const float BID_EMISSIVE_COOL = 1006.0;
const float BID_ORE_DIAMOND   = 1007.0;
const float BID_ORE_EMERALD   = 1008.0;
const float BID_ORE_REDSTONE  = 1009.0;
const float BID_ORE_LAPIS     = 1010.0;
const float BID_ORE_GOLD      = 1011.0;
const float BID_ORE_COPPER    = 1012.0;
const float BID_ORE_IRON      = 1013.0;
const float BID_METAL         = 1014.0;
const float BID_GLASS         = 1015.0;
const float BID_ICE           = 1016.0;
const float BID_PORTAL        = 1017.0;
const float BID_SCULK         = 1018.0;
const float BID_NETHER        = 1019.0;

float materialFromBlockId(float id) {
    if (abs(id - BID_LEAVES)        < 0.5) return MAT_LEAVES;
    if (abs(id - BID_PLANT)         < 0.5) return MAT_PLANT;
    if (abs(id - BID_WATER)         < 0.5) return MAT_WATER;
    if (abs(id - BID_LAVA)          < 0.5) return MAT_LAVA;
    if (abs(id - BID_EMISSIVE_WARM) < 0.5) return MAT_EMISSIVE_WARM;
    if (abs(id - BID_EMISSIVE_COOL) < 0.5) return MAT_EMISSIVE_COOL;
    if (abs(id - BID_ORE_DIAMOND)   < 0.5) return MAT_ORE_DIAMOND;
    if (abs(id - BID_ORE_EMERALD)   < 0.5) return MAT_ORE_EMERALD;
    if (abs(id - BID_ORE_REDSTONE)  < 0.5) return MAT_ORE_REDSTONE;
    if (abs(id - BID_ORE_LAPIS)     < 0.5) return MAT_ORE_LAPIS;
    if (abs(id - BID_ORE_GOLD)      < 0.5) return MAT_ORE_GOLD;
    if (abs(id - BID_ORE_COPPER)    < 0.5) return MAT_ORE_COPPER;
    if (abs(id - BID_ORE_IRON)      < 0.5) return MAT_ORE_IRON;
    if (abs(id - BID_METAL)         < 0.5) return MAT_METAL;
    if (abs(id - BID_GLASS)         < 0.5) return MAT_GLASS;
    if (abs(id - BID_ICE)           < 0.5) return MAT_ICE;
    if (abs(id - BID_PORTAL)        < 0.5) return MAT_PORTAL;
    if (abs(id - BID_SCULK)         < 0.5) return MAT_SCULK;
    if (abs(id - BID_NETHER)        < 0.5) return MAT_NETHER;
    return MAT_DEFAULT;
}

float encodeMaterial(float materialId) {
    return materialId / 31.0;
}

float decodeMaterial(float packedValue) {
    return floor(packedValue * 31.0 + 0.5);
}

bool materialEquals(float materialId, float expected) {
    return abs(materialId - expected) < 0.25;
}

bool isOreMaterial(float materialId) {
    return materialId >= MAT_ORE_DIAMOND - 0.25 &&
           materialId <= MAT_ORE_IRON + 0.25;
}

bool isTerrainMaterial(float materialId) {
    return materialId < MAT_ENTITY - 0.25;
}

#endif
