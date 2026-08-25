#ifndef VIBE_SHADER_COMMON
#define VIBE_SHADER_COMMON

const float PI  = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec2  saturate(vec2 x)  { return clamp(x, vec2(0.0), vec2(1.0)); }
vec3  saturate(vec3 x)  { return clamp(x, vec3(0.0), vec3(1.0)); }
vec4  saturate(vec4 x)  { return clamp(x, vec4(0.0), vec4(1.0)); }

float sqr(float x) { return x * x; }
float pow5(float x) { float x2 = x * x; return x2 * x2 * x; }

float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 srgbToLinear(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 linearToSrgb(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash33(vec3 p3) {
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float valueNoise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float valueNoise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(i + vec3(1.0, 1.0, 1.0));

    float x00 = mix(n000, n100, f.x);
    float x10 = mix(n010, n110, f.x);
    float x01 = mix(n001, n101, f.x);
    float x11 = mix(n011, n111, f.x);
    return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

float fbm2(vec2 p) {
    float sum = 0.0;
    float amp = 0.5;
    mat2 m = mat2(1.63, 1.17, -1.17, 1.63);
    for (int i = 0; i < 4; ++i) {
        sum += amp * valueNoise2(p);
        p = m * p + vec2(7.1, 3.8);
        amp *= 0.5;
    }
    return sum;
}

float fbm3(vec3 p) {
    float sum = 0.0;
    float amp = 0.5;
    mat3 m = mat3(
         0.00,  0.80,  0.60,
        -0.80,  0.36, -0.48,
        -0.60, -0.48,  0.64
    );
    for (int i = 0; i < 4; ++i) {
        sum += amp * valueNoise3(p);
        p = m * p * 2.02 + vec3(3.1, 7.2, 5.4);
        amp *= 0.5;
    }
    return sum;
}

mat2 rotate2(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

vec3 safeNormalize(vec3 v) {
    return v * inversesqrt(max(dot(v, v), 1e-8));
}

vec2 octEncode(vec3 n) {
    n /= max(abs(n.x) + abs(n.y) + abs(n.z), 1e-7);
    vec2 encoded = n.xy;
    if (n.z < 0.0) {
        encoded = (1.0 - abs(encoded.yx)) * sign(encoded.xy);
    }
    return encoded * 0.5 + 0.5;
}

vec3 octDecode(vec2 encoded) {
    vec2 f = encoded * 2.0 - 1.0;
    vec3 n = vec3(f, 1.0 - abs(f.x) - abs(f.y));
    if (n.z < 0.0) {
        n.xy = (1.0 - abs(n.yx)) * sign(n.xy);
    }
    return safeNormalize(n);
}

float interleavedGradientNoise(vec2 pixel, float frame) {
    return fract(52.9829189 * fract(dot(pixel + frame * 0.06711056,
                                        vec2(0.06711056, 0.00583715))));
}

vec3 acesTonemap(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

#endif
