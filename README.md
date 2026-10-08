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

The thin gold bar under each health bar in the combat HUD is **Special Energy** (labelled `SPECIAL ENERGY` with a percentage). Clean hits charge the attacker, blocked hits charge it a little, and the defender gains comeback energy from damage taken. At 55% the `MAX` special move unlocks; at 100% the `SP` finisher unlocks and its button lights up with an electric aura.

## Controls

| Action | Keyboard |
|---|---|
| Move | `A` / `D` or arrow keys |
| Jump | `W` or Up |
| Guard | `S` / `H` |
| Crouch | `C` |
| Jab (`JAB`): fast, short-range combo starter | `J` / `1` |
| Cross (`CROSS`): slower, longer-range high-damage hit | `K` / `2` |
| Kick (keyboard only) | `U` / `4` |
| `MAX` special move (costs 55% energy) / `SP` finisher at 100% | `L` / `3` |
| Pause / back | `Esc` |

Phone controls follow the HUD reference: a joystick on the left (push up to jump, down to crouch) and a right-hand cluster of `JAB`, `CROSS`, `MAX`, `SP` and `GUARD`. Every button acts exactly once per tap, on press; its hit area is exactly the drawn diamond or circle, and each finger is tracked separately, so you can attack while holding the joystick. `MAX` stays dim below 55% energy and never falls back to another attack.

Finisher controls: fill Special Energy to 100%, then press `L` / `3` once or tap `SP` on touch screens. No prior round win or rival-health threshold is required. The authored sequence always starts and spends the full meter; it damages the rival only when the fighters were inside the configured activation range at the instant of the press. An out-of-range attempt plays as an opening miss, deals no damage and resumes combat. **A finisher is a heavy blow, not an automatic win:** in a match it deals 30% of the rival's max HP. If the rival survives, it falls, gets up and the round continues. If the blow empties the bar, it is a normal round KO; the match ends (and the celebration plays) only when that KO wins the best-of-three. All 13 fighters have an authored Finish Attack and post-match celebration. At the end of a full match, the winner celebrates unobstructed for at least three real-time seconds at 40% authored speed; only then does the compact `YOU WIN` / `YOU LOSE` card appear. `REMATCH` / `TRY AGAIN` replays the same rival; `NEW OPPONENT` draws a different random rival. `WIN CELEBRATION` in Finisher Lab previews the same slower sequence directly.

Special Energy carries over between the rounds of a match and resets when a new match starts.

The CPU uses an adaptive brain (`scripts/cpu_brain.gd`). During a match it learns which attack the player tends to throw after which (an order-1 Markov table), how often the player guards, and the player's preferred attack distance. It then chooses between spacing just outside the player's reach, pressure, baiting a whiff and defending, using a weighted random choice so it never settles into a readable pattern. It punishes missed attacks during their recovery, guards more often against habits it has learned, and never repeats the same attack three times in a row. The level sets its reaction time and guard skill. `tests/test_combat_fairness.gd` plays ten best-of-three matches between a scripted average player and the level-1 CPU and checks that the player wins between 40% and 82% of rounds, that rounds last at least 22 seconds, that Special Energy reaches 100% in most matches, that the CPU's attack choice has at least 1.2 bits of entropy, and that its guard rate against a repeated habit rises over time.

## Run the project

1. Install Godot 4.7 or newer.
2. Import `project.godot` in Godot.
3. Run the main scene: `scenes/main.tscn`.

```powershell
godot --path .
```

The project disables Blender import in `project.godot`; gameplay uses the sprite pipeline and does not require Blender.

## Play on a phone

Every push to `main` exports the Godot Web build and deploys it to GitHub Pages at [roee030.github.io/world-fight-election](https://roee030.github.io/world-fight-election/). Open it in a phone browser and rotate to landscape. While the engine downloads, a branded loading screen shows the percentage and megabytes, warns about slow connections and offers `RETRY` if the engine fails. The game fills the entire landscape screen: Godot uses the `expand` stretch aspect on a 1280×720 design canvas, so wider phones show more arena instead of black bars; the HUD panels and touch controls anchor to the screen edges, and menus stay centred. On Android phones a `TAP TO FIGHT` gate enters fullscreen and locks landscape; leaving fullscreen pauses the fight and shows the gate again. Browsers without the fullscreen API (iPhone Safari) or that refuse it skip the gate. Add `?diag=1` to the URL for an on-screen diagnostics panel (load stage, engine heartbeat, viewport, safe area, GPU and last console errors).

The UI is authored left-to-right and is forced to stay that way (`internationalization/rendering/root_node_layout_direction=1` plus `Window.LAYOUT_DIRECTION_LTR`). Without it Godot mirrors every screen on Hebrew phones and browsers, which pushed the menus off-screen and left only the background art visible.

Images are imported as lossy WebP by default (`[importer_defaults]` in `project.godot`), which cut the downloaded package from about 65 MB to about 15 MB. Textures decode to the same GPU format, so runtime performance is unchanged.

In portrait orientation the page now shows a dedicated illustrated rotate gate: the complete fighter roster surrounds a landscape-phone cue beneath the Knesset menorah, with a visible `FULL SCREEN` button. Rotating to landscape triggers a best-effort browser full-screen request, and the first landscape tap also retries it; mobile browsers that require a user gesture retain the button as the reliable fallback. In landscape, every Web fight exposes the movement joystick plus `JAB`, `CROSS`, `MAX`, `SP` and `GUARD`. Editor-only 3D sources, raw sprite sheets, reference images and tests are excluded from the Web package to reduce its initial download without removing runtime fighters, stages or finishers. The web export replaces the former PWA worker with a self-retiring cleanup worker that unregisters itself and clears old caches without reloading open tabs (a forced reload used to download the game twice).

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

On phones, `SP` launches a finisher with one tap whenever Special Energy is full. Distance determines hit or miss rather than whether the sequence starts. The Web loading screen disappears as soon as the real Godot menu reports ready.

The shared finisher and celebration system is complete for all 13 fighters: one MAX/Special press at 100% triggers the authored timeline, pause freezes the cinematic, and Fighter Lab previews hit, miss and celebration sequences. Fighter Lab shows the complete roster at once with a dedicated `FINISH` button for each fighter, plus hit/miss, pause, frame-step, mobile-density and reduced-motion controls. `LIVE VERSUS TEST` creates a production fighter and a selectable rival with full Special Energy; use the normal keyboard controls or the lab action buttons, then `F` or `FINISH NOW` to validate in-range hits and out-of-range misses. The authoritative delivery record is [`docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md`](docs/superpowers/specs/2026-10-07-finishers-celebrations-design.md).

## Asset and repository policy

- Keep source code, curated game assets, design documents and tests in Git.
- Keep Godot caches, local exports, portable Blender downloads, temporary renders and the raw third-party character pack out of Git.
- Third-party licenses retained under `assets/characters/rigged/source/` must remain with their corresponding assets.
- Review generated artwork for clean anatomy, readable silhouette, transparent edges and correct ground contact before integration.

## Status

The game is playable and under active visual and combat polish. The current priority is consistent character presentation, readable hit feedback, robust pause behavior, stage grounding and data-driven finishing moves.
