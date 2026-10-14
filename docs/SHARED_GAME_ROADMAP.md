# World Fight — Shared Game Roadmap

**Last updated:** 2026-10-14
**Purpose:** One shared source of truth for every contributor and agent.

Before editing, read `AGENTS.md`, this roadmap, and the linked specification or plan for the chosen workstream. Update this roadmap whenever a workstream starts, changes scope, reaches a milestone or hands off.

## Shared creative direction

World Fight is an original, accessible 2.5D fighting game. Its target combines three principles without copying characters, assets or moves from another game:

- **Guilty Gear Strive:** strong silhouettes, readable key poses, forceful hit feedback and clear fighter identity.
- **Rivals of Aether:** lively readable stages, layered motion and backgrounds that react to combat.
- **Brawlhalla:** quick onboarding, compact controls, understandable combos and a varied roster.

The current one-on-one, best-of-three rules remain. The roadmap does not currently include a platform-fighter conversion, ring-outs, percentage knockback, changing weapons or a large Tekken-style move list.

## Shared priorities

1. Fighters that look polished and remain readable at gameplay scale.
2. Distinct attacks and motion language for every fighter.
3. Compact personal kits and signature combos.
4. Moving, layered and interactive stages that preserve combat readability.
5. Campaign persistence, Training and accessibility after the combat presentation is strong.

## Workstream status

| Workstream | Status | Working document | File boundary |
|---|---|---|---|
| Combat data foundation | Complete | `docs/superpowers/plans/2026-10-14-combat-data-foundation.md` | `data/combat.json`, combat loader/tests |
| Distinct attack presentation | Second slice complete: 12-step strikes and desktop SP keyboard binding verified | `docs/superpowers/plans/2026-10-14-distinct-attacks-and-interactive-stages.md` | animation profiles, `SpriteMotion`, visual tests |
| Reactive stages | First slice complete | `docs/superpowers/plans/2026-10-14-reactive-stages.md` | `scripts/stages/`, stage tests, narrow event wiring |
| Character visual redesign | Production in progress: Gantz and Joint List complete; Lapid exact-scale revision pending | `docs/superpowers/plans/2026-10-14-first-production-fighter-trio.md` | character images, sprite sheets, derived sprite frames, visual QA |
| Compact fighter kits and combos | Next | Create a dated spec and plan before tuning | combo/kit data, loaders and focused tests |
| Stage-specific motion and props | Planned | Extend the reactive-stage spec after review | parallax, crowds and cosmetic props behind the fight plane |
| Campaign persistence | Planned | `docs/superpowers/specs/2026-10-14-game-upgrade-design.md` | save schema, campaign flow and tests |
| Training and accessibility | Planned | `docs/superpowers/specs/2026-10-14-game-upgrade-design.md` | Training UI/runtime, Reduced Motion and tests |

## Shared integration rules

1. Every independent workstream uses a separate Git worktree and `codex/` branch.
2. Each workstream edits only its declared file boundary. Shared files such as `fighter.gd`, `fighter_visual.gd` and `main.gd` have one integration owner at a time.
3. A workstream that needs a shared-file change records the proposed patch in its plan and waits for integration ownership.
4. Every behavior change starts with a failing test. Every visual change includes 1280×720 and landscape-phone inspection.
5. Preserve the 12-frame fighter source contract, one combat engine, one combo engine, pause freezing, LTR UI and Web/mobile budgets.
6. No workstream pushes, merges or publishes without explicit user instruction.

## Shared specifications

- Main product and engineering specification: `docs/superpowers/specs/2026-10-14-game-upgrade-design.md`
- Fighter asset contract: `docs/character-pipeline.md`
- Finishers and celebrations: `docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md`
- Durable delivery handoff: `docs/superpowers/plans/2026-10-09-presentation-campaign-legal-analytics.md`
- Full-roster character bible: `docs/superpowers/specs/2026-10-14-character-visual-direction.md`

## Next review gate

Review the complete 13-fighter direction across `docs/design/concepts/2026-10-14-fighter-archetypes-v1.png` through `v4.png`. Approve a first production trio; the recommended mix is Lapid, Gantz and Joint List because it tests a simple fast silhouette, a heavy and the roster's unusual dual silhouette. Approved concepts then enter the existing 12-frame pipeline. In parallel, define compact kits and signature combos through the existing combat and combo engines, and create the first stage-specific motion concept.

## 2026-10-14 full-roster visual handoff

- Every roster ID now has a named gameplay archetype, personality, silhouette, movement language, effect palette and continuity link to its existing combo and finisher.
- Four concept boards cover all 13 fighters. Boards are review art and do not replace production sprites.
- Public-role research is linked in the character bible. Biography only informs broad presentation themes; all combat behaviour remains fictional satire.
- The next editor must preserve the 12-frame source contract and use the character bible as the shared visual source of truth.

## 2026-10-14 animation and desktop-control update

- Ordinary strikes now use twelve presentation steps with anticipation, contact and recovery silhouettes drawn from the shared twelve-pose source contract. Each strike uses at least four distinct source poses instead of switching only between idle and impact.
- Walk cycles now include stance transitions and play at 12 FPS; strikes target 24 FPS while `SpriteMotion` continues the per-render-frame lean, drive, lift, squash and recoil.
- Desktop fights hide the complete touch cluster and use keyboard `L` / `3` for Special and the full-energy finisher. The round `SP` control is phone-only.
- Kick transitions use stance and stepping poses only; the crouch pose is forbidden from kick clips so a kick cannot read as crouch-then-punch.
- Regression coverage: `tests/test_attack_clip_frames.gd` and `tests/test_mobile_control_contract.gd`. Visual review covers 1280×720 desktop and 844×390 landscape-phone layouts.
