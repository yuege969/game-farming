# Tool Animation System Design

**Date:** 2026-08-04
**Status:** Approved

## Overview

Implement tool switching and usage animation logic for the player's AnimationTree. The AnimationTree already has a OneShot node wired between MoveStateMachine (default) and ToolStateMachine (one-shot tool animations). Three global input actions (`action`, `tool_forward`, `tool_backward`) drive the system.

## Architecture

All changes in `scenes/player/player.gd`. No scene changes needed — the AnimationTree BlendTree connections are already in place:

```
output ← OneShot (0: MoveStateMachine, 1: ToolStateMachine)
```

ToolStateMachine states: Start → hoe (auto), with transitions between axe/hoe/water and auto-advance to End on animation completion.

## State Variables

```gdscript
var tools: Array[String] = ["axe", "hoe", "water"]
var current_tool_idx: int = 1  # default to hoe (matches Start→hoe auto-transition)
var is_using_tool: bool = false
```

## Input Handling

### tool_forward / tool_backward
- Cycle `current_tool_idx` forward/backward through the tools array (wrapping)
- Only allowed when `is_using_tool == false`
- On switch: `playback.travel(tool_name)`, set the tool's blend_position to `last_direction`

### action
- Only allowed when `is_using_tool == false`
- Set current tool's blend_position → fire OneShot request → set `is_using_tool = true`
- Detect completion by tracking `parameters/OneShot/active` transition from true to false
- On completion: set `is_using_tool = false`

## Movement Lock

When `is_using_tool == true`:
- Skip movement input processing
- Set velocity to Vector2.ZERO
- Do not update MoveStateMachine blend positions or travel

## axe_use() Callback

The axe animation tracks call `axe_use()` at 0.4s. Define this method as a placeholder for future tool effect logic.

## Files Modified

- `scenes/player/player.gd` — add tool state vars, input handling, movement lock, OneShot trigger logic
