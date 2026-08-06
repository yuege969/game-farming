# Audio Playback Design

**Date:** 2026-08-06
**Status:** Approved

## Overview

Wire up the 5 existing AudioStreamPlayer2D nodes in `player.tscn` to play at
appropriate times during gameplay. All changes are confined to `player.gd`.

## Audio Nodes (already in scene)

| Node path | Audio file | Purpose |
|---|---|---|
| `Sounds/AxeSound` | `audio/axe.wav` | Axe swing |
| `Sounds/HoeSound` | `audio/hoe.wav` | Hoe till |
| `Sounds/WaterSound` | `audio/water.ogg` | Watering |
| `Sounds/StepSound` | `audio/step.mp3` | Footsteps |
| `Sounds/BackgroundSound` | `audio/music.mp3` | BGM loop |

## Implementation

### 1. Node references

Add `@onready` vars for all 5 AudioStreamPlayer2D nodes.

### 2. Background music

In `_ready()`, call `_bgm.play()` — the audio file's import settings control
looping (set to loop in the import or via `_bgm.finished.connect(_bgm.play)`).

### 3. Tool sounds

In `_start_tool_action()`, look up the current tool name and play the
corresponding sound before firing the animation OneShot:

- `"axe"` → `_axe_sound.play()`
- `"hoe"` → `_hoe_sound.play()`
- `"water"` → `_water_sound.play()`

### 4. Footstep sounds

Track a `_step_timer: float` in `_physics_process(delta)`:

- When moving (`velocity != 0` and not using tool): accumulate delta, play
  `_step_sound` every 0.35s, reset timer.
- When stopped or using tool: reset timer to 0 (so next move starts fresh).

## Scope

- Only `player.gd` is modified.
- No new audio files needed.
- No changes to `game.gd` or any other file.
