# Finish attacks and celebrations — system design

**Date:** 2026-10-07  
**Status:** Design approved with character direction corrections; implementation has not started.  
**Source material:** The supplied fighting-game tutorial transcript, `docs/finisher-celebration-plan.md`, the current Godot combat implementation, and the user-approved character list in this document.

**Implementation plan:** `docs/superpowers/plans/2026-10-07-finishers-celebrations-implementation.md`

## Purpose

Add a reliable, data-driven Finish Attack and post-match Celebration system to all 13 playable fighters. Each sequence must feel specific to its fighter while using one shared runtime, one validation path and one testing contract. Finishers must extend the real combat state machine rather than play as detached videos or bypass health, collision and round resolution.

This document is the durable source of truth for future agents. Read it together with `README.md`, `AGENTS.md`, `docs/character-pipeline.md` and the implementation plan created from this design.

## Lessons carried forward from the tutorial

The supplied tutorial recommends a staged production loop:

1. Build coherent character and prop assets from stable reference art.
2. Inspect animation frames, grounding and bounds in a Character Gym.
3. Activate attack bounds only during authored active frames.
4. Tune timing and framing in a playground before match integration.
5. Keep gameplay values in data that the game and debug tools load together.
6. Add special presentation such as portrait lightboxes only after the mechanic is correct.

Finishers follow that sequence. Visual spectacle never replaces deterministic hit timing, damage, pause support or validation.

## Player contract

A Finish Attack is eligible only when all conditions are true:

- The current round can win the match for the attacker.
- The defender has at most 15% of maximum health.
- The attacker has 100 Special Energy.
- Both fighters are grounded and neither is stunned, knocked down or recovering.
- The fighters are inside the finisher's configured activation range and facing correctly.
- The match is in `FIGHTING`, with no pause or result overlay.

Input behavior:

- A normal Special tap continues to use the existing special attack.
- Holding Special for `0.55` seconds while eligible confirms the Finish Attack.
- The HUD changes `SPECIAL READY` to `FINISH READY` while eligibility is true.
- The touch `MAX` button uses the same hold duration and progress feedback.
- Releasing before confirmation performs the normal special once. It must not perform both actions.

Failure behavior:

- If eligibility disappears before confirmation, the hold is cancelled without spending meter.
- Once the cinematic starts, meter is spent immediately.
- If an authored finisher opening misses, the cinematic ends, both fighters unlock and ordinary combat resumes.
- A successful finisher can emit one defeat event and one match transition only.

## Match state machine

The match owns an explicit state instead of combining booleans:

`ROUND_INTRO → FIGHTING → FINISHER_PROMPT → FINISHER_CINEMATIC → KO_HOLD → CELEBRATION → RESULT`

Additional rules:

- `PAUSED` is an overlay that freezes the current state, timelines, tweens, AI, timer, sound cues and particles.
- `FINISHER_PROMPT` does not freeze normal combat; it represents an eligible hold in progress.
- `FINISHER_CINEMATIC` locks ordinary fighter input and AI.
- The round timer freezes from confirmed activation through `RESULT`.
- `KO_HOLD` preserves the authored defeated pose and prevents automatic get-up.
- `CELEBRATION` starts only after the final hit and waits for an authored result marker.
- `RESULT` remains the existing victory or defeat presentation entry point.

## Runtime architecture

### `FinisherCatalog`

Loads and validates `data/finishers.json`. It exposes immutable definitions by fighter ID and rejects missing assets, unknown event types, invalid times, out-of-range hit events and roster gaps during tests.

### `FinisherDirector`

A dedicated node owned by the match scene. It:

- evaluates eligibility;
- tracks hold confirmation;
- enters and exits cinematic states;
- positions the fighters at deterministic stage-safe marks;
- runs timeline events;
- applies authored hit events;
- controls camera presets and portrait lightboxes;
- starts celebration timelines;
- hands control back to the match result flow.

It does not contain fighter-specific `if` branches. It executes the catalog definition.

### `FinisherActor`

A lightweight sprite and prop actor used for guests, projectiles, crowds, vehicles and animals. It supports:

- transparent texture or sprite-frame animation;
- normalized screen/world position;
- scale, facing and depth layer;
- enter, hold and exit motion;
- optional ground contact;
- automatic cleanup when the sequence ends.

### Existing fighter integration

`fighter.gd` keeps ordinary movement and combat. It gains a cinematic lock API and explicit methods for authored damage/reaction. It must not learn the individual story of any finisher.

`main.gd` owns the match state, HUD prompt, pause overlay and result handoff. `character_debug.gd` gains a Finishers tab that uses the same catalog and director.

## Data contract

Each roster entry in `data/finishers.json` has this shape:

```json
{
  "fighter_id": "bennet",
  "finisher_id": "startup_exit",
  "meter_cost": 100,
  "trigger_health_ratio": 0.15,
  "hold_seconds": 0.55,
  "activation_range": 1.75,
  "duration": 3.2,
  "camera_preset": "close_side",
  "events": [
    {"at": 0.0, "type": "portrait_lightbox"},
    {"at": 0.35, "type": "spawn_prop", "asset": "laptop"},
    {"at": 1.15, "type": "launch_prop", "target": "defender"},
    {"at": 1.48, "type": "hit", "damage": 999, "reaction": "finish_fall"},
    {"at": 1.48, "type": "camera_impact", "strength": 0.55},
    {"at": 2.25, "type": "celebration_start"}
  ],
  "celebration_id": "exit_success"
}
```

Allowed event types are deliberately limited:

- `portrait_lightbox`
- `fighter_clip`
- `spawn_actor`
- `spawn_prop`
- `move_actor`
- `launch_prop`
- `caption`
- `sound`
- `camera_preset`
- `camera_impact`
- `screen_flash`
- `hit`
- `defender_reaction`
- `celebration_start`
- `result_marker`
- `cleanup`

Every `hit` event has a unique event ID. The director records consumed IDs so a frame hitch or pause/resume cannot apply the same damage twice.

## Asset contract

Assets live under `assets/finishers/<fighter_id>/`:

- `actors/` — guest characters and crowds;
- `props/` — laptop, clock, oil barrel, flag, money and weapons;
- `effects/` — smoke, impact, muzzle flash and explosion frames;
- `celebration/` — fighter-specific celebration frames;
- `preview.png` — Sprite Lab preview used for review.

All actors and props use transparent PNG/WebP frames with a consistent painted fighting-game style. Photographs are reference material only and never appear pasted into the arena. Sarah and Yair Netanyahu use the supplied image only as facial reference for original caricature assets.

Technical requirements:

- Keep important action inside the 16:9 safe frame.
- Grounded actors include an authored foot baseline.
- Projectiles and aircraft may leave the safe frame only through intentional entrance or exit motion.
- Effects use atlases where possible and are freed at sequence completion.
- A finisher may use at most 12 simultaneously visible supporting actors on mobile.
- Web builds target a stable 60 FPS on a modern phone; effects have a reduced mobile density setting.
- No full-screen pre-rendered video is used. The system composes sprites, props, camera and effects at runtime.

## Camera and presentation

Shared camera presets:

- `close_side` — attacker and defender, waist-up impact framing.
- `wide_stage` — crowds, cattle, crocodiles and aircraft.
- `projectile_track` — follows a thrown or fired prop.
- `overhead_pass` — B-2 flyover.
- `victory_low` — grounded hero celebration.

Every sequence begins with one portrait lightbox. Camera shake is limited to authored impact events and capped for mobile. Captions such as `48 HOURS`, `DEMOCRACY` and `EXIT SUCCESS` are part of the data and use the game's UI typography.

## Approved fighter sequences

The exact runtime IDs are fixed and must be used in the catalog:

| Fighter | `fighter_id` | `finisher_id` |
|---|---|---|
| Bennet | `bennet` | `startup_exit` |
| Bibi | `bibi` | `family_business` |
| Yair Lapid | `yair_lapid` | `prime_time_rush` |
| Benny Gantz | `benny_gantz` | `independence_flag` |
| Avigdor Lieberman | `avigdor` | `oil_barrel_48` |
| Mansour Abbas | `mansour_abbas` | `coalition_cashstorm` |
| Gadi Eisenkot | `gadi_eisenkot` | `bazooka_command` |
| Yair Golan | `yair_golan` | `m16_burst` |
| Itamar Ben-Gvir | `itamar_ben_gvir` | `crocodile_release` |
| Bezalel Smotrich | `bezalel_smotrich` | `cattle_charge` |
| Aryeh Deri | `aryeh_deri` | `campaign_entourage` |
| Joint List | `joint_list` | `two_headed_chaos_squad` |
| Donald Trump | `trump` | `b2_flyover` |

### 1. Bibi — `family_business`

**Target duration:** 4.2 seconds.  
The arena darkens and Bibi poses at center-left. Sarah Netanyahu enters on a raised side spotlight and sings, producing two visible sound-wave impacts that stagger the defender without resolving the match. Yair Netanyahu enters as a theatrical comic-book villain and delivers the single final strike. The three characters remain inside the safe frame; guest art is a coherent caricature based on the supplied reference image.

**Celebration:** Bibi sits on a stylized royal throne. Sarah and Yair take positions on either side for a short family victory tableau. Result marker at approximately 2.0 seconds after the final hit.

### 2. Bennet — `startup_exit`

**Target duration:** 3.2 seconds.  
Bennet opens a glowing laptop showing scrolling code, closes it, spins and throws it like a disc. The laptop tracks the defender, displays an impact error flash and explodes into pixels. One final hit event resolves the match.

**Celebration:** Bennet catches a second laptop, opens it and the screen displays `EXIT SUCCESS`; pixel confetti rises behind him.

### 3. Gadi Eisenkot — `bazooka_command`

**Target duration:** 3.7 seconds.  
Eisenkot braces a stylized bazooka, aims, fires and absorbs the recoil. The projectile uses `projectile_track`; the explosion applies one final hit and leaves a short smoke column.

**Celebration:** Eisenkot lowers the bazooka, straightens his uniform and gives a grounded military salute.

### 4. Avigdor Lieberman — `oil_barrel_48`

**Target duration:** 3.5 seconds.  
Lieberman rolls and then throws a marked oil barrel toward the defender. A large clock appears above it at `48:00`, accelerates toward `00:00`, and the barrel explodes at zero. The timer is part of the finisher build-up; the oil barrel explosion is the final hit.

**Celebration:** Lieberman stands with folded arms while a large clock behind him remains fixed on `48:00`.

### 5. Itamar Ben-Gvir — `crocodile_release`

**Target duration:** 4.0 seconds.  
Ben-Gvir gestures forward and opens a stylized enclosure. Three cartoon crocodiles attack in a readable left-to-right sequence. The first two are stagger hits; the third is the final impact.

**Celebration:** The crocodiles line up beside him while he poses toward the camera.

### 6. Bezalel Smotrich — `cattle_charge`

**Target duration:** 4.1 seconds.  
Smotrich signals with a ranch-style whistle. A cattle herd crosses the wide-stage camera in two depth layers. Dust frames appear near the floor and the central animal carries the final hit event.

**Celebration:** Smotrich adopts a ranch pose while the herd settles as silhouettes in the background.

### 7. Mansour Abbas — `coalition_cashstorm`

**Target duration:** 3.6 seconds.  
Abbas throws bundles of dollar bills upward. They expand into a money storm with three controlled multi-hit events, followed by one oversized bundle as the final strike.

**Celebration:** A gentle rain of bills continues while Abbas calmly counts one bundle and faces the camera.

### 8. Aryeh Deri — `campaign_entourage`

**Target duration:** 4.0 seconds.  
Deri raises a campaign folder and summons a clearly authored group of caricatured Haredi campaign operatives with signs and binders. They cross the stage as a coordinated political entourage rather than an undifferentiated crowd. Two foreground passes stagger; the last sign impact finishes.

**Celebration:** The arena quiets, Deri puts away the folder, covers his head and prays to God in a respectful grounded pose. The celebration uses no attack effects.

### 9. Joint List — `two_headed_chaos_squad`

**Target duration:** 3.8 seconds.  
The two heads argue, point in opposite directions and accidentally summon a miniature masked comic sabotage squad. The squad is entirely fictional and carries no ethnic or religious markers. Their chaotic crossing produces two stagger hits and one final comic blast.

**Celebration:** The two-headed fighter sits at a small table and both heads happily eat knafeh, briefly competing for the final piece before sharing it.

### 10. Benny Gantz — `independence_flag`

**Target duration:** 3.4 seconds.  
Gantz unfurls a large Israeli Independence Day flag. The cloth arcs through the foreground, wraps the defender visually without hiding the safe frame, and the flagpole delivers the final grounded strike. Blue and white confetti follows the impact.

**Celebration:** Gantz plants the flag, stands tall beside it and salutes as Independence Day confetti falls.

### 11. Donald Trump — `b2_flyover`

**Target duration:** 4.5 seconds.  
Trump points upward. The camera widens and a stylized B-2 passes overhead in silhouette. Target markers converge on the defender, followed by a non-graphic cinematic blast and one final hit event.

**Celebration:** Trump performs a short victory dance while the B-2 makes a distant background pass.

### 12. Yair Lapid — `prime_time_rush`

**Target duration:** 3.2 seconds.  
Lapid enters a boxer stance and performs six rapid authored punches. The first five use low stagger damage with clear combo numbers; time slows before a final uppercut resolves the match.

**Celebration:** Lapid raises both boxing gloves under camera-flash effects and bounces once in a grounded winner stance.

### 13. Yair Golan — `m16_burst`

**Target duration:** 3.5 seconds.  
Golan takes a stable firing stance with a stylized M16. Two controlled muzzle-flash bursts cause stagger reactions; a final stronger impact resolves the match. Effects remain non-graphic and use clear hit timing rather than continuous damage.

**Celebration:** Golan lowers the weapon safely. A Kaplan protest crowd fills the background holding repeated `DEMOCRACY` signs while he raises a hand toward them. The crowd remains behind the fighter and inside the stage-safe region.

## Celebration rules

- Celebrations are separate timelines referenced by `celebration_id`.
- Every celebration begins from a grounded, collision-safe winner position.
- The loser stays in the authored finish pose and cannot recover.
- Background crowds never cover the winner's face, result title or action buttons.
- Celebration duration is 1.8–2.8 seconds before the result marker.
- The result overlay may fade in over the final held pose; it must not interrupt the defining celebration beat.
- A reduced-motion setting replaces repeated motion with a stable final tableau.

## Sprite Lab and review workflow

The Fighter Lab gains a `FINISHER` mode with:

- attacker and defender selector;
- eligible, hit, miss and pause/resume scenarios;
- timeline scrubber and current event ID;
- 0.25×, 0.5× and 1× playback;
- frame stepping;
- ground line and 16:9 safe-frame overlays;
- visibility toggles for collision, hurt, guard and attack bounds;
- mobile effect-density preview;
- validation output from `FinisherCatalog`.

No fighter is integrated into matches before its entire sequence is approved in the Lab.

## Testing contract

### Shared system tests

- Eligibility requires match point, critical defender health and full meter.
- A Special tap remains backward compatible.
- Hold confirmation cannot trigger both special and finisher.
- Meter is spent once at confirmed activation.
- Ordinary input, AI and round timer freeze during the cinematic.
- Pause freezes and resumes at the same timeline time and event ID.
- Hit events fire only once and in time order.
- Missed openings resume combat without resolving the round.
- Successful finishers emit exactly one defeat and one result transition.
- Celebration starts after KO hold and reaches one result marker.
- Cleanup removes all temporary actors, props, sounds and effects.

### Per-fighter tests

- A catalog entry exists for every playable ID.
- Referenced assets exist and load.
- Timeline times are monotonic and within duration.
- The final hit occurs before `celebration_start`.
- The celebration contains one `result_marker`.
- All grounded actors have valid foot baselines.
- The 1280×720 safe-frame capture contains no cropped required actors.
- A landscape-phone capture loads the sequence at reduced density without errors.

## Incremental delivery and Git discipline

Implementation is delivered in small, reviewable pushes.

### Foundation pushes

1. Match state enum, eligibility tests and hold-input behavior.
2. Catalog schema, validator and placeholder assets.
3. Director timeline engine, pause support and cleanup tests.
4. Fighter Lab finisher controls and safe-frame preview.

### Fighter pushes

Each fighter receives its own commit and push. A fighter is complete only when all items are done:

- final transparent assets committed;
- catalog definition validated;
- Finish Attack plays in Fighter Lab;
- Finish Attack triggers through real match input;
- hit timing, KO and result transition tests pass;
- Celebration plays and remains grounded;
- 1280×720 screenshot reviewed;
- landscape-phone screenshot reviewed;
- checklist below updated with commit hash and notes;
- full Godot and Python suites pass;
- commit pushed to `main`.

Recommended implementation order minimizes risk:

1. Bennet — validates thrown-prop path.
2. Bibi — validates guest actors, sound waves and multi-character tableau.
3. Yair Lapid — validates rapid multi-hit timing.
4. Benny Gantz — validates large cloth/flag framing.
5. Avigdor Lieberman — validates timer plus explosive prop.
6. Mansour Abbas — validates particle-like money actors.
7. Gadi Eisenkot — validates projectile and smoke.
8. Yair Golan — validates burst events and background crowd celebration.
9. Itamar Ben-Gvir — validates multiple animal actors.
10. Bezalel Smotrich — validates a larger moving herd.
11. Aryeh Deri — validates foreground entourage and quiet celebration transition.
12. Joint List — validates miniature squad and two-character celebration props.
13. Donald Trump — validates aircraft, wide camera and mobile effect reduction.

## Progress checklist

Update this section in the same commit that completes each item.

### Shared foundation

- [x] Match state and eligibility — 2026-10-07: pure boundary rules and round-flow state tracking; 16 Godot tests passed.
- [ ] Hold input and HUD prompt
- [x] Catalog and validation — Task 2: 13 disabled entries and separate celebration objects, strict schema/resource/link validation, copy isolation and asset validator.
- [ ] Timeline director
- [ ] Pause and cleanup
- [ ] Fighter Lab support
- [ ] Camera, lightbox, sound and result handoff

### Fighters

- [ ] Bennet — `startup_exit`
- [ ] Bibi — `family_business`
- [ ] Yair Lapid — `prime_time_rush`
- [ ] Benny Gantz — `independence_flag`
- [ ] Avigdor Lieberman — `oil_barrel_48`
- [ ] Mansour Abbas — `coalition_cashstorm`
- [ ] Gadi Eisenkot — `bazooka_command`
- [ ] Yair Golan — `m16_burst`
- [ ] Itamar Ben-Gvir — `crocodile_release`
- [ ] Bezalel Smotrich — `cattle_charge`
- [ ] Aryeh Deri — `campaign_entourage`
- [ ] Joint List — `two_headed_chaos_squad`
- [ ] Donald Trump — `b2_flyover`

## Definition of complete

## Delivery records

| Date | Delivery | Verification | Next step |
|---|---|---|---|
| 2026-10-07 | Implementation plan published; task 1 rules and match-state tracking implemented | Eligibility test observed failing before implementation, then passing; full Godot suite 16/16 | Catalog and roster stubs (task 2); no fighter finisher marked complete yet |
| 2026-10-07 | Task 2 catalog and roster scaffolding | Catalog/roster RED→GREEN; 10 Python tests passed; reviewer regressions reject unfinished celebrations and late portraits | Task 3 input; fighters remain disabled until final art and sequence review |

Execution ruling: this managed worktree has a detached HEAD. Preserve it and publish using `git push origin HEAD:main` after integrating remote updates normally. No forced pushes.

The feature is complete when all 13 finishers and celebrations satisfy the data contract, pass shared and per-fighter tests, have reviewed desktop and phone captures, preserve ordinary Special behavior, pause correctly, resolve the match once and are deployed successfully through GitHub Pages.
