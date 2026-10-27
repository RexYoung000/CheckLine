// Native optical adaptation of React Bits ReflectiveCard.
// Copyright (c) 2026 David Haz. MIT + Commons Clause.
// Full license: Resources/Licenses/ReactBits-ReflectiveCard.txt
// Optical environment follows the accepted CheckLine HTML at 770ad6a.
#include <metal_stdlib>
using namespace metal;
namespace wish_material {
constant float VIEW = 900.0;

float hash(float2 p) {
  float3 p3 = fract(float3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float2 hash2(float2 p) {
  float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.103, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy) * 2.0 - 1.0;
}

float3 gradientNoise(float2 p) {
  float2 i = floor(p);
  float2 f = fract(p);
  float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
  float2 ga = hash2(i);
  float2 gb = hash2(i + float2(1.0, 0.0));
  float2 gc = hash2(i + float2(0.0, 1.0));
  float2 gd = hash2(i + float2(1.0, 1.0));
  float va = dot(ga, f);
  float vb = dot(gb, f - float2(1.0, 0.0));
  float vc = dot(gc, f - float2(0.0, 1.0));
  float vd = dot(gd, f - float2(1.0, 1.0));
  float k = va - vb - vc + vd;
  float value = va + u.x * (vb - va) + u.y * (vc - va) + u.x * u.y * k;
  float2 slope = ga + u.x * (gb - ga) + u.y * (gc - ga) + u.x * u.y * (ga - gb - gc + gd) + du * (u.yx * k + float2(vb, vc) - va);
  return float3(value, slope);
}

float valueNoise(float2 p) {
  float2 i = floor(p);
  float2 f = fract(p);
  float2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + float2(1.0, 0.0));
  float c = hash(i + float2(0.0, 1.0));
  float d = hash(i + float2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float wishErf(float x) {
  float x2 = x * x;
  return sign(x) * sqrt(1.0 - exp(-x2 * (1.2732395 + 0.147 * x2) / (1.0 + 0.147 * x2)));
}

float band(float x, float halfWidth, float sigma) {
  float s = 1.4142136 * max(sigma, 0.0001);
  return 0.5 * (wishErf((x + halfWidth) / s) - wishErf((x - halfWidth) / s));
}

float strip(float2 q, float2 center, float2 dir, float halfWidth, float2 sigma) {
  float2 normal = float2(-dir.y, dir.x);
  return band(dot(q - center, normal), halfWidth, length(sigma * normal));
}

constant float2 SWEEP = float2(0.5, 0.86);

float softbox(float2 q, float2 sigma) {
  // A compact white reflection sits inside a broader soft spill. Neither
  // washes the whole card, so the darker reflected room remains legible.
  float key = strip(q, float2(0.14, -0.08), normalize(SWEEP), 0.017, sigma + 0.012);
  float spill = strip(q, float2(0.14, -0.08), normalize(SWEEP), 0.07, sigma + 0.055);
  float shoulder = band(q.y + 0.4, 0.04, sigma.y + 0.03);
  float side = band(q.x - 0.3, 0.015, sigma.x + 0.02);
  return key * 0.75 + spill * 0.23 + shoulder * 0.45 + side * 0.34;
}

float roomPane(float2 q, float2 center, float2 halfSize, float2 softness) {
  return band(q.x - center.x, halfSize.x, softness.x) * band(q.y - center.y, halfSize.y, softness.y);
}

float room(float2 q, float2 sigma) {
  // Reflected room geometry: a distant divided window, side return and soft
  // near-field occluders. Different blur widths retain depth at rest, instead
  // of reducing the environment to one continuous brightness ramp.
  float2 windowQ = float2(q.x + q.y * 0.1, q.y - q.x * 0.06);
  float window = roomPane(windowQ, float2(-0.12, 0.04), float2(0.22, 0.21), sigma + float2(0.022, 0.032));
  float mullion = band(windowQ.x + 0.15, 0.014, sigma.x + 0.009);
  float crossbar = band(windowQ.y - 0.015, 0.013, sigma.y + 0.009);
  float panes = window * (1.0 - 0.73 * mullion) * (1.0 - 0.57 * crossbar);
  float sideReturn = roomPane(q, float2(0.32, -0.09), float2(0.025, 0.31), sigma + float2(0.017, 0.055));
  float wall = 0.23 + 0.21 * exp(-dot((q - float2(-0.1, -0.35)) * float2(1.9, 1.1), (q - float2(-0.1, -0.35)) * float2(1.9, 1.1)));
  float near = roomPane(q, float2(-0.22, 0.19), float2(0.045, 0.18), sigma + float2(0.018, 0.045)) * 0.57;
  near += roomPane(float2(q.x - q.y * 0.13, q.y), float2(0.055, 0.21), float2(0.033, 0.24), sigma + float2(0.012, 0.055)) * 0.65;
  near += roomPane(q, float2(0.19, 0.32), float2(0.06, 0.2), sigma + float2(0.029, 0.05)) * 0.52;
  return (wall + panes * 0.82 + sideReturn * 0.32) * (1.0 - min(near, 0.82));
}

float lightRoom(float2 q, float2 sigma) {
  // The far window has a soft, finite frame. A single closer side return
  // has a tighter edge and reflected side to distinguish depth
  // without spreading grey silhouettes over the clean ice-blue field.
  float2 windowQ = float2(q.x + q.y * 0.1, q.y - q.x * 0.06);
  float window = roomPane(windowQ, float2(-0.15, -0.06), float2(0.17, 0.18), sigma + float2(0.02, 0.034));
  float division = band(windowQ.x + 0.16, 0.019, sigma.x + 0.009);
  float crossbar = band(windowQ.y + 0.08, 0.014, sigma.y + 0.01);
  float panes = window * (0.68 - division * 0.86 - crossbar * 0.42);
  float2 returnQ = float2(q.x - q.y * 0.2 + pow(max(q.y + 0.04, 0.0), 2.0) * 0.55, q.y);
  float returnWidth = mix(0.018, 0.036, smoothstep(0.0, 0.3, q.y));
  float returnShadow = roomPane(returnQ, float2(0.175, 0.21), float2(returnWidth, 0.17), sigma + float2(0.008, 0.035));
  float returnLight = roomPane(returnQ, float2(0.216, 0.17), float2(0.01, 0.13), sigma * 0.7 + float2(0.006, 0.022));
  return 0.58 + panes - returnShadow * 0.76 + returnLight * 0.4;
}

float lightSoftbox(float2 q, float2 sigma) {
  // A clearer surface reflection sits above the low-contrast distant room.
  // Its soft spill remains local instead of veiling the whole card in white.
  float extent = band(dot(q - float2(0.14, -0.08), normalize(SWEEP)), 0.25, sigma.y + 0.08);
  float key = strip(q, float2(0.14, -0.08), normalize(SWEEP), 0.011, sigma * 0.65 + 0.006) * extent;
  float spill = strip(q, float2(0.14, -0.08), normalize(SWEEP), 0.042, sigma + 0.047) * extent;
  float rim = band(q.x - 0.31, 0.008, sigma.x + 0.01);
  return key * 0.9 + spill * 0.16 + rim * 0.28;
}

float3 rotatePose(float3 p, float2 angles, float roll) {
    float cx=cos(angles.x), sx=sin(angles.x), cy=cos(angles.y), sy=sin(angles.y);
    float3 r = float3(cy*p.x+sy*p.z, sx*sy*p.x+cx*p.y-sx*cy*p.z, -cx*sy*p.x+sx*p.y+cx*cy*p.z);
    float cz=cos(roll), sz=sin(roll);
    return float3(cz*r.x-sz*r.y, sz*r.x+cz*r.y, r.z);
}
}

[[ stitchable ]] half4 wishCollectionMetal(float2 position, float2 uSize, float uRadius,
    float uTheme, float2 rotation, float roll, float2 pointer, float glareStrength) {
    using namespace wish_material;
    float uScale=1.5, uBlur=8.0, uRough=0.26, uMetal=1.0;
    float uWarp=0.52, uWarpScale=1.0, uShine=0.86, uBevel=1.8, uGlare=glareStrength;
    float2 uPointer=pointer*uSize;
    float3 uTint=uTheme>0.5 ? pow(float3(0.717647,0.882353,0.945098), float3(2.2)) : float3(1.0);

  float2 p = position - uSize * 0.5;
  float2 halfSize = uSize * 0.5;
  float r = min(uRadius, min(halfSize.x, halfSize.y));
  float2 corner = abs(p) - halfSize + r;
  float2 side = float2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
  float d;
  float2 outward;
  if (corner.x > 0.0 && corner.y > 0.0) {
    d = length(corner) - r;
    outward = normalize(corner) * side;
  } else if (corner.x > corner.y) {
    d = corner.x - r;
    outward = float2(side.x, 0.0);
  } else {
    d = corner.y - r;
    outward = float2(0.0, side.y);
  }
  float coverage = clamp(0.5 - d * uScale, 0.0, 1.0);

  float chamferWidth = min(uBevel, max(r, 1.0));
  float chamfer = chamferWidth > 0.01 ? 1.0 - smoothstep(0.0, chamferWidth, -d) : 0.0;
  float2 slope = outward * chamfer;

  float2 wp = p / (220.0 * uWarpScale);
  float3 w1 = gradientNoise(wp);
  float3 w2 = gradientNoise(wp * 2.07 + 13.7);
  float2 ripple = (w1.yz + w2.yz * 0.5) * uWarp;
  slope += ripple * 0.008;

  float grain = valueNoise(float2(p.x * 0.008, p.y * 0.55)) * 0.45 + valueNoise(float2(p.x * 0.019 + 3.7, p.y * 0.23)) * 0.35 + valueNoise(float2(p.x * 0.004 + 9.2, p.y * 0.09)) * 0.2;
  float brush = uRough * uRough;
  slope.y += (grain - 0.5) * brush * 0.004;

  float3 normal = rotatePose(normalize(float3(slope, 1.0)), rotation, roll);
  float3 worldPosition = rotatePose(float3(p, 0.0), rotation, roll);
  float3 view = normalize(worldPosition - float3(0.0, 0.0, max(uSize.x, uSize.y) * 1.55));
  float3 bounce = reflect(view, normal);
  float2 q = bounce.xy / max(bounce.z, 0.2);

  float2 footprint = fwidth(q);
  float2 sigma = sqrt(float2(uBlur / VIEW) * float2(uBlur / VIEW) + footprint * footprint * 0.5);
  sigma += float2(0.004, 0.05) * uRough;

  // Keep the room's bright and occluded regions in every card format. A wide
  // card otherwise crops away the lower room, leaving only an even light band.
  float2 framing = float2(max(uSize.x, uSize.y)) / uSize;
  float2 environmentQ = q * framing;
  float2 environmentSigma = sigma * sqrt(framing);
  float2 toPointer = (uPointer - p) / (120.0 + uBlur * 4.0);
  float2 spread = toPointer * float2(1.0, 1.0 / (1.0 + 2.5 * uRough));
  float reach = dot(spread, spread);
  float glint = max(1.0 + 3.0 * dot(slope, toPointer), 0.0);
  float glare = (exp(-reach * 1.6) + exp(-reach * 0.35) * 0.15) * glint * uGlare * (1.0 + 0.8 * (grain - 0.5) * brush);
  float3 color;
  if (uTheme > 0.5) {
    float distantRoom = lightRoom(environmentQ, environmentSigma);
    float surfaceLight = (lightSoftbox(environmentQ, environmentSigma) * uShine + glare) * mix(0.4, 1.0, uMetal);
    color = uTint * (0.6 + 0.35 * clamp(distantRoom, 0.0, 1.15)) + float3(surfaceLight * 0.4);
  } else {
    // The accepted grey-metal path is unchanged and does not evaluate light optics.
    float3 scene = float3(room(environmentQ, environmentSigma));
    scene *= 1.0 + (grain - 0.5) * brush * 0.3;
    float highlight = (softbox(environmentQ, environmentSigma) * uShine + glare) * mix(0.4, 1.0, uMetal);
    color = float3(0.008) + uTint * (scene * 0.23 * uMetal + highlight * 0.38);
  }
  color = min(color, 0.7) + 0.3 * (1.0 - exp(-max(color - 0.7, 0.0) / 0.3));
  color = pow(clamp(color, 0.0, 1.0), float3(1.0 / 2.2));

  color += (hash(position) - 0.5) / 255.0;
  color = clamp(color, 0.0, 1.0);
  return half4(half3(color * coverage), half(coverage));
}
