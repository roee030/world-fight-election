# Agent onboarding

Read `README.md`, `docs/character-pipeline.md`, `docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md` (including its 2026-10-08 amendment) and the newest plan in `docs/superpowers/plans/` before editing. This file is the durable project context; do not rely on chat history.

## Product goal

Build a polished satirical 2.5D fighting game in Godot 4. The quality target is a readable console fighting game: strong character identity, immediate hit feedback, clear UI hierarchy and no floating or cropped fighters.

## Non-negotiable implementation rules

- Use the existing sprite fighter pipeline. Never replace a fighter with a photo billboard or a generic body with a pasted face.
- Keep the 1280×720 reference layout usable with Godot canvas scaling.
- All fighters use the same 12-frame source contract and `FighterVisual` geometry system.
- Character height, pixel scale and floor correction are separate values. Adjust the correct value instead of compensating with arbitrary transforms.
- Shadows remain on the world floor during jumps.
- An attack counts only during its active window, within reach and in the correct facing direction.
- The gold HUD bar is Special Energy. UI text must identify it.
- A match finisher deals 30% of the rival's max HP; it ends a round only when that empties the bar and celebrates only when it wins the match. Phone controls are `JAB`, `CROSS`, `MAX` (55%), `SP` (100%) and `GUARD`; every touch action dispatches once, on press.
- The window uses the `expand` stretch aspect: never assume the viewport is exactly 1280×720. Anchor HUD/touch elements to edges and centre 1280-wide screens.
- Keep `tests/test_combat_fairness.gd` green when tuning AI or damage. CPU behaviour lives in `scripts/cpu_brain.gd`; Special Energy carries over between rounds of one match.
- The UI must stay left-to-right on RTL locales (Hebrew users); never remove the forced LTR layout direction.
- Punch clips (`jab`, `cross`, `hook`) must never contain the kick frame (frame 6 of the 12-frame contract).
- Menus share the console style helpers in `main.gd` (`_screen_title`, `_split_background`, `_bottom_bar`, `_primary_button`, `_secondary_button`) and `scripts/ui/ornament.gd`. The bundled font lacks symbols such as ← ✓ ⛶; use plain text.
- Player selection chooses only the player fighter. Quick Fight chooses a different CPU rival randomly.
- Pause freezes combat, timers, AI, animations and round transitions.
- Do not commit `.godot`, exports, browser traces, temporary renders, portable tools or the raw `Universal Base Characters[Standard]` folder.

## Main files

- `scripts/main.gd`: screens, HUD, stage alignment and match flow.
- `scripts/fighter.gd`: combat rules and AI.
- `scripts/fighter_visual.gd`: art clips, height and grounding.
- `scripts/character_debug.gd`: Sprite Lab.
- `tools/slice_sprite_sheets.py`: connected-component frame extraction.
- `tools/build_portraits.py`: roster portrait derivation.

## Roster IDs

`bennet`, `avigdor`, `bibi`, `yair_golan`, `aryeh_deri`, `yair_lapid`, `mansour_abbas`, `benny_gantz`, `itamar_ben_gvir`, `bezalel_smotrich`, `gadi_eisenkot`, `trump`, `joint_list`.

When adding a fighter, update roster data, geometry, card, portrait, twelve sprite frames, tests and README together.

## Workflow

1. Reproduce a bug in the smallest headless test or Sprite Lab scenario.
2. Add the failing regression test.
3. Change the smallest production surface that fixes the root cause.
4. Run the focused test, then the full Godot and Python suites.
5. Open the relevant screen at 1280×720 and inspect clipping, grounding and readability.
6. Update docs if the asset contract, controls or state machine changed.

Never claim a visual or behavior fix without automated evidence and a screen inspection when visual output is involved.

## Current roadmap

All 13 finishers and celebrations are implemented. Their delivery record is tracked in `docs/superpowers/plans/2026-10-07-finishers-celebrations-implementation.md` and the approved spec. Catalog entries and celebrations are separate objects in `data/finishers.json`; new `implemented=false` entries must never activate. Preserve one `FINISH` button per fighter in Fight Lab and keep the complete-roster visual-budget test green. Run Python tests with `python -m unittest discover -s tests -p 'test_*.py'` (bare unittest discovers no tests).

1. Finish presentation polish across menu, selection, pause, HUD and result screens.
2. Tune hit range and feedback in the Sprite Lab/playground.
3. Move fighter timing, bounds and scale values into editable data files.
4. Polish the completed finisher roster without changing approved hit ownership, cleanup or celebration contracts.
