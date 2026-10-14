# Distinct Attacks and Interactive Stages Plan

**Goal:** Give every roster fighter a readable attack identity and smoother presentation while a parallel workstream adds cosmetic stage reactions.

**Creative target:** Strive-like impact and character posing, Rivals-like readable living stages, and Brawlhalla-like accessibility and roster variety. Preserve the current round-based one-on-one rules; this milestone does not convert the game into a platform fighter.

**Constraints:** Keep the 12-frame source contract, one combat engine, current hit windows/damage/reach, grounded shadows, pause semantics and mobile/Web budgets.

## Track A — fighter attack presentation

- [x] Add a validated, deep-copy data contract with one unique profile for every roster fighter and every ordinary attack.
- [x] Expand ordinary attack presentation clips to at least eight display frames using only the allowed source poses.
- [x] Add 60 Hz procedural in-between motion to `SpriteMotion`; freeze and mirror it with the existing fighter state.
- [x] Route attack start/finish/reset through the presentation API without changing combat authority.
- [x] Verify profile coverage, visual uniqueness, source-pose safety, motion pause and the complete combat suite.
- [x] Inspect representative fast and heavy profiles in a 1280×720 Knesset Chamber fight; both fighters stayed grounded and fully visible.
- [x] Replace two-pose attack snapping with twelve presentation steps and at least four distinct anticipation/contact/recovery poses per strike, while preserving the twelve-frame source contract.
- [x] Keep a clickable `SP` control visible in desktop fights without exposing the full phone control cluster.

## Track B — interactive stages (parallel agent)

- [x] Audit stage construction and event signals.
- [x] Define cosmetic-only reactions with deterministic limits and pause support.
- [x] Implement a tested first vertical slice without touching combat outcomes.
- [x] Inspect at 1280×720 and landscape-phone framing.

## Exit criteria

Every fighter has a distinct validated attack-presentation signature, attack clips expose twelve display steps with at least four distinct source poses, simulation/fairness stays green, desktop and phone layouts expose SP, and the first stage-interaction slice reacts to combat without affecting damage or timing.

## Next milestone — compact unique kits

- Define one role and preferred range for each fighter.
- Give every fighter one signature ordinary-move modifier and one signature combo, using the existing combat and combo engines.
- Strengthen anticipation, contact pose, hit-stop and recovery readability without adding a large command list.
- Verify that no fighter dominates fairness and that players can identify the fighter's style after a short round.
