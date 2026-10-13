# Combat Data Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the current combat move, motion, input-buffer and Special Energy tuning values into validated data without changing gameplay behavior.

**Architecture:** A focused `CombatData` RefCounted loader owns validation, immutable cached source data and deep-copy reads from `data/combat.json`. `GameFighter` remains the sole combat engine and consumes that data, preserving its public constants temporarily only where existing callers require compatibility.

**Tech Stack:** Godot 4.7 GDScript, JSON, headless Godot tests.

**Spec:** `docs/superpowers/specs/2026-10-14-game-upgrade-design.md`

## Global Constraints

- Preserve all current numeric behavior in this milestone.
- Keep one combat engine in `scripts/fighter.gd` and one combo engine driven by `data/combos.json`.
- Attacks hit only during active windows, in reach, in depth lane and in the committed facing direction.
- Keep the 1280×720 `expand` layout, forced LTR, 30% finisher damage and current touch dispatch contract.
- Run focused tests, every Godot test and the Python suite before completion.

## Review Focus

- Missing or malformed `combat.json` fails validation with a useful error rather than silently changing combat.
- A caller mutating returned data cannot alter later fighters or tests.
- Move windows remain ordered: `startup + active <= duration` and `cancel_from <= cancel_to <= duration`.
- All combo route move IDs exist in combat data; an unknown move is rejected.
- 60 Hz simulation produces the same damage, combo reachability and meter behavior as the pre-migration baseline.

---

### Task 1: Validated combat data contract

**Files:**
- Create: `data/combat.json`
- Create: `scripts/combat/combat_data.gd`
- Create: `tests/test_combat_data.gd`

**Interfaces:**
- Produces: `CombatData.load_data(path: String = "res://data/combat.json") -> Dictionary`
- Produces: `CombatData.validate(data: Dictionary) -> PackedStringArray`
- Produces: `CombatData.current() -> Dictionary`, returning a deep copy

- [x] **Step 1: Write `test_combat_data.gd` against the missing API**

Assert literal current values for JAB and jump, no validation errors for the shipped file, validation errors for malformed windows and unknown required fields, and copy isolation after mutating a returned move.

- [x] **Step 2: Run the test and observe the expected failure**

Run: `godot --headless --path . --script res://tests/test_combat_data.gd`
Expected: FAIL because `scripts/combat/combat_data.gd` and `data/combat.json` do not exist.

- [x] **Step 3: Add the JSON and minimal loader/validator**

Copy the current `MOVES`, input buffer, movement, damage scale and meter values exactly. Validate required sections/types, finite non-negative numbers, ordered move windows and known clips.

- [x] **Step 4: Run the focused test**

Expected: PASS with no warnings or parse errors.

- [x] **Step 5: Commit the independently reviewable data contract**

Commit: `feat: define validated combat tuning data`

### Task 2: GameFighter consumes combat data

**Files:**
- Modify: `scripts/fighter.gd`
- Modify: `tests/test_combo_strings.gd`
- Test: `tests/test_live_combat_damage.gd`
- Test: `tests/test_fighter_motion_integration.gd`
- Test: `tests/test_combat_fairness.gd`

**Interfaces:**
- Consumes: `CombatData.current() -> Dictionary`
- Preserves: `GameFighter.MOVES`, `INPUT_BUFFER_SECONDS`, `SPECIAL_COST` and `DAMAGE_SCALE` compatibility reads during this milestone

- [x] **Step 1: Add a failing behavior test that injects a valid alternate data fixture**

Prove a fighter uses fixture move damage, movement speed and input-buffer duration in real simulation; the production change that should fail it is bypassing loaded data for a hard-coded value.

- [x] **Step 2: Run the test and observe values remain hard-coded**

Expected: FAIL on the fixture-derived damage or motion assertion.

- [x] **Step 3: Replace hard-coded reads in `fighter.gd` with one per-instance combat-data snapshot**

Keep static compatibility constants at current values only for callers that still read them; all runtime decisions use the validated snapshot. Add a test-only fixture path through constructor/setup dependency, not a production-only reset method.

- [x] **Step 4: Run motion, damage, combo and fairness tests**

Expected: all focused tests PASS and fairness remains inside its existing thresholds.

- [x] **Step 5: Commit the runtime migration**

Commit: `refactor: drive fighter tuning from combat data`

### Task 3: Cross-data validation and documentation

**Files:**
- Modify: `scripts/combat/combat_data.gd`
- Modify: `tests/test_combat_data.gd`
- Modify: `README.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Extends: `CombatData.validate(data)` to verify every route move in `data/combos.json` exists in `moves`

- [x] **Step 1: Add failing tests for an unknown combo route move and unknown fighter speed override**

Expected: current validator misses the cross-file errors.

- [x] **Step 2: Run the focused test and verify RED**

Run: `godot --headless --path . --script res://tests/test_combat_data.gd`

- [x] **Step 3: Add cross-data validation and document the tuning workflow**

Document which values live in `combat.json`, which remain in `combos.json`, and the focused/full verification commands.

- [x] **Step 4: Run full verification**

Run all `tests/test_*.gd`, then `python -m unittest discover -s tests -p 'test_*.py'`.
Expected: every test passes.

- [x] **Step 5: Commit the milestone record**

Commit: `docs: record combat data tuning contract`
