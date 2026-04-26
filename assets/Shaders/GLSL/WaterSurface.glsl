// WaterSurface.glsl
// 多层水面 Shader:
//   Layer 1: 蓝色基础水面 (sDiffMap)
//   Layer 2: 焦散网格线条 × 局部遮罩 (sSpecMap × sEmissiveMap), Additive
//   Layer 3: (鱼影在 Lua 侧用独立节点处理)
//
// Texture units:
//   0 (sDiffMap)     = water_base_tile.png     蓝色水底贴图
//   1 (sNormalMap)    = water_normal.png        法线 (供鱼影扭曲, 本 shader 内也用作微扰)
//   2 (sSpecMap)      = water_caustic_line.png  焦散线条 (黑底白线)
//   3 (sEmissiveMap)  = sun_glitter_mask.png    局部阳光遮罩

#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"

#ifdef COMPILEVS
void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = iTexCoord;
}
#endif

#ifdef COMPILEPS

uniform float cElapsedTimePS;

void PS()
{
    vec2 uv = vTexCoord;
    float t = cElapsedTimePS;

    // ---- Layer 1: 基础水面 ----
    // 缓慢向下漂移
    vec2 baseUV = uv * 1.0 + vec2(t * 0.005, t * 0.015);
    vec3 base = texture2D(sDiffMap, baseUV).rgb;

    // ---- 法线微扰 (让焦散线条有轻微扭曲) ----
    vec2 normalUV = uv * 2.0 + vec2(t * 0.008, t * 0.012);
    vec2 n = texture2D(sNormalMap, normalUV).rg * 2.0 - 1.0;
    vec2 distort = n * 0.008;

    // ---- Layer 2: 焦散线条 (双层叠加, 不同速度/缩放) ----
    vec2 causticUV1 = uv * 1.2 + vec2(t * 0.015, t * 0.008) + distort;
    vec2 causticUV2 = uv * 1.6 + vec2(-t * 0.010, t * 0.014) + distort * 0.7;

    float c1 = texture2D(sSpecMap, causticUV1).r;
    float c2 = texture2D(sSpecMap, causticUV2).r;

    // ---- 局部遮罩 (大块柔和明暗) ----
    vec2 maskUV = uv * 0.45 + vec2(t * 0.003, t * 0.005);
    float mask = texture2D(sEmissiveMap, maskUV).r;
    // 增强对比度: 让亮区更亮暗区更暗
    mask = smoothstep(0.25, 0.85, mask);

    // ---- 合成 ----
    // 焦散 = 双层叠加, 受遮罩调制
    vec3 caustic = vec3(c1 * 0.45 + c2 * 0.25);
    vec3 finalColor = base + caustic * mask;

    // 色调微调: 高光偏暖白, 整体偏蓝
    finalColor = mix(finalColor, finalColor * vec3(1.05, 1.08, 1.12), mask * 0.3);

    gl_FragColor = vec4(finalColor, 1.0);
}

#endif
