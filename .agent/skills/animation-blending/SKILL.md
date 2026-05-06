---
name: animation-blending
description: "UrhoX 引擎动画融合完整指南，涵盖 AnimationController 多层动画、骨骼遮罩（StartBone）、AnimationStateMachine 状态机、BlendSpace 混合空间、AimOffset 瞄准偏移。Use when users need to (1) 实现边跑边攻击/上下半身分离动画, (2) 配置动画层级和权重混合, (3) 使用 AnimationStateMachine 状态机, (4) 配置 BlendSpace 混合空间（8方向移动等）, (5) 实现 AimOffset 瞄准偏移, (6) 解决动画卡帧/抽搐/融合不平滑等问题, (7) 设置动画触发器和事件回调。"
---

# 动画融合指南

## 核心概念

- **动画层级（Layer 0~255）**：高层级覆盖低层级同名骨骼
- **起始骨骼（StartBone）**：限制动画只作用于某骨骼及其子骨骼
- **权重（Weight 0~1）**：控制动画混合强度
- **混合模式**：`ABM_LERP`（线性插值）、`ABM_ADDITIVE`（叠加）

## AnimationController 基础用法

### 播放动画

```lua
local animCtrl = node:CreateComponent("AnimationController")

-- 排他播放（淡出同层其他动画，用于状态切换：Idle↔Walk↔Run）
animCtrl:Play("Models/Run.ani", 0, true, 0.2)
-- Play/PlayExclusive(动画路径, 层级, 是否循环, 淡入时间)

-- 叠加播放（不影响同层动画，用于触发一次性动作）
animCtrl:Play("Models/Attack.ani", 1, false, 0.1)
```

### 上下半身分离（边跑边攻击）

```lua
-- Layer 0: 全身跑步（基础层）
animCtrl:PlayExclusive("Models/Run.ani", 0, true, 0.2)

-- Layer 1: 上半身攻击
animCtrl:Play("Models/Attack.ani", 1, false, 0.1)

-- 关键：限制攻击动画只影响脊椎以上骨骼
animCtrl:SetStartBone("Models/Attack.ani", "Spine")
-- 骨骼名严格区分大小写！Mixamo 模型通常为 "mixamorig:Spine"

-- 确保权重为 1.0（完全覆盖上半身）
animCtrl:SetWeight("Models/Attack.ani", 1.0)

-- 播完后自动淡出（防止卡在最后一帧）
animCtrl:SetAutoFade("Models/Attack.ani", 0.2)
```

### 常用 API 速查

```lua
-- 播放控制
animCtrl:Play(name, layer, looped, fadeIn)         -- 叠加播放
animCtrl:PlayExclusive(name, layer, looped, fade)  -- 排他播放
animCtrl:Stop(name, fadeOut)                       -- 停止动画
animCtrl:StopLayer(layer, fadeOut)                  -- 停止整层
animCtrl:StopAll(fadeTime)                         -- 停止全部

-- 混合控制
animCtrl:Fade(name, targetWeight, fadeTime)        -- 渐变权重
animCtrl:FadeOthers(name, targetWeight, fadeTime)  -- 淡出其他
animCtrl:SetWeight(name, weight)                   -- 设置权重
animCtrl:SetSpeed(name, speed)                     -- 播放速度（负数=倒放）
animCtrl:SetBlendMode(name, ABM_ADDITIVE)          -- 叠加混合

-- 骨骼遮罩
animCtrl:SetStartBone(name, boneName)              -- 限制骨骼范围

-- 淡出与完成
animCtrl:SetAutoFade(name, fadeOutTime)            -- 播完自动淡出
animCtrl:SetRemoveOnCompletion(name, true)         -- 播完自动移除

-- 状态查询
animCtrl:IsPlaying(name)       -- 是否在播放
animCtrl:IsAtEnd(name)         -- 是否播完
animCtrl:GetTime(name)         -- 当前时间
animCtrl:GetLength(name)       -- 动画总时长
```

## AnimationStateMachine（高级状态机）

适用于复杂角色动画（多状态 + 条件转换 + 混合空间）。

### 基础用法

```lua
local fsm = modelNode:CreateComponent("AnimationStateMachine")
fsm:LoadFromJSONFile(cache:GetResource("JSONFile", "FSM/Character.fsm"))
fsm:Start()

-- 设置参数驱动状态转换
fsm:SetFloat("moveSpeed", speed)
fsm:SetFloat("direction", dir)
fsm:SetBool("isCrouching", crouching)
fsm:SetTrigger("jump")       -- 触发器（一次性）

-- 查询
local state = fsm:GetCurrentState(0)   -- 第0层当前状态名
local trans = fsm:IsTransitioning(0)   -- 是否在过渡中
```

### FSM JSON 结构示例

```json
{
  "layers": [
    {
      "name": "BaseLayer",
      "defaultState": "Idle",
      "states": {
        "Idle": {
          "animation": "Models/Idle.ani",
          "loop": true
        },
        "Run": {
          "blendSpace": "FSM/Locomotion.blendspace",
          "loop": true
        }
      },
      "transitions": [
        {
          "from": "Idle", "to": "Run",
          "condition": "moveSpeed > 0.1",
          "duration": 0.2
        }
      ]
    },
    {
      "name": "UpperBody",
      "defaultState": "Empty",
      "boneMask": "UpperBody",
      "states": {
        "Attack": {
          "animation": "Models/Attack.ani",
          "loop": false
        }
      }
    }
  ],
  "boneMasks": {
    "UpperBody": {
      "startBone": "Bip001 Spine"
    }
  }
}
```

### BlendSpace（混合空间）

用于参数驱动的多动画混合（如 8 方向移动）：

```json
{
  "type": "polar",
  "parameterX": "direction",
  "parameterY": "moveSpeed",
  "points": [
    { "animation": "Models/WalkForward.ani",  "x": 0,   "y": 1 },
    { "animation": "Models/WalkRight.ani",    "x": 90,  "y": 1 },
    { "animation": "Models/WalkBack.ani",     "x": 180, "y": 1 },
    { "animation": "Models/WalkLeft.ani",     "x": 270, "y": 1 },
    { "animation": "Models/RunForward.ani",   "x": 0,   "y": 5 },
    { "animation": "Models/RunRight.ani",     "x": 90,  "y": 5 }
  ]
}
```

## AimOffset 瞄准偏移

对指定骨骼做程序化旋转，实现角色瞄准：

```lua
local aimOffset = modelNode:CreateComponent("AimOffset")
-- 添加受影响骨骼（骨骼名, pitch权重, yaw权重）
aimOffset:AddBone("Bip001 Spine", 0.40, 0.40)
aimOffset:AddBone("Bip001 Spine1", 0.35, 0.35)
aimOffset:AddBone("Bip001 Head", 0.25, 0.25)
-- 权重之和 = 1.0，旋转分散到多骨骼更自然

aimOffset:SetMaxPitch(50)    -- 最大俯仰角
aimOffset:SetMaxYaw(30)      -- 最大偏航角
aimOffset:SetEnabled(true)

-- 每帧更新瞄准角度
aimOffset:SetPitch(cameraPitch)
aimOffset:SetYaw(cameraYaw - characterYaw)
```

## 动画事件

```lua
-- 动画完成事件
SubscribeToEvent("AnimationFinished", function(eventType, eventData)
    local animName = eventData["Name"]:GetString()
    local looped = eventData["Looped"]:GetBool()
end)

-- 动画触发器（在动画特定时间点触发）
SubscribeToEvent("AnimationTrigger", function(eventType, eventData)
    local triggerName = eventData["Name"]:GetString()
    local time = eventData["Time"]:GetFloat()
    -- 典型用途：脚步声、攻击判定帧、特效触发
end)
```

## 问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 动画切换抽搐 | fadeTime=0 | 设 0.1~0.2 的淡入淡出 |
| 上半身没播放攻击 | 骨骼名拼错 | 检查大小写，Mixamo 带 `mixamorig:` 前缀 |
| 攻击完卡在最后一帧 | 未设淡出 | 用 `SetAutoFade(name, 0.2)` |
| 全身都在攻击 | 没设 StartBone | `SetStartBone(name, "Spine")` |
| 状态机不转换 | 参数未更新 | 确保每帧 `SetFloat/SetBool` |

## 参考

- API 文档: `engine-docs/api/animation.md`（完整 AnimationController/AnimationState/AnimationStateMachine API）
- 完整示例: `examples/22-third-person-shooter/`（状态机 + 混合空间 + AimOffset + 骨骼遮罩）
