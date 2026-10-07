# UI and combat polish implementation plan

## Goal

Replace the split roster menu with cinematic title art and floating actions, make fighter selection face-readable, align the Knesset chamber floor, freeze all match progression during pause, ground jump shadows and make damage and special feedback unambiguous.

## Work items

- [x] Generate two 16:9 title-art candidates with protected menu space.
- [x] Add a full-screen hero background and floating text menu.
- [x] Derive dedicated face-focused portraits for all 13 fighters.
- [x] Use those portraits in selection tiles and the HUD.
- [x] Add a Knesset chamber background alignment value.
- [x] Keep shadows on the world floor during jumps.
- [x] Mark the lower HUD bar as Special Energy and show percentage and readiness.
- [x] Prevent timers and round transitions from advancing while paused.
- [x] Add regression coverage for damage, hit reaction, shadow, pause, stage alignment and UI structure.
- [ ] Run the full headless suite and visual screen review.
- [ ] Commit and push the complete project to the new GitHub repository.
