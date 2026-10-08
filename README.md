# World Fight: Election Edition

משחק קרבות סאטירי מקורי, אופליין, שנבנה ב־Godot 4 כמשחק 2.5D עם לוחמים מצוירים מבוססי ספרייטים.

This repository is the source of truth for the game. New contributors and agents should read this file and [`AGENTS.md`](AGENTS.md) before changing code or art.

## Current game

- 13 playable fighters: Bennet, Avigdor Lieberman, Bibi, Yair Golan, Aryeh Deri, Yair Lapid, Mansour Abbas, Benny Gantz, Itamar Ben-Gvir, Bezalel Smotrich, Gadi Eisenkot, Donald Trump and Joint List.
- Single Fight with one player choice and a random CPU rival.
- Four-fight campaign, best-of-three rounds, health, hit stun, guard, combos and a charged special meter.
- Five stages, including the Knesset exterior, Knesset chamber and three studio arenas.
- Keyboard and touch controls.
- Fighter Sprite Lab for inspecting every animation outside a match.

The lower gold bar in the combat HUD is **Special Energy**. It fills when attacks connect. At 100%, the special attack is available.

## Controls

| Action | Keyboard |
|---|---|
| Move | `A` / `D` or arrow keys |
| Jump | `W` or Up |
| Guard | `S` / `H` |
| Crouch | `C` |
| Jab: fast, short-range combo starter | `J` / `1` |
| Heavy: slower, longer-range high-damage hit | `K` / `2` |
| Special / Finisher: strong meter attack; hold when Finish is ready | `L` / `3` |
| Pause / back | `Esc` |

Finisher controls: first win one round, fill Special Energy to 100%, reduce the rival to 15% health or less and move close. The HUD then says `FINISH READY`; hold `L` / `3`, or tap `FINISH` once on touch screens. The phone button is dedicated to the finisher and explains any missing condition instead of launching a different move. Releasing keyboard Special during pause cancels the pending hold on resume. All 13 fighters have an authored Finish Attack and post-match celebration. At the end of a full match, the winner celebrates unobstructed for at least three real-time seconds at 40% authored speed; only then does the compact `YOU WIN` / `YOU LOSE` card appear. `WIN CELEBRATION` in Finisher Lab previews the same slower sequence directly.

## Run the project

1. Install Godot 4.7 or newer.
2. Import `project.godot` in Godot.
3. Run the main scene: `scenes/main.tscn`.

```powershell
godot --path .
```

The project disables Blender import in `project.godot`; gameplay uses the sprite pipeline and does not require Blender.

## Play on a phone

Every push to `main` exports the Godot Web build and deploys it to GitHub Pages at [roee030.github.io/world-fight-election](https://roee030.github.io/world-fight-election/). Open it in a phone browser and rotate to landscape. The startup actions are available from first paint while Godot loads; the centered 16:9 canvas follows the live visual viewport, respects notches and browser safe areas, and displays touch controls automatically without cropping.

In portrait orientation the page now shows a bilingual rotate/full-screen gate instead of shrinking the 16:9 game into an unreadable strip. In landscape, every Web fight exposes the movement joystick plus `PUNCH`, `KICK`, `FINISH`, `JUMP` and `GUARD`. The loading-only HTML actions disappear as soon as Godot is ready, and selecting a loading action requests browser full screen from the same user gesture. The exported canvas is constrained to a centered 16:9 rectangle inside Chrome's current visual viewport, keeping the full menu and every touch target inside its safe edges. The web export replaces the former PWA worker with a self-retiring cleanup worker, unregisters it and clears its old caches. This also repairs Chrome installations that retained the obsolete `index.service.worker.js`; after the migration deployment, close and reopen an already-open game tab once.

## Project structure

| Path | Purpose |
|---|---|
| `scripts/main.gd` | Screen flow, stages, HUD, rounds, pause and result presentation |
| `scripts/fighter.gd` | Movement, attacks, damage, AI, health, special meter and reaction states |
| `scripts/fighter_visual.gd` | Fighter height, grounding, sprite clips and shadow setup |
| `scripts/character_debug.gd` | Fighter Sprite Lab |
| `scripts/opponent_selector.gd` | Random rival selection |
| `assets/characters/*-card.png` | Canonical full character artwork |
| `assets/characters/portraits/` | Face-focused selection and HUD portraits |
| `assets/characters/sprites/` | Normalized transparent combat frames |
| `assets/stages/` | Full-frame stage backplates |
| `assets/ui/main-hero-*.png` | Two title-art candidates |
| `tools/slice_sprite_sheets.py` | Sprite extraction and normalization |
| `tools/build_portraits.py` | Rebuilds face-focused roster portraits |
| `tests/` | Headless Godot and Python regression tests |
| `docs/` | Art pipeline, combat plans and future design work |

## Character art contract

Every playable fighter must have:

1. A canonical `assets/characters/<id>-card.png` character illustration.
2. A generated `assets/characters/portraits/<id>.png` upper-body portrait.
3. Twelve normalized transparent frames in `assets/characters/sprites/<id>-0.png` through `<id>-11.png`.
4. Geometry metadata in `FighterVisual.FIGHTER_GEOMETRY`.
5. Entries in `FIGHTER_DATA` and `PLAYABLE_IDS`.

Do not paste a photo onto a generic 3D body. The game uses coherent, complete fighter artwork and sprite animation. See [`docs/character-pipeline.md`](docs/character-pipeline.md).

## Rebuild derived art

```powershell
python tools/build_portraits.py
python tools/slice_sprite_sheets.py
```

After rebuilding PNGs, let Godot finish importing before running visual tests.

## Tests

```powershell
python -m unittest tests.test_slice_sprite_sheets

Get-ChildItem tests/test_*.gd | ForEach-Object {
  godot --headless --path . --script ("res://tests/" + $_.Name)
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Regression coverage checks roster completeness, random opponent selection, sprite geometry, real hit damage, reaction clips, grounded shadows, pause behavior and presentation structure.

## Current design direction

- Full-screen cinematic title art with a small floating text menu.
- Fighter selection shows all fighters at once with face-focused portraits.
- Angular fighting-game HUD with edge portraits, segmented cyan/red health, round markers, a central timer and a thin gold `SPECIAL ENERGY` meter. Phone controls use a large left joystick and a right-side diamond cluster matching the supplied console-fighter reference.
- The defeated fighter falls on the lethal hit and remains grounded. Results stay hidden while the winner celebrates unobstructed for at least three seconds at 40% speed, then reveal one compact result card.
- Per-stage visual alignment keeps feet on the visible floor.

On phones, `FINISH` launches an eligible finisher with one tap and otherwise reports the unmet requirement without spending energy. Chrome web exports include temporary loading actions that forward Start Fight, Campaign and Fighter Lab to Godot, then disappear when the real menu is ready.

The shared finisher and celebration system is complete for all 13 fighters: eligible MAX/Special holds trigger authored hit timelines, pause freezes the cinematic, and Fighter Lab previews hit, miss and celebration sequences. Fighter Lab shows the complete roster at once with a dedicated `FINISH` button for each fighter, plus hit/miss, pause, frame-step, mobile-density and reduced-motion controls. `LIVE VERSUS TEST` creates a production fighter and a selectable rival at 15% health with full Special Energy; use the normal keyboard controls or the lab action buttons, then `F` or `FINISH NOW` to validate the finisher against that rival. The authoritative delivery record is [`docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md`](docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md).

## Asset and repository policy

- Keep source code, curated game assets, design documents and tests in Git.
- Keep Godot caches, local exports, portable Blender downloads, temporary renders and the raw third-party character pack out of Git.
- Third-party licenses retained under `assets/characters/rigged/source/` must remain with their corresponding assets.
- Review generated artwork for clean anatomy, readable silhouette, transparent edges and correct ground contact before integration.

## Status

The game is playable and under active visual and combat polish. The current priority is consistent character presentation, readable hit feedback, robust pause behavior, stage grounding and data-driven finishing moves.
