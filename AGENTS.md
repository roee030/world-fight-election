# Agent onboarding

Read `README.md`, `docs/character-pipeline.md`, `docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md` and the newest plan in `docs/superpowers/plans/` before editing. This file is the durable project context; do not rely on chat history.

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

1. Finish presentation polish across menu, selection, pause, HUD and result screens.
2. Tune hit range and feedback in the Sprite Lab/playground.
3. Move fighter timing, bounds and scale values into editable data files.
4. Implement finishers and celebrations from `docs/finisher-celebration-plan.md` only after the core combat suite remains green.
