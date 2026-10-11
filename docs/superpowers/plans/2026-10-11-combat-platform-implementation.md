# World Fight: Power Play Combat Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing offline game into the data-driven, testable **Power Play** fighting platform: varied play builds Special Energy, which creates meaningful power-move versus finisher choices, alongside expressive combat, comic items and character-intake tools.

**Architecture:** Extract deterministic rules from Godot presentation into a tick-driven `CombatWorld`, while adapting `Fighter` incrementally so existing finisher, combo, tutorial and CPU callers retain their contracts. Combat definitions live in validated JSON; rendering and labs consume the authoritative simulated state rather than creating their own rules.

**Tech Stack:** Godot 4.7+, GDScript, JSON data, existing sprite pipeline, headless Godot tests, Python unittest/Pillow tools.

**Spec:** `docs/superpowers/specs/2026-10-11-combat-platform-design.md`

## Global Constraints

- Preserve the 12-frame FighterVisual source contract, floor grounding, canvas scaling and LTR UI.
- Keep one combo engine in `fighter.gd` driven by `data/combos.json`; do not mutate returned combo arrays.
- Existing SP finisher rules, director, tutorials, visual assets and tests remain authoritative.
- Phone actions dispatch once on press; no motion inputs beyond forward/back double taps.
- Do not add online transport, app packaging, new fighter art, realistic weapons or gore.
- Every production task: RED test, minimal implementation, focused test, full Godot/Python suite and desktop/phone inspection.

## Review Focus

- A hit-stop frame must preserve buffered action presses rather than expiring them.
- A crouched or airborne target must be tested against its actual hurtbox, not an old distance shortcut.
- A render hitch must never alter a fixed-tick replay outcome.
- An item may never spawn under a fighter, repeatedly hit, or decide a round on its own below 5% HP.
- A generated sheet with a missing foot, opaque background, invalid grid or wrong pose count must be rejected before runtime import.

### Task 1: Deterministic Combat Harness and Replay Fixture

**Files:**
- Create: `scripts/combat/combat_world.gd`, `scripts/combat/combat_input.gd`, `scripts/combat/combat_replay.gd`, `tests/helpers/fight_sim.gd`, `tests/test_combat_world.gd`
- Modify: `scripts/fighter.gd`, `scripts/main.gd`

**Interfaces:**
- Produces `CombatWorld.step(tick: int, inputs: Dictionary) -> Array[Dictionary]`, `snapshot() -> Dictionary`, `restore(snapshot: Dictionary) -> void` and `CombatReplay.record(seed: int, inputs: Dictionary) -> void`.

- [ ] Write failing replay tests: equal seed/input logs produce equal snapshots after 600 ticks; snapshot/restore at tick 300 produces the same final snapshot; hit-stop does not age a buffered attack.
- [ ] Implement scalar-only snapshot, deterministic seed and fixed 60Hz stepping; adapt `Fighter` as a presentation-backed participant without deleting public fields.
- [ ] Run `godot --headless --path . --script res://tests/test_combat_world.gd`; expect PASS.
- [ ] Run all Godot/Python suites and inspect a normal 1280x720 match plus 780x360 phone fight.
- [ ] Commit: `feat: add deterministic combat replay harness`.

### Task 2: Validated Fighter and Move Data

**Files:**
- Create: `data/fighter_tuning.json`, `data/moves.json`, `scripts/combat/fighter_tuning.gd`, `tests/test_fighter_tuning.gd`
- Modify: `scripts/fighter.gd`, `scripts/cpu_brain.gd`, `scripts/character_debug.gd`, `README.md`

**Interfaces:**
- Produces `FighterTuning.load() -> Dictionary`, `FighterTuning.move(id: String) -> Dictionary`, `FighterTuning.fighter(id: String) -> Dictionary`.

- [ ] Write failing schema tests for every playable ID, all baseline moves, integer phase frames, valid clip mappings and safe default fallback.
- [ ] Migrate today’s HP, speed, reach, damage, timing and clip values without changing expected outcomes; expose current `MOVES` as read-only compatibility data.
- [ ] Run focused schema and existing fairness/combo tests; inspect Sprite Lab at 1280x720.
- [ ] Commit: `feat: move fighter timing and tuning into validated data`.

### Task 3: State Machine, Buffered Input and Movement

**Files:**
- Create: `scripts/combat/fighter_state.gd`, `tests/test_fighter_state.gd`, `tests/test_fighter_movement.gd`
- Modify: `scripts/fighter.gd`, `scripts/main.gd`, `scripts/cpu_brain.gd`, `scripts/virtual_stick.gd`

**Interfaces:**
- Produces `FighterState.Kind`, `Fighter.transition(next: FighterState.Kind) -> void`, and facing-relative `CombatInput` press/axis history.

- [ ] Write failing tests for legal/illegal state transitions, edge-triggered jump, no jump repeat while held, dash double-tap window, grounded-only facing change and capped push-box correction.
- [ ] Implement the explicit state machine with compatibility read-outs; add walk/backwalk, dash/backdash, soft push-box and hit/block pushback.
- [ ] Run focused tests, fairness test, tutorial test and screen inspections of walk/dash/jump on desktop and phone.
- [ ] Commit: `feat: add fighter states and responsive movement`.

### Task 4: Hitboxes, Hurtboxes and Air Combat

**Files:**
- Create: `scripts/combat/combat_boxes.gd`, `tests/test_combat_boxes.gd`, `tests/test_air_combat.gd`
- Modify: `data/moves.json`, `scripts/fighter.gd`, `scripts/fighter_visual.gd`, `scripts/character_debug.gd`, `docs/character-pipeline.md`

**Interfaces:**
- Produces `CombatBoxes.intersects(hitbox: Dictionary, hurtbox: Dictionary) -> bool` and `Fighter.active_boxes() -> Array[Dictionary]`.

- [ ] Write failing tests for active-window-only damage, facing/depth rejection, crouch-under-high, aerial target hits, CROSS anti-air and punch clips excluding frame 6.
- [ ] Replace distance-only attack resolution with data-defined boxes; implement jump squat, committed arc, landing and air punch/kick under the fixed clip contract.
- [ ] Add Sprite Lab hitbox/hurtbox/state/active-frame overlay; inspect left/right fighter, grounded feet and shadow at both required sizes.
- [ ] Commit: `feat: add frame-accurate combat boxes and air attacks`.

### Task 5: Defence, Throws, Launchers and Juggles

**Files:**
- Create: `tests/test_combat_responses.gd`, `tests/test_throw_juggle.gd`
- Modify: `data/moves.json`, `scripts/fighter.gd`, `scripts/main.gd`, `scripts/cpu_brain.gd`, `tests/test_combat_fairness.gd`

**Interfaces:**
- Produces `Fighter.receive_hit(payload: Dictionary) -> Dictionary`, `try_throw(rival: Fighter) -> bool`, and serializable `juggle_budget: int`.

- [ ] Write failing tests for blockstun/frame advantage, counter-hit bonus, throw break, strike beating a throw, three-hit airborne cap, gravity escalation and combo-breaker compatibility.
- [ ] Implement response data, counter feedback, throw state and launcher/juggle budget; update CPU only after 1v1 rules pass.
- [ ] Run combo/finisher/tutorial/fairness suites, then inspect block, throw, anti-air and juggle captures.
- [ ] Commit: `feat: add defence throws and bounded juggles`.

### Task 6: Comic Item System and Item Lab

**Files:**
- Create: `data/items.json`, `scripts/combat/combat_item.gd`, `scripts/combat/item_rules.gd`, `tests/test_combat_items.gd`
- Modify: `scripts/combat/combat_world.gd`, `scripts/fighter.gd`, `scripts/main.gd`, `scripts/character_debug.gd`, `scenes/character_debug.tscn`

**Interfaces:**
- Produces `CombatItem.State`, `ItemRules.spawn(world, definition_id: String) -> CombatItem`, `Fighter.try_pickup(item: CombatItem) -> bool`, and `Fighter.throw_item() -> void`.

- [ ] Write failing tests for neutral spawn distance, single active item, pickup range, guardable single-hit throw, break/despawn, deterministic replay and 5%-HP anti-KO rule.
- [ ] Implement microphone and briefcase prototype items with placeholder/code effects, carry anchor, throw and break; add Item Lab preset using production code.
- [ ] Run focused/full suites and inspect both items in Sprite Lab/Combat Lab at desktop and phone resolution.
- [ ] Commit: `feat: add deterministic comic combat items`.

### Task 7: Combat Lab, Feel Layer and Balance Slice

**Files:**
- Create: `scripts/ui/combat_lab.gd`, `tests/test_combat_lab.gd`
- Modify: `scenes/character_debug.tscn`, `scripts/character_debug.gd`, `scripts/fighter_visual.gd`, `scripts/main.gd`, `scripts/cpu_brain.gd`, `data/fighter_tuning.json`

**Interfaces:**
- Produces `CombatLab.load_replay(replay: Dictionary) -> void`, `frame_step() -> void`, and `export_replay() -> Dictionary`.

- [ ] Write failing tests proving the lab uses production `CombatWorld` state, frame-step does not consume unstepped inputs and export/import preserves final snapshot.
- [ ] Add state/frame/advantage/juggle/item overlays, replay controls and procedural foot-pivot feedback (hit flash, shake, landing dust) without changing geometry data.
- [ ] Tune four gameplay archetype vertical-slice fighters through data only, then prove existing fairness bounds and unique move/stat profiles.
- [ ] Inspect all lab modes plus normal match at 1280x720 and 780x360; commit `feat: add combat lab and gameplay identity tuning`.

### Task 8: Character Intake and Asset Validation Tools

**Files:**
- Create: `tools/character_intake.py`, `tools/validate_character_sheet.py`, `tests/test_character_intake.py`, `docs/character-generator-brief.md`
- Modify: `tools/slice_sprite_sheets.py`, `docs/character-pipeline.md`, `README.md`, `scripts/character_debug.gd`

**Interfaces:**
- Produces `python tools/character_intake.py --id <id> --concept <text>` and `python tools/validate_character_sheet.py <sheet.png>` with nonzero exit on a contract violation.

- [ ] Write fixture tests for valid transparent 4x3 sheet and invalid opaque/missing-cell/out-of-bounds sheets; assert prompt manifests never embed reference-image bytes or paths.
- [ ] Implement manifest/prompt template generation, image validation and Character Intake panel diagnostics; retain the existing slicer as the only runtime frame builder.
- [ ] Run Python suite, all Godot tests and Sprite Lab selection/fight screen visual inspection using an existing fixture.
- [ ] Commit: `feat: add character intake and art validation tools`.

### Task 9: Documentation, Regression Audit and Deferred-mode Boundary

**Files:**
- Modify: `README.md`, `AGENTS.md`, `docs/character-pipeline.md`, `docs/superpowers/specs/2026-10-11-combat-platform-design.md`
- Test: all `tests/test_*.gd`, `python -m unittest discover -s tests -p 'test_*.py'`

- [ ] Write regression assertions that snapshots contain no Node/Object references and every emitted event carries a fighter/team owner ID.
- [ ] Document controls, item rules, art intake, Combat Lab and the explicitly deferred online/2v2 boundary.
- [ ] Run complete suites and review test captures for no fighter cropping/floating, SP behaviour unchanged, paused combat frozen and RTL still LTR.
- [ ] Commit: `docs: record combat platform contracts and verification`.

## Self-review

- Spec coverage: Tasks 1–5 implement the core, Task 6 items, Task 7 tools/identity, Task 8 art intake, Task 9 future-boundary and docs.
- Type consistency: `CombatWorld`, `CombatInput`, `FighterTuning`, `CombatItem` and `CombatLab` are introduced before their consumers.
- Review focus is pinned in Tasks 1, 4, 6 and 8.
- No task introduces online transport, app packaging or new roster artwork.
