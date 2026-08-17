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
5. **Manufactured Déjà Vu** (adopted from taste vault, 2026-08-16). The player should feel "I've stood here before" for worlds they never stood in — engineered sensory signature (light temperature, haze, wind audio, seasonal air color) rather than fidelity. Atmosphere > accuracy. Audio analog: pentatonic familiarity + elevated harmony = nostalgia you can't place.

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

### Who the player is — Story v1 (synthesis: v0 + Shiv's builder-observer)

**The Builder** — an anonymous hand that walks the ages. Neither early nor late; arriving precisely when meant to (the Gandalf principle). Not a collector, not a conqueror: the craftsperson every age sends ahead.

**The arc of every structure — four beats (the biography of a site):**
1. **Beat 1 — The Raising (Tier 1, gameplay).** Build from the foundation. Core massing with a smaller piece set — the "bones" of the structure. Teaches the structure's logic and the mechanics.
2. **Beat 2 — The Restoration (Tier 2, gameplay).** An era later: restore to zenith — full detail, colours, decorations; the civilisation flourishes as progress reaches 100%. This is the core loop and the difficulty layer.
3. **Beat 3 — The Decay (cinematic, non-interactive).** Time passes: days and seasons, the slant of sunrays changes, and the proud apex of a civilisation falls away to a mound — buried, ruined. Time prevails and continues. Khayyam's "The Moving Finger" is the invoking emotion; the Ozymandias loop is the register (Sting: *"These are the works of man. This is the sum of our ambition."*). Accompanied by scrolling text / voiceover — an epilogue telling the story of those people, that civilisation. A completion moment: bittersweet, but pivotal — endings lead to new beginnings lead to endings (the phoenix meta of the world itself).
4. **Beat 4 — The Excavation (Tier 3, light actions).** Quick, tactile clicks: clear the dust, remove the earth — bring the structure to its state as excavated by archaeologists **today**. Light interaction (brush swipes, dust, block-by-block reveal) gives mild closure so the loss never feels harsh. Aligns the arc with chronology itself: from where it started to where it is today.

**Difficulty lives INSIDE Tiers 1-2** (the gameplay layers), as a per-level scaffolding setting: **ghost → partial ghost + blueprint → blueprint only.** Tiers remain narrative acts; scaffolding carries difficulty — the same level data serves casual and brainy players. Excavation (Beat 4) stays deliberately light — closure, not challenge.

**The Ozymandias loop.** After the zenith, time spins ahead: the wheels of time churn, bricks turn back to earth, an era ends. The structure weathers to ruin in a cinematic time-lapse — the signature moment of the game. Tonal reference (Sting, "Mad About You"): *"They say a city in the desert lies... These are the works of man. This is the sum of our ambition."*

**The Memory Atlas (collection).** The peak (zenith) of every structure is saved into the player's memory — a museum of what was, fully viewable, orbitable, showcaseable. **Two entries per site:** the zenith (what the Builder remembers) and the today (the excavated state as archaeology found it) — a museum of what was, and what remains. This is the save/showcase pillar with narrative weight: the only thing that survives the Ozymandias loop is what the Builder remembers. The loop flips from nihilism to dignity: **the sum of ambition is what is remembered.**

**Metagame: the globe.** A world map/globe across time and space. **Spin the globe fast to initiate a change of era — forward or backward — and zoom into a region when the era locks.** One location can hold MULTIPLE structures across eras — Troy and its layers: one place, many levels, each era its own beat. Chronological spine: Egypt (test hook) → Göbekli Tepe → Sumer → Indus → Persia → China → Greece → Rome; strict chronology deferred — the time-travel loop permits any order.

**Why ruins? Resolved.** You don't find ruins — you make them. You are present at creation, you watch the decay; the ruin is the consequence of your own journey. And because you built here before, the weathered world feels familiar — Manufactured Déjà Vu made literal: *"Your hands remember what your eyes have never seen."*

## 5. Difficulty System — narrative acts + scaffolding (locked)

Per-structure arc = **biography**: Raising (Tier 1) → Restoration to zenith (Tier 2) → cinematic Decay → light Excavation to today (Tier 3).

| Beat | Interaction | Player load | Purpose |
|---|---|---|---|
| **1. Raising** | Build from foundation (core massing, small piece set) | Full build, guided | Learn structure + mechanics |
| **2. Restoration** | Restore to zenith: full detail, colours, decoration; civ flourishes at 100% | Full build, mastery | Core loop / difficulty layer |
| **3. Decay** | Cinematic time-lapse, non-interactive; epilogue text/voiceover | None | Emotional peak — Khayyam/Ozymandias |
| **4. Excavation** | Light tactile actions: clear dust/earth to today's excavated state | Minimal | Closure, chronology alignment |

**Difficulty = per-level scaffolding inside Tiers 1-2** (same level data, different aids):
- Ghost → partial ghost + blueprint → blueprint only
- Tiers are narrative acts; scaffolding carries difficulty — casual and brainy players served by one level

**No punitive timer** — progress % only (locked 2026-08-16).
Every ruin is **mathematically derivable** from the blueprint (plan/elevation → 3D). No eyeballing, per project rule.

## 6. UI & Mobile Real Estate (OPEN — needs final call)

Portrait mobile: the build viewport must dominate (~75-80% of screen). Principle: **only one secondary surface on screen at a time.**

- **Build view:** main viewport, full-bleed. Orbit camera (drag) + pinch zoom. **Locked pillar.**
- **Block palette:** bottom tray, thumb-reach, **tabs per category** (locked 2026-08-16 — blocks / columns / wedges / arches / specials), material-tinted.
- **Blueprint (excavation file):** **pull-up modal sheet** over the lower ~60% — plan and elevation side by side; build input pauses while open; tap-outside or close button dismisses. *Recommended: never a persistent side-by-side widget — real estate is too precious; treat the blueprint as a manual you consult.* **Flagged playtest risk:** open/close friction while building — alternatives (peek chip, auto-hide after N seconds) to be explored during playtesting.
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

Chronological arc: **Egypt → Göbekli Tepe → Sumer → Indus → Persia → China → Greece → Rome** (Egypt pulled up front for recognition — locked 2026-08-16).

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

- [ ] Story v1 — final sign-off pending (2026-08-17)
- [ ] Globe spin speed/era-lock feel — prototype
- [ ] Excavation (Beat 4) interaction depth — prototype; keep light
- [ ] Epilogue voiceover vs. scrolling text only — audio scope decision
- [ ] Save/gallery scope for v1 vs. post-v1
- [ ] Sound & haptics design (pillar 2) — block art pass timing

**Decision log**
- 2026-08-16: Restorer fantasy + 3-tier difficulty locked. V1 = Göbekli Enclosure A, Ur Ziggurat, Pyramid, Persepolis Gate. Pipeline = PD plans → MagicaVoxel → converter. Pillars = building, tactile completion, inspection/ownership, history-as-content.
- 2026-08-16: **Manufactured Déjà Vu adopted as pillar 5** (from taste vault — evening General session).
- 2026-08-16: Palette = tabs per category (locked). No punitive timer, progress % only (locked). Civ order: Egypt pulled up front (locked). Blueprint = modal sheet for now, flagged as playtest risk.
- 2026-08-17: TASTE.md lost in nightly sync (stale template clobbered newer file) — recovered verbatim from session diffs, `sync_brain.sh` fixed with `--update`.
- 2026-08-17: **Story v1.1 locked (synthesis + Shiv's beats)** — biography arc: Raising → Restoration to zenith → cinematic Decay (Khayyam/Ozymandias + epilogue) → light Excavation to today. Difficulty = per-level scaffolding inside Tiers 1-2 (ghost → partial ghost + blueprint → blueprint only). Memory Atlas = two entries per site (zenith + today). Globe: spin-to-era-change, zoom-to-lock. Egypt first as test hook; strict chronology deferred.
