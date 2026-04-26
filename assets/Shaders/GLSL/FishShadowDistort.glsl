#ifdef COMPILEVS

attribute vec3 iPos;
attribute vec2 iTexCoord;

uniform mat4 cModelViewProj;

varying vec2 vTexCoord;

void VS()
{
    gl_Position = cModelViewProj * vec4(iPos, 1.0);
    vTexCoord = iTexCoord;
}

#endif


#ifdef COMPILEPS

uniform sampler2D sDiffMap;     // 鱼影 sprite
uniform sampler2D sNormalMap;   // water_normal.png
uniform float cElapsedTimePS;
uniform float cDistortStrength; // 小鱼 0.010 / 中鱼 0.014 / 大鱼 0.018

varying vec2 vTexCoord;

void PS()
{
    vec2 uv = vTexCoord;

    // 两层水波扰动，避免重复感
    vec2 nUv1 = uv * 1.8 + vec2(cElapsedTimePS * 0.025, cElapsedTimePS * 0.015);
    vec2 nUv2 = uv * 3.2 + vec2(-cElapsedTimePS * 0.018, cElapsedTimePS * 0.022);

    vec2 n1 = texture2D(sNormalMap, nUv1).rg * 2.0 - 1.0;
    vec2 n2 = texture2D(sNormalMap, nUv2).rg * 2.0 - 1.0;

    vec2 distortedUV = uv + (n1 * 0.65 + n2 * 0.35) * cDistortStrength;

    vec4 fish = texture2D(sDiffMap, distortedUV);

    // 鱼影颜色压深，保持水下阴影感
    fish.rgb *= vec3(0.55, 0.75, 0.85);

    // Alpha 呼吸 0.45 ~ 0.65，用 uv + 时间产生自然波动
    float fishAlpha = 0.55 + 0.1 * sin(cElapsedTimePS * 0.8 + uv.y * 6.2832);
    fish.a *= fishAlpha;

    gl_FragColor = fish;
}

#endif
