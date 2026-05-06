---
name: lighting-and-shadows
description: "UrhoX 引擎光影渲染完整指南，涵盖灯光组预设、三种灯光类型（方向光/点光/锥光）、阴影配置、Zone 环境光/雾效、Renderer 全局渲染设置。Use when users need to (1) 添加光照/灯光/阴影到 3D 场景, (2) 配置日夜/黄昏光照环境, (3) 设置阴影质量/软阴影/阴影级联, (4) 配置 Zone 环境光/雾效, (5) 调整全局渲染参数（HDR/阴影贴图/各向异性等）, (6) 解决阴影闪烁/条纹/彼得潘等问题。"
---

# 光影渲染指南

## 快速开始：LightGroup 预设

推荐一键配置场景光照（含 Zone + 方向光 + 阴影）：

```lua
local lgFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
local lg = scene_:CreateChild("LightGroup")
lg:LoadXML(lgFile:GetRoot())
```

| 预设 | 说明 |
|------|------|
| `LightGroup/Daytime.xml` | 白天 |
| `LightGroup/Dusk.xml` | 黄昏 |
| `LightGroup/Night.xml` | 夜晚 |

## 手动创建灯光

### 方向光（太阳/月亮）— 亮度单位: lux

```lua
local lightNode = scene_:CreateChild("Sun")
lightNode.direction = Vector3(0.6, -1.0, 0.8)
local light = lightNode:CreateComponent("Light")
light.lightType = LIGHT_DIRECTIONAL
light.color = Color(1.0, 0.95, 0.8)
light.brightness = 1.0
light.specularIntensity = 0.5
light.castShadows = true
```

### 点光（灯泡/火把）— 亮度单位: candela

```lua
local pNode = scene_:CreateChild("PointLight")
pNode.position = Vector3(0, 3, 0)
local light = pNode:CreateComponent("Light")
light.lightType = LIGHT_POINT
light.color = Color(1.0, 0.8, 0.5)
light.brightness = 100.0
light.range = 10.0
light.castShadows = true
```

### 锥光（手电/聚光灯）— 亮度单位: candela

```lua
local sNode = scene_:CreateChild("SpotLight")
sNode.position = Vector3(0, 5, 0)
sNode.direction = Vector3(0, -1, 0)
local light = sNode:CreateComponent("Light")
light.lightType = LIGHT_SPOT
light.brightness = 200.0
light.range = 15.0
light.fov = 45.0
light.castShadows = true
```

## 阴影配置

### 全局设置（Renderer）

```lua
renderer.drawShadows = true
renderer.shadowMapSize = 2048                     -- 512/1024/2048/4096
renderer.shadowQuality = SHADOWQUALITY_PCF_24BIT  -- 推荐
renderer.shadowSoftness = 2.0                     -- 0=硬阴影
```

阴影质量枚举：
`SHADOWQUALITY_SIMPLE_16BIT`, `SHADOWQUALITY_SIMPLE_24BIT`,
`SHADOWQUALITY_PCF_16BIT`, `SHADOWQUALITY_PCF_24BIT`（推荐）,
`SHADOWQUALITY_VSM`, `SHADOWQUALITY_BLUR_VSM`

### 单灯阴影参数

```lua
-- 偏移（修复条纹/彼得潘）
light.shadowBias = BiasParameters(0.00025, 0.5, 0.5)
-- BiasParameters(constantBias, slopeScaledBias, normalOffset)

-- 级联阴影（仅方向光）
light.shadowCascade = CascadeParameters(10.0, 30.0, 80.0, 0.0, 0.8)
-- CascadeParameters(split1, split2, split3, split4, fadeStart, biasAutoAdjust)

-- 聚焦（提高有效分辨率）
light.shadowFocus = FocusParameters(true, true, true, 0.5, 1.0)
-- FocusParameters(focus, nonUniform, autoSize, quantize, minView)

light.shadowIntensity = 0.0    -- 0=全黑, 1=无阴影
light.shadowResolution = 1.0   -- 倍率 0.25~1.0
```

### 阴影问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 条纹/摩尔纹 | constantBias 太小 | 增大 BiasParameters 的 constantBias |
| 彼得潘（悬空） | constantBias 太大 | 减小 constantBias，增大 normalOffset |
| 远处阴影模糊 | 级联分配不合理 | 调整 CascadeParameters 的 split 值 |
| 阴影闪烁 | 贴图分辨率低 | 增大 shadowMapSize 或启用 shadowFocus |

## Zone 环境光与雾效

```lua
-- 获取默认 Zone（推荐）
local zone = renderer:GetDefaultZone()

-- 环境光
zone.ambientColor = Color(0.3, 0.3, 0.4)
-- 渐变环境光（天顶到地面）
zone.ambientGradient = true
zone.ambientStartColor = Color(0.5, 0.6, 0.8)  -- 天顶
zone.ambientEndColor = Color(0.2, 0.2, 0.15)    -- 地面

-- 雾效
zone.fogColor = Color(0.6, 0.7, 0.8)
zone.fogStart = 50.0    -- 起始距离（米）
zone.fogEnd = 300.0     -- 完全覆盖距离

-- 高度雾
zone.heightFog = true
zone.fogHeight = 0.0
zone.fogHeightScale = 0.1
```

## Renderer 全局参数速查

```lua
renderer.HDRRendering = true
renderer.specularLighting = true
renderer.textureAnisotropy = 8              -- 1/2/4/8/16
renderer.textureFilterMode = FILTER_ANISOTROPIC
renderer.dynamicInstancing = true
renderer.maxShadowMaps = 4
renderer.reuseShadowMaps = true
```

## 完整示例：白天户外场景

```lua
function CreateLighting()
    -- 太阳方向光
    local sunNode = scene_:CreateChild("Sun")
    sunNode.direction = Vector3(0.5, -1.0, 0.7)
    local sun = sunNode:CreateComponent("Light")
    sun.lightType = LIGHT_DIRECTIONAL
    sun.color = Color(1.0, 0.95, 0.85)
    sun.brightness = 1.2
    sun.castShadows = true
    sun.shadowBias = BiasParameters(0.00025, 0.5, 0.5)
    sun.shadowCascade = CascadeParameters(10.0, 30.0, 80.0, 0.0, 0.8)
    sun.shadowFocus = FocusParameters(true, true, true, 0.5, 1.0)

    -- Zone 环境光 + 雾
    local zone = renderer:GetDefaultZone()
    zone.ambientColor = Color(0.35, 0.35, 0.4)
    zone.fogColor = Color(0.7, 0.75, 0.85)
    zone.fogStart = 80.0
    zone.fogEnd = 400.0

    -- 全局阴影
    renderer.drawShadows = true
    renderer.shadowMapSize = 2048
    renderer.shadowQuality = SHADOWQUALITY_PCF_24BIT
    renderer.shadowSoftness = 1.5
end
```
