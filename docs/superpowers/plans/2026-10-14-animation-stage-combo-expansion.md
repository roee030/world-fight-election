# Animation, Stage and Combo Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real supplemental fighter drawings, visible living-stage reactions and readable named combo payoffs without changing combat authority.

**Architecture:** The canonical twelve-pose fighter sheet remains the required source contract. Optional twelve-pose transition sheets add presentation-only textures through `FighterVisual`; fighters without a transition sheet retain the tested fallback. `StageReactivity` gains bounded stage-kind props driven by existing strike/combo signals, while the existing combo engine remains authoritative and the HUD displays its named-string signal.

**Tech Stack:** Godot 4.7 GDScript, PNG RGBA sprite sheets, Python/Pillow slicer tests, JSON combat data.

**Spec:** `docs/superpowers/specs/2026-10-14-game-upgrade-design.md`

## Global Constraints

- Preserve the canonical 12-frame source contract, grounding geometry and punch/kick ownership.
- Presentation never changes damage, reach, hit windows, combo recognition or AI decisions.
- Pause freezes fighters and stage reactions.
- Keep 1280x720 `expand`, landscape-phone controls and Web/mobile budgets usable.
- Use the existing combo engine in `fighter.gd`; never add another combo tracker.

## Review Focus

- Missing supplemental sheets fall back to canonical animation without errors.
- Supplemental kick frames cannot appear in punch clips and all frames keep transparent padding and a shared floor baseline.
- Stage props remain behind fighters, cap their movement and reset when the stage changes.
- Pausing freezes every stage prop and animation transition.
- Named combo HUD copy fits desktop and landscape-phone layouts.

---

### Task 1: Supplemental fighter transition art

**Files:**
- Create: `assets/characters/sprite-sheets/transitions/benny-gantz-transitions.png`
- Create: `assets/characters/sprite-sheets/transitions/joint-list-transitions.png`
- Create: `assets/characters/transitions/<id>-0.png` through `<id>-11.png`
- Create: `tools/slice_transition_sheets.py`
- Modify: `scripts/fighter_visual.gd`
- Test: `tests/test_fighter_transition_frames.gd`
- Test: `tests/test_slice_transition_sheets.py`

**Interfaces:**
- Produces: `FighterVisual._presentation_sequence(character_id, clip_name, canonical_frames) -> Array`
- Produces: optional `res://assets/characters/transitions/<id>-<index>.png`

- [x] Write failing fallback, frame-count, ownership, alpha and grounding tests.
- [x] Add the deterministic transition-sheet slicer and generated Gantz/Joint List assets.
- [x] Load supplemental frames for idle, walk, jab, cross and kick while retaining canonical contact poses.
- [x] Run focused sprite, geometry, render-budget and combat tests.
- [x] Inspect both fighters at 1280x720 and 844x390.

### Task 2: Stage-kind interactive props

**Files:**
- Modify: `scripts/stages/stage_reactivity.gd`
- Modify: `tests/test_stage_reactivity.gd`

**Interfaces:**
- Produces: bounded `CrowdWave`, `StudioSweep` and `StreetDust` presentation nodes selected from `stage.kind`
- Consumes: existing `react_to_strike(move, blocked, combo)` and `advance(delta)`

- [x] Write failing tests for stage-specific prop selection, bounded response, reset and pause behavior.
- [x] Add one lightweight prop family per stage kind behind the fight plane.
- [x] Drive prop amplitude from existing strike and combo pulses with deterministic decay.
- [x] Run stage, pause, arena and mobile tests and inspect both target viewports.

### Task 3: Named combo payoff in combat HUD

**Files:**
- Modify: `scripts/main.gd`
- Modify: `tests/test_combo_strings.gd`
- Modify: `tests/test_ui_presentation.gd`

**Interfaces:**
- Consumes: existing `GameFighter.combo_string(who, name, damage)`
- Produces: two-line `combo_label` containing the authored combo name and hit/damage result

- [x] Write a failing integration assertion that a completed signature string exposes its authored name in the HUD.
- [x] Render the authored name above the hit/damage line without a second tracker.
- [x] Verify all universal/signature strings, fairness, desktop layout and landscape-phone layout.

### Task 4: Integration and shared handoff

**Files:**
- Modify: `docs/SHARED_GAME_ROADMAP.md`
- Modify: `README.md`

- [x] Run the complete Godot and Python suites.
- [x] Record delivered fighters, stage behaviors, controls and remaining roster transition-art batches.
- [x] Commit only owned files and preserve unrelated workspace changes.
