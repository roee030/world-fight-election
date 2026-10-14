# Reactive Stages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bounded, pause-safe stage-coloured lighting reactions to strikes in all six existing arenas without changing combat.

**Architecture:** A focused `StageReactivity` Node3D owns two procedural lights and deterministic pulse state. `main.gd` creates it from existing stage metadata and forwards the existing `strike_landed` event, keeping the combat engine untouched.

**Tech Stack:** Godot 4.7, GDScript, headless Godot tests.

**Spec:** `docs/superpowers/specs/2026-10-14-reactive-stages-design.md`

## Global Constraints

- Do not modify `fighter.gd`, `data/combat.json`, combo data or fighter animation assets.
- Preserve all six stage IDs, full-frame backplates, floor alignment and 1280x720 `expand` behavior.
- Add no textures, audio or runtime downloads; use at most two bounded lights and two procedural glow quads.
- Presentation cannot affect combat state and must freeze through the existing scene-tree pause.

## Review Focus

- Unknown move IDs use the lightest safe impulse rather than producing a missing-key error.
- Negative or very large combo counts are clamped and cannot create unbounded energy.
- Repeated strikes keep energy at or below the cap.
- Rebuilding a stage frees the previous controller and starts from zero energy.
- The controller remains pausable and does not use render-frame or wall-clock timing.

---

### Task 1: Deterministic reactive stage lighting

**Files:**
- Create: `scripts/stages/stage_reactivity.gd`
- Create: `tests/test_stage_reactivity.gd`
- Modify: `scripts/main.gd`

**Interfaces:**
- Produces: `StageReactivity.configure(stage: Dictionary) -> void`
- Produces: `StageReactivity.react_to_strike(move: String, blocked: bool, combo: int) -> void`
- Produces: `StageReactivity.advance(delta: float) -> void`
- Consumes: existing stage fields `id`, `kind`, `accent`
- Consumes: existing `GameFighter.strike_landed(attacker, defender, move, blocked, combo)` signal

- [x] **Step 1: Write the failing integration test**

Create `tests/test_stage_reactivity.gd`. Instantiate the production script and assert: six stages configure their accent; heavy is stronger than light; blocked is weaker than a clean strike; combo boost caps; repeated impulses stay at or below `1.0`; `advance(0.25)` decays intensity; both created lights mirror the computed energy; and a real `main.gd` bout forwards `_on_strike_landed` to the selected stage controller.

- [x] **Step 2: Run the test to verify RED**

Run: `godot --headless --path . --script res://tests/test_stage_reactivity.gd`

Expected: FAIL because `scripts/stages/stage_reactivity.gd` and `_stage_reactivity` do not exist.

- [x] **Step 3: Implement the controller**

Add the three interfaces above. Use two `OmniLight3D` children and two radial emissive quads behind the fighters, `Node.PROCESS_MODE_PAUSABLE`, a maximum normalized pulse of `1.0`, a fixed decay of `1.8` per second and a maximum rendered light energy of `1.15`. Keep all state presentation-only.

- [x] **Step 4: Integrate the selected stage and strike signal**

In `_build_stage`, replace the previous controller, configure the new one from the selected stage and add it to `_arena`. In `_on_strike_landed`, forward the existing move/block/combo values after the current audio and camera response.

- [x] **Step 5: Verify focused behavior**

Run: `godot --headless --path . --script res://tests/test_stage_reactivity.gd`

Expected: PASS with no parse errors.

- [x] **Step 6: Verify adjacent contracts**

Run the stage, arena-bound, gameplay-polish, UI-presentation and mobile-control tests. Expected: all PASS.

- [x] **Step 7: Inspect the fight screen**

Open a bout at 1280x720 and a landscape-phone viewport. Confirm that the reaction colours fighters without covering the stage, HUD or touch controls and that pause visibly freezes the fade.

- [x] **Step 8: Commit**

Commit: `feat: add reactive arena lighting`
