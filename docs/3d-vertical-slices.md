# 3D vertical slices

This document records the boundary between the shipped 2.5D fighter and the next
generation 3D game. It is intentionally specific so a later agent can continue
without replacing the production sprite contract prematurely.

## Bibi 3D proof

`scenes/bibi_3d_preview.tscn` is the playable visual proof. It assembles Bibi
through `RiggedFighterVisual`, binds the Quaternius skeleton clips and offers
idle, walk, strike, hit, fall and recovery poses. It is accessible from the main
menu as **BIBI 3D PROTOTYPE**. The scene deliberately does not alter
`GameFighter` or `FighterVisual`: the released fight still requires the shared
12-frame source contract.

Promotion rule: migrate a combat fighter only after a presentation adapter can
preserve every existing combat state, hit-stop, grounding/shadow contract,
finisher lock and mobile render budget. Add a headless test plus 1280x720 and
780x360 visual captures before enabling it in a normal match.

## Arena map

`scripts/ui/arena_map.gd` is the interactive 2D stage map used on the arena
selection screen. Stage data owns its `map_position`; clicking a node emits the
stage ID and synchronizes with the stage cards and keyboard browsing. It is a
selection map, not a physical battle arena, so it cannot change combat physics.

## Roee Monster concept

`assets/characters/concepts/roee-monster-3d-concept.png` is an approved visual
brief derived from the supplied photo: dark hair and beard, recognizable smile,
slate-blue clothing, rock-scaled forearms, cyan fissures and compact horns. It
is a concept reference only; it has an opaque studio background and is not a
runtime sprite, portrait or billboard.

To make this a playable 3D character, use a properly licensed humanoid mesh
with a rig compatible with the project skeleton, create original face and outfit
geometry/materials from the brief, then export a `.glb`. Do not paste the photo
onto a generic body. The intake must include: mesh/license manifest, bone-map
test, separate body/clothing/accessory materials, idle/walk/strike/hit/fall
preview, floor/shadow inspection and explicit approval before adding a roster ID.
