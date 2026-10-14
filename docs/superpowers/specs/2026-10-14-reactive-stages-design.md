# World Fight — Reactive Stages Design

**Date:** 2026-10-14

## Intent

Make the six existing arenas feel connected to the fight without adding hazards, changing combat outcomes, obscuring the backplates or increasing the Web download with new art. The first milestone adds a restrained, stage-coloured lighting response to landed and blocked strikes.

## First milestone

- Every registered stage owns one lightweight `StageReactivity` node while a bout is active.
- A landed strike emits a short light pulse using the stage's existing accent colour.
- Heavy, kick and special attacks create a stronger pulse than a jab. A block remains readable but quieter than a clean hit. Combo count adds a small capped boost.
- The response is presentation only. It cannot change fighter position, health, hit detection, energy, AI or round state.
- The effect advances in physics time, uses no wall-clock reads and is pausable with the scene tree. Rebuilding or changing the stage resets the pulse and frees the previous controller.
- The implementation uses two bounded `OmniLight3D` nodes plus two radial emissive quads and no new textures, audio or runtime downloads. The quads make the response visible because the existing stage backplates are intentionally unshaded.

## Constraints

- Preserve the current full-frame stage backplate, floor alignment and 1280x720 `expand` behavior.
- Keep effects behind fighters, HUD and touch controls and low enough that fighters and health state remain readable.
- Do not edit `fighter.gd`, `data/combat.json`, combo data or fighter animation assets.
- Keep the current six stage IDs and selection flow.
- Pause must freeze the pulse at its current intensity and resume from the same value.
- Headless tests must be able to drive the response deterministically without rendering.

## Engineering boundary

`scripts/stages/stage_reactivity.gd` owns stage presentation state. `main.gd` creates it from the selected stage dictionary and forwards the existing `strike_landed` signal. The controller exposes `configure(stage)`, `react_to_strike(move, blocked, combo)` and `advance(delta)`; `_physics_process` delegates to `advance`.

## Later milestones

After visual play-testing, stage-specific actors or props may be added behind the same controller: studio tally lights, a Kaplan protest-light rhythm and architectural light movement for the Knesset arenas. They remain cosmetic until a separate product decision explicitly approves gameplay hazards.

## Success criteria

- All six stage definitions build the controller with their own accent.
- Hit, block, move weight and combo cap produce deterministic bounded impulses.
- The pulse decays to zero, never exceeds its energy cap and does not advance while the game is paused.
- Existing stage selection, arena-bound, pause and combat tests stay green.
