// WaterHighlight.glsl
// 水面高光 shader: 高光纹理(UV * hlScale + flow) × 遮罩纹理(UV * maskScale)
// highlight UV: 2.0 ~ 3.0 (细碎高光)
// mask     UV: 0.3 ~ 0.6 (大块遮罩)

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
uniform float cFlowSpeedX;
uniform float cFlowSpeedY;
uniform float cHighlightIntensity;

void PS()
{
    vec2 uv = vTexCoord;
    float t = cElapsedTimePS;

    // highlight UV 缩放: 2.0 ~ 3.0 缓慢振荡
    float hlScale = 2.5 + 0.5 * sin(t * 0.3);

    // mask UV 缩放: 0.3 ~ 0.6 缓慢振荡
    float maskScale = 0.45 + 0.15 * sin(t * 0.2 + 1.0);

    // 高光采样 + 流动偏移
    vec2 flow = vec2(t * cFlowSpeedX, t * cFlowSpeedY);
    vec4 highlight = texture2D(sDiffMap, uv * hlScale + flow);

    // 遮罩采样 (低频大块)
    float mask = texture2D(sNormalMap, uv * maskScale).r;

    // 最终高光 = 高光 × 遮罩 × 强度
    vec3 finalHighlight = highlight.rgb * mask * cHighlightIntensity;

    gl_FragColor = vec4(finalHighlight, highlight.a * mask);
}
#endif
