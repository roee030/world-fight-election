# World Fight: Power Play Combat Platform Design

**Status:** approved for execution by the product owner on 2026-10-11.

## Intent

World Fight must become a deep, readable, mobile-friendly 2.5D fighting game in the spirit of Brawlhalla, Street Fighter and Tekken: each round is driven by spacing, timing, defence, combos, launchers, items and spectacular finishers—not by looping pictures or button spam. This original combat identity is called **Power Play**: a player gains Special Energy by varied, assertive play (clean hits, counters, throws, item interaction and well-timed defence), then chooses whether to spend it on a 55% power move or save it for a 100% SP finisher. The immediate scope is the offline combat platform and creator tooling. Online play, app-store packaging and new character artwork are deliberately deferred.

The game keeps its satirical roster, 1280x720 canvas, sprite-based 12-frame fighter contract, existing finishers and touch-first controls. It must feel good with the current roster before any new art is required.

## Goals

1. A deterministic, fixed-tick combat simulation with an explicit fighter state machine and data-defined moves.
2. Frame-accurate active windows and data-defined hitboxes/hurtboxes; crouching, jumping and blocking have meaningful tactical results.
3. Distinct fighter play styles from data: statistics, move properties, signatures and future special moves can differ without forked combat code.
4. Real fighting-game decisions: fast movement, dash, air attacks, anti-air, blockstun, counter hits, launch/juggle rules, throws and short target combos.
5. Grounded, non-graphic stage props: pick up, carry, throw, drop and break items. Items are optional tactical tools, not random unavoidable damage.
6. Existing finishers continue to obey their separate cinematic contract: 30% max HP, one activation at full Special Energy, range decides hit/miss, celebration only for a match-winning KO.
7. In-project tools make tuning and art intake easy: Combat Lab, Sprite Lab overlays, Item Lab, replayable scripted tests and a character-intake validator.
8. A future online/2v2 implementation can use the same pure simulation, but neither is delivered in this batch.

## Non-goals

- No online transport, matchmaking, accounts, rollback session UI, store submission or KMP/Unity migration.
- No new roster art or automatic image generation API. The owner will create images with another engine later.
- No real-world weapons, gore, or realistic harm. Items are comic props (microphone, placard, briefcase, foam gavel, ballot box).
- No replacement of the FighterVisual 12-frame source contract or generic photo-billboard fighters.
- No complex motion inputs that make touch controls inaccessible.

## Core model

At 60 simulation ticks per second, `CombatWorld` owns fighter, item and match state. It accepts only packed player commands for a numbered tick and produces a read-only event stream (`hit`, `block`, `throw`, `launch`, `item_pickup`, `item_break`, `finisher_start`). Godot nodes render that state and play audio/VFX; they do not decide outcomes. Randomness comes from a saved integer seed.

Each fighter has exactly one primary state:

`IDLE, WALK, DASH, JUMP_SQUAT, AIR, LAND, ATTACK, BLOCK, BLOCKSTUN, HITSTUN, LAUNCH, KNOCKDOWN, GETUP, THROW, ITEM_PICKUP, ITEM_CARRY, KO, CINEMATIC`.

Moves are phases inside `ATTACK` (`startup`, `active`, `recovery`) and use integer frames rather than elapsed floating-point time. Existing public fields remain compatibility read-outs until CPU, tutorial, HUD and finishers are migrated.

## Combat rules

- Inputs are stored in a 30-frame facing-relative ring buffer. Action presses occur once on press; buffered inputs do not expire during hit-stop.
- Every move declares startup, active and recovery frames; one or more hitboxes; hit/block responses; cancel routes; hit-stop; pushback; and a clip mapping.
- Hurtboxes are standing, crouching, airborne, knocked-down or invulnerable. A hit requires an active attack box to intersect a rival hurtbox in the correct facing/depth band.
- `JAB`, `CROSS`, `KICK`, `SP`, `GUARD`, jump and movement remain the only player-facing baseline controls. Double-tap forward/back becomes dash/backdash; no quarter-circle motions are required.
- Guard produces blockstun and pushback. A counter hit during startup gets a defined hitstun bonus. Strings stop on block. Existing combo breaker remains a 35%-energy GUARD double tap during hitstun.
- Launchers enter `LAUNCH`; air hits may continue a juggle only while the shared juggle budget remains. Each follow-up increases gravity and damage scaling, and a hard 3-hit airborne cap forces a fall.
- Throws beat a nearby guarding rival, lose to an active strike, and are breakable only by a matching throw input within a generous 8-frame window. They never interact with a cinematic finisher.

## Items

An item definition declares spawn weight, world hitbox, carry anchor, durability, throw trajectory, damage/stun/pushback, and VFX/SFX IDs. `ItemState` is `SPAWNED`, `CARRIED`, `THROWN`, `BROKEN` or `DESPAWNING`.

- A maximum of one neutral item may exist in a 1v1 round. Spawn is telegraphed and begins only after the opening neutral phase; it must be at least 1.4m from either fighter.
- `GUARD + toward item` picks it up when within 0.45m. Carrying replaces the fighter's normal attack buttons with light swing/heavy throw, but SP is unchanged.
- A thrown item hits once, can be guarded, breaks on body/stage collision, and cannot deal a KO by itself below the target's final 5% HP. This preserves comeback gameplay.
- Items are disabled in ranked/competitive rules later by a single ruleset flag. Training and casual local rules enable them.

## Data and character identity

`data/fighter_tuning.json` is the source of truth. It contains defaults plus one override block per existing roster ID: max health, walk/dash/jump values, weight, hurtbox profile, damage multiplier, archetype tag, move overrides and signature metadata. Values initially mirror today’s balance; the system ships with neutral differences only, then uses four existing fighters as a fully tuned vertical slice before applying stronger identity to all 13.

`data/moves.json` holds universal move frame data and hitbox geometry. `data/items.json` holds comic prop definitions and rulesets. Existing `data/combos.json` remains the only combo-string engine and gains move IDs/launch rules rather than a second combo tracker.

Archetypes are `RUSHDOWN`, `BALANCED`, `HEAVY`, `RANGE`, `TRICKSTER`. They are gameplay labels, not locked classes: the actual numbers and moves are authoritative.

## Character creation pipeline

The owner supplies a reference image and a written concept to an external image generator. The project supplies a safe intake path, not generation itself:

1. `tools/character_intake.py` creates a non-sensitive prompt brief and a `<id>.json` manifest template. It records only the roster ID, art direction and intended archetype; it never copies the source photo into shipped assets.
2. The generator output must be one transparent 4x3 sheet following `docs/character-pipeline.md`: consistent full-body character, right-facing poses, no labels/background.
3. `tools/validate_character_sheet.py` validates PNG transparency, 4x3 grid, silhouette continuity, all required cells and safe bounds before slicing.
4. The existing slicer creates the twelve runtime frames, and a new `character_intake` test verifies card, portrait, frames, geometry and tuning manifest as one transaction.
5. Sprite Lab presents frame, baseline, state, hitbox/hurtbox and clip timing overlays; a new Character Intake panel shows explicit failures and the generator brief.

No character is marked playable until the pipeline and visual inspection both pass.

## Tools and workflow

- **Combat Lab:** deterministic 1v1 sandbox with move timeline, inputs, state, hitboxes, hurtboxes, advantage, juggle budget, item controls, pause/frame-step and replay export.
- **Sprite Lab:** extends the current lab, using the production combat state and production tuning data.
- **Item Lab:** Combat Lab preset that pins an item, its owner and facing; validates pickup/throw/guard/break without random spawns.
- **Replay fixture:** a compact input log plus seed that can replay exact simulations in tests or visually. This is the future foundation for online diagnostics, but creates no networking now.

## Free-library decisions

- **Adopt later:** [LimboAI](https://github.com/limbonaut/limboai), MIT, only for the presentation-level CPU decision tree after deterministic combat rules are stable. It will express personalities such as pressure, bait, item use and punish; it never owns hit resolution.
- **Evaluate later:** [GUT](https://github.com/bitwes/Gut), MIT, if the existing standalone headless test format becomes too cumbersome. Do not introduce two competing test runners during core migration.
- **Defer:** [Godot Rollback Netcode](https://github.com/SnoringCatGames/godot-rollback-netcode), when online begins. `CombatWorld` is designed to meet its snapshot/replay needs, but this batch installs no networking addon.
- **Reject for combat simulation:** visual/state-chart addons. The combat state machine remains a small, explicit pure-code model so that a 60Hz replay and future rollback cannot be affected by scene-node signals or animation timing.

## Delivery order and acceptance

1. Safety harness/replay plus extracted data with no intentional gameplay change.
2. State and input migration, then movement/air combat/hitboxes.
3. Block/counter/throw/launch/juggle behaviour and Combat Lab diagnostics.
4. Item system with two comic prototype items and Item Lab.
5. Visual feel, CPU adaptation, balance and four-fighter identity vertical slice.
6. Character intake/validation tools, documentation and full regression/visual validation.

Each task starts with a failing headless test, retains the complete existing finisher/tutorial/combo contracts, then passes the full Godot and Python suites and receives a 1280x720 plus 780x360 visual review.

## Deferred architecture constraints

`CombatWorld` must be pure enough to snapshot/restore using only serializable numbers, arrays and dictionaries. Rendering state, sounds, UI nodes, `PhysicsBody` queries and wall-clock time may not influence a tick. This is required before future rollback online or 2v2. Team ownership is stored on every fighter and event now, but the public match mode remains 1v1 until the separate 2v2 plan.
