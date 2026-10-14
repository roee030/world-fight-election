# First Production Fighter Trio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the playable 12-pose source sheets for Yair Lapid, Benny Gantz and Joint List with production art that carries their approved fast, heavy and dual-stance identities without changing combat rules.

**Architecture:** Generate one transparent 4×3 source sheet per fighter from the current card, current sheet and approved concept direction. Run the existing connected-component slicer to rebuild normalized frames and cards, then validate the asset contract and inspect Sprite Lab and live fights at desktop and landscape-phone sizes.

**Tech Stack:** Built-in ImageGen, PNG/RGBA, Pillow/SciPy slicer, Godot 4.7.

**Spec:** `docs/superpowers/specs/2026-10-14-character-visual-direction.md`

## Global Constraints

- Preserve the exact 12-pose order in `docs/character-pipeline.md` and a transparent 4×3 source sheet.
- Every pose faces screen-right and keeps the full body, feet and accessories inside its cell.
- Use the existing fighter identity and outfit; never paste a photographic face or substitute a generic body.
- Do not change damage, hit windows, reach, combo ownership, fighter height or match rules.
- Punch poses cannot contain the kick pose. Effects and motion trails remain runtime presentation rather than baked sheet elements.
- Preserve `FighterVisual` grounding, world-floor shadows, 1280×720 layout and landscape-phone controls.

## Review Focus

- Extended gloves, boots and the Joint List dual silhouette must remain attached to the correct pose after slicing.
- All 12 cells must contain exactly the intended fighter with no labels, floor, shadow or neighbouring-pose fragments.
- Lapid's kick and Gantz's heavy poses must retain the same visible body scale as their punches.
- Joint List must read as one dual-figure roster slot at gameplay size without exceeding the render budget.
- Cards regenerated from idle frames must still fit selection and HUD crops.

---

### Task 1: Contract regression and production metadata

**Files:**
- Create: `data/fighter_art_manifest.json`
- Modify: `tests/test_slice_sprite_sheets.py`

**Interfaces:**
- Produces: production status and approved archetype for `yair_lapid`, `benny_gantz` and `joint_list`.
- Consumes: `extract_pose_cells()` and the 4×3 asset contract.

- [x] Add a failing test that requires all three production IDs in the manifest and validates sheet RGBA mode, 4:3 dimensions, transparent pixels, twelve non-empty owned cells and the fixed pose order.
- [x] Run the focused Python test and confirm it fails because the manifest does not exist.
- [x] Add the manifest with the approved archetype and source-sheet path for each fighter; version/status tracks completed production honestly.
- [x] Run the focused Python test.

### Task 2: Lapid production sheet

**Files:**
- Modify: `assets/characters/sprite-sheets/new-roster/yair-lapid-sheet.png`
- Regenerate: `assets/characters/sprites/yair_lapid-0.png` through `yair_lapid-11.png`
- Regenerate: `assets/characters/yair-lapid-card.png`

**Interfaces:**
- Consumes: current Lapid card/sheet and FAST concept direction.
- Produces: one complete transparent 4×3 sheet and twelve normalized frames.

- [ ] Generate and inspect the sheet with narrow boxing silhouettes, fast straight punches and a distinct signature kick.
- [ ] Run `python tools/slice_sprite_sheets.py` and the focused scale/silhouette tests.
- [ ] Inspect all twelve normalized frames and commit the Lapid asset slice.

### Task 3: Gantz production sheet

**Files:**
- Modify: `assets/characters/sprite-sheets/new-roster/benny-gantz-sheet.png`
- Regenerate: `assets/characters/sprites/benny_gantz-0.png` through `benny_gantz-11.png`
- Regenerate: `assets/characters/benny-gantz-card.png`

**Interfaces:**
- Consumes: current Gantz card/sheet and HEAVY concept direction.
- Produces: one complete transparent 4×3 sheet and twelve normalized frames.

- [x] Generate and inspect the sheet with a broad planted silhouette, compressed wind-up and large full-body recoil.
- [x] Run the slicer and focused silhouette/grounding tests.
- [x] Inspect all twelve normalized frames and the in-game desktop/phone result.

### Task 4: Joint List production sheet

**Files:**
- Modify: `assets/characters/sprite-sheets/new-roster/joint-list-sheet.png`
- Regenerate: `assets/characters/sprites/joint_list-0.png` through `joint_list-11.png`
- Regenerate: `assets/characters/joint-list-card.png`

**Interfaces:**
- Consumes: current Joint List card/sheet and DUAL-STANCE ENSEMBLE concept direction.
- Produces: one complete transparent 4×3 sheet and twelve normalized frames.

- [x] Generate and inspect the sheet with a coherent two-figure silhouette, brown close-range lead and teal long-range lead alternating by pose.
- [x] Run the slicer, connected-component and render-budget tests.
- [x] Inspect all twelve normalized frames and the in-game desktop/phone result.

### Task 5: Runtime, responsive and full-suite verification

**Files:**
- Modify: `docs/SHARED_GAME_ROADMAP.md`
- Modify: `docs/superpowers/plans/2026-10-09-presentation-campaign-legal-analytics.md`

**Interfaces:**
- Consumes: all three production asset slices.
- Produces: verified milestone and shared handoff state.

- [ ] Run the focused geometry, attack identity, render-budget, combo and fairness tests.
- [ ] Run all Godot tests and `python -m unittest discover -s tests -p 'test_*.py'`.
- [ ] Inspect Sprite Lab and live-fight captures at 1280×720 and 844×390, including both facing directions and touch controls.
- [ ] Record the evidence in the shared roadmap and handoff, then commit and push the completed milestone when authorized.
