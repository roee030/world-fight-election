# Distinct Attacks and Interactive Stages Plan

**Goal:** Give every roster fighter a readable attack identity and smoother presentation while a parallel workstream adds cosmetic stage reactions.

**Constraints:** Keep the 12-frame source contract, one combat engine, current hit windows/damage/reach, grounded shadows, pause semantics and mobile/Web budgets.

## Track A — fighter attack presentation

- [x] Add a validated, deep-copy data contract with one unique profile for every roster fighter and every ordinary attack.
- [x] Expand ordinary attack presentation clips to at least eight display frames using only the allowed source poses.
- [x] Add 60 Hz procedural in-between motion to `SpriteMotion`; freeze and mirror it with the existing fighter state.
- [x] Route attack start/finish/reset through the presentation API without changing combat authority.
- [ ] Verify profile coverage, visual uniqueness, source-pose safety, motion pause and the complete combat suite.
- [x] Inspect representative fast and heavy profiles in a 1280×720 Knesset Chamber fight; both fighters stayed grounded and fully visible.

## Track B — interactive stages (parallel agent)

- [ ] Audit stage construction and event signals.
- [ ] Define cosmetic-only reactions with deterministic limits and pause support.
- [ ] Implement a tested first vertical slice without touching combat outcomes.
- [ ] Inspect at 1280×720 and landscape-phone framing.

## Exit criteria

Every fighter has a distinct validated attack-presentation signature, attack clips expose at least eight display frames, simulation/fairness stays green, and the first stage-interaction slice reacts to combat without affecting damage or timing.
