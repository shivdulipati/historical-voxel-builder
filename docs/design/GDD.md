# History in Voxels — Game Design Document

- **Working title:** History in Voxels (Relocation Proto)
- **Status:** v0.1 — initial draft, design window open
- **Date:** 2026-08-16
- **Author:** Hermes (producer) + Shiv (director)
- **Supersedes:** `GAP_CONTEXT.md` (Gemini-era workflow doc — retained as history)

---

## 1. Elevator Pitch

A meditative mobile builder where the player **restores the great structures of human civilization** — from Göbekli Tepe to the Great Bath — by reading archaeological evidence and assembling period-authentic blocks. LEGO-like building is the mechanic; history is the subject matter; the reward is watching a ruin become a building, and a building become knowledge.

## 2. Experience Pillars (locked)

1. **Building as the mechanic.** LEGO-style assembly on a voxel grid — picking, placing, clicking pieces together. Proven, fun, broad appeal. The grid, snapping math, stacking physics, and raycast placement are the foundation; nothing dilutes them.
2. **Tactile completion.** Blocks *click* into place — satisfying sound + haptic feedback on snap, pickup, and completion. Feel is as important as sight.
3. **Inspection & ownership.** The player can rotate, orbit, and examine the structure at any time. Completed work is **savable and showcaseable** (gallery + share).
4. **History as content.** Every structure is a real building with real plans and a real story. The game teaches by making the player *build the evidence*.

## 3. Core Loop

1. **Receive the site** — a named structure, its period, its story (one line).
2. **Study the evidence** — the ruin in-world, plus the excavation file (blueprint sheet: plan + elevation).
3. **Build** — select material-appropriate blocks/pieces, place on the grid to complete the structure.
4. **Reveal** — the finished reconstruction stands; brief historical note; orbit showcase.
5. **Keep** — save to gallery, advance to the next site in the chronological arc.

## 4. The Restorer Fantasy & Puzzle Presentation

The player is a **restorer**, not a copier. The finished building is the *reward*, never the starting reference.

- **Primary presentation: the ruin in-world.** Foundations, surviving lower courses, a broken corner — what an archaeologist actually finds. The footprint is the plan; the surviving masonry is the elevation.
- **Secondary: the excavation file.** A toggleable, diegetic blueprint sheet (plan view + elevation view, period-styled, with a fact line). Always available, never required.
- **Ghost (transparent full structure):** demoted to the Guided tier only — teaches mechanics — or a "reveal-then-fade" memory challenge.

## 5. Difficulty System — 3 Tiers (locked)

| Tier | In-world | Aid | Audience |
|---|---|---|---|
| **1. Guided** | Full ghost (+ ruin where ghosting is off) | Blueprint available | Onboarding / casual |
| **2. Restoration** (default) | Ruin — foundations + surviving parts | Blueprint available | Core loop / casual-to-mid |
| **3. Excavation** | Foundation only, no surviving superstructure | Blueprint only | Brainy / archaeologist |

- **Learning curve:** Tier 1 teaches the system (piece types, snapping, materials); Tier 2 is the main loop; Tier 3 is the mastery mode. Level progression ramps within and across tiers.
- **Difficulty knob per level:** how much of the ruin survives + which aids are allowed + structure complexity.
- **Long-term target:** casual/meditative broad audience. Near-term: build the tier system properly so difficulty can be tuned per-audience — we experiment now, tune for retention later.
- Every ruin is **mathematically derivable** from the blueprint (plan/elevation → 3D). No eyeballing, per project rule.

## 6. UI & Mobile Real Estate (OPEN — needs final call)

Portrait mobile: the build viewport must dominate (~75-80% of screen). Principle: **only one secondary surface on screen at a time.**

- **Build view:** main viewport, full-bleed. Orbit camera (drag) + pinch zoom. **Locked pillar.**
- **Block palette:** bottom tray, thumb-reach, scrollable per category (blocks / columns / wedges / arches / specials), material-tinted.
- **Blueprint (excavation file):** **pull-up modal sheet** over the lower ~60% — plan and elevation side by side; build input pauses while open; tap-outside or close button dismisses. *Recommended: never a persistent side-by-side widget — real estate is too precious; treat the blueprint as a manual you consult.*
- **Top bar:** civilization + structure name, progress %, story line, pause.
- **Win state:** reconstruction stands alone in viewport → orbit showcase → save/share → next.

**Open decisions to finalize in next pass:**
- Blueprint as modal sheet vs. split-view vs. floating mini-card (recommend: modal sheet).
- Palette: single scrolling tray vs. tabs per category (recommend: tabs — piece set will grow).
- Where the story/fact line lives (top bar vs. reveal card).

## 7. Blocks, Pieces & Materials

- **Layout language: voxel grid.** Unit cell + grid snapping + stacking physics (unchanged foundation). "No Eyeballing" discipline preserved.
- **Piece set expands per shape need:** unit cube, half-block, slope/wedge, cylinder (columns), quarter-cylinder (peristyle), arch, pyramid/stepped wedge, corner block, dome course. LEGO model: stud grid + varied bricks.
- **Materials = civilizations.** Per-civilization palettes with authentic color mapping (Indus baked brick, Egyptian limestone, Sumerian mudbrick, Persian glazed tile...). Block choice = choosing the right *material*, then placing it.
- Palette abstraction already exists (`Color0`, `Color1`...) in `levels.json` — extend, don't replace.

## 8. Civilizations & v1 Content

Chronological arc: **Göbekli Tepe → Sumer → Indus → Persia → China → Egypt → Greece → Rome** (order tunable; Egypt may move earlier for recognition).

**v1 — 4 structures (locked):**
1. **Göbekli Enclosure A** (Turkey, ~9500 BCE) — T-pillars; teaches tapered pieces
2. **Ur Ziggurat** (Sumer, ~2100 BCE) — stepped mass; teaches stepped/wedge courses
3. **Pyramid** (Egypt, ~2560 BCE) — Giza stepped-core model; teaches pyramid pieces + scale
4. **Persepolis Gate of All Nations** (Persia, ~470 BCE) — columned gateway; teaches cylinders + arch + glazed tile

Each gets 1-2 levels per tier (Guided/Restoration/Excavation) → ~4-8 playable levels in v1, more structures follow.

## 9. Authoring Pipeline (locked)

Public-domain archaeological plans → MagicaVoxel blockout → `.vox` → converter script → `levels.json`.

| Step | Tool | Cost |
|---|---|---|
| Reference plans/elevations (real dimensions) | Wikimedia Commons / PD archaeology publications | $0 |
| Blockout per structure on grid | MagicaVoxel (free) | $0 |
| `.vox` → project `levels.json` | converter script (extend `level_compiler.py` pattern) | $0 |
| Block/piece art | Asset Forge (owned) + Kenney | $0 |

- Structures must be grid-derivable from real floor plans — authenticity is a pillar.
- V1 authoring begins with Göbekli Enclosure A (T-pillars are the riskiest shape — validates the piece set early).

## 10. Feedback & Juice

- **Snap:** click sound + short haptic on placement (iOS: `Input.vibrate_handheld()`).
- **Pickup:** soft whoosh; **invalid placement:** low buzz + visual rejection.
- **Completion:** structure rise/sting, historical note card, showcase orbit.
- **Ambience:** period-appropriate palette + light; keep asset footprint small (mobile).

## 11. Save & Showcase

- Completed structures save to a **gallery** (user:// or local JSON) — "my reconstructed world."
- Showcase = orbit camera render; export/share via screenshot capture.
- (Long-term: this is the retention/collection hook.)

## 12. Tech Constraints

- Godot 4.6.3, GDScript; iOS portrait; PCK → Xcode export (pipeline proven).
- Performance: blocks freeze (`freeze = true`) on placement; keep draw calls mobile-safe.
- Repo: `hermes` branch is the working branch; `main` + `pre-hermes-baseline` = pre-Hermes state.
- Code reviews via Claude at feature milestones.

## 13. Open Questions & Decision Log

- [ ] Blueprint presentation final call (see §6)
- [ ] Palette tray structure final call (see §6)
- [ ] Civilization order for v1.1 (Egypt placement)
- [ ] Timer/score vs. meditative no-score (casual target suggests no punitive timer)
- [ ] Save/gallery scope for v1 vs. post-v1

**Decision log**
- 2026-08-16: Restorer fantasy + 3-tier difficulty locked. V1 = Göbekli Enclosure A, Ur Ziggurat, Pyramid, Persepolis Gate. Pipeline = PD plans → MagicaVoxel → converter. Pillars = building, tactile completion, inspection/ownership, history-as-content.
