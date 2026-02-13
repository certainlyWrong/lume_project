#version 320 es

precision highp float;

layout(location = 0) out vec4 fragColor;

layout(location = 0) uniform vec2 uResolution;
layout(location = 1) uniform vec2 uOffset;
layout(location = 2) uniform float uZoom;
layout(location = 3) uniform float uMaxIter;
layout(location = 4) uniform float uColorShift;
layout(location = 5) uniform float uFade;

vec2 complexSqr(vec2 z) {
    return vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
}

vec3 palette(float t, float shift) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.263, 0.416, 0.557) + vec3(shift * 0.1);
    return a + b * cos(6.28318 * (c * t + d));
}

void main() {
    vec2 uv = (gl_FragCoord.xy - uResolution * 0.5) / uResolution.y;
    
    vec2 c = uv * uZoom + uOffset;
    vec2 z = vec2(0.0);
    
    float iter = 0.0;
    for (int i = 0; i < 1000; i++) {
        if (float(i) >= uMaxIter) break;
        z = complexSqr(z) + c;
        if (dot(z, z) > 4.0) {
            iter = float(i);
            break;
        }
        iter = float(i);
    }
    
    float smoothIter = iter + 1.0 - log2(log2(dot(z, z))) / log2(2.0);
    float t = smoothIter / uMaxIter;
    
    vec3 color = palette(t + 0.5, uColorShift);
    
    if (iter >= uMaxIter - 0.5) {
        color = vec3(0.0);
    }
    
    // Fade for cycle transitions
    color *= uFade;
    
    fragColor = vec4(color, 1.0);
}
