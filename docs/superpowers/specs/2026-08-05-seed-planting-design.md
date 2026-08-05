# Seed Switching & Planting Design

**Date:** 2026-08-05
**Status:** Approved

## Overview

实现种子类型切换（corn/pumpkin/tomatoes）和播种逻辑。种子系统独立于工具系统，通过专用按键操作。

## Input Mapping

| 按键 | Action | 用途 |
|------|--------|------|
| C | `seed_toggle` | 循环切换种子类型 |
| F | `plant` | 在面向的 soil tile 上播种 |
| Q/E | `tool_backward`/`tool_forward` | 工具切换（不变） |
| Space | `action` | 工具使用（不变） |

## Architecture

### 1. Player (`player.gd`) — 种子管理

**新增属性：**
- `seeds: Array[String] = ["corn", "pumpkin", "tomatoes"]`
- `current_seed_idx: int = 0`

**输入处理（`_physics_process`）：**
- `seed_toggle` → 循环切换 `current_seed_idx`，种子切换不受 `is_using_tool` 限制
- `plant` → 调用 `_start_plant_action()`

**信号：**
- `plant_action(seed_name: String, target_world_pos: Vector2)` — 由 `plant_use()` 动画回调发射

### 2. Plant Scene (`plant.gd`) — 作物行为

**属性：**
- `crop_type: String` — 作物类型
- `growth_stage: int` (0–3) — 对应 Sprite2D 的 hframe
- `is_watered: bool` — 是否已浇水
- `growth_timer: Timer` — 动态创建的计时器

**方法：**
- `setup(crop_name: String)` — 设置作物类型，加载对应纹理，显示 frame 0
- `water()` — 标记已浇水，启动生长计时器

**生长逻辑：**
- 每轮间隔（如 5 秒）`growth_stage += 1`，更新 `$Sprite2D.frame`
- 到达 stage 3（成熟）停止计时器

**纹理映射：**
```
corn     → res://graphics/plants/corn.png
pumpkin  → res://graphics/plants/pumpkin.png
tomatoes → res://graphics/plants/tomatoes.png
```
每个纹理 4 帧（hframes=4）：seed → sprout → growing → mature

### 3. Game (`game.gd`) — 世界操作

**播种 `_handle_plant(seed_name, target_pos)`：**
1. `_world_to_tile(target_pos)` 获取 tile 坐标
2. 检查 tile 是否有 soil — 无 soil 则忽略
3. 检查 tile 是否已有 Plant 实例 — 已有则忽略
4. 实例化 Plant 场景 → `setup(seed_name)` → 添加到 `$Objects` → 放置在 tile 世界坐标

**浇水增强 `_handle_water()`：**
- 保留现有 soil → soil_water 逻辑
- 新增：浇水后检测该 tile 是否有 Plant → 有则调用 `plant.water()`

**信号连接（`_ready`）：**
- `_player.plant_action.connect(_on_plant_action)`

### 4. Player Scene 动画

需要在 AnimationTree 中添加 `plant` 工具状态的 blend_space 和 OneShot 支持，动画 keyframe 中调用 `plant_use()`。

## Files Changed

| File | Change |
|------|--------|
| `scenes/player/player.gd` | 新增 seeds 数组、种子切换、plant_action 信号、plant_use() |
| `scenes/level/plant.gd` | 实现 setup()/water()/生长计时器 |
| `scenes/level/game.gd` | 新增 _handle_plant()、修改 _handle_water()、连接信号 |
| `scenes/level/plant.tscn` | 移除硬编码 corn 纹理引用（改为动态加载） |

## Edge Cases

- 播种时如果 tile 不是 soil（是 grass/water）→ 静默忽略
- 同一 tile 已有 Plant → 静默忽略，不覆盖
- 未浇水时 Plant 保持在 stage 0，不生长
- 到达 stage 3 后计时器停止，不再生长
- 多次浇水同一 tile → 不重复触发 `plant.water()`
