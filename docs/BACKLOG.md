# BACKLOG — History in Voxels (slice)

Parked discussions and deferred work, tracked so nothing is lost between
sessions. Items here are NOT scheduled implementation — they are flagged for
design discussion first (user direction before code, per the workflow).

## Discussion items

### 1. Excavation File (blueprint sheet) — improvement or cut
- Status: parked (user: "I don't find it very useful for now")
- Open questions:
  - Is the blueprint redundant with the ghost scaffold + Memory Atlas?
  - If kept: what would make it useful? (per-beat checklist, rotated views,
    "what's left" filter, tap-to-place from the blueprint?)
  - If cut: remove button + sheet, keep the data for future use.

### 2. UI & HUD — full design review
- Status: parked
- Scope for the discussion: top bar density (beat label + site + progress +
  build badge), tool rows (view/scaffold/tools), Debug button placement,
  message cards, tray sizing/layout, typography scale, notch-safe margins,
  any affordance gaps found during playtest.

### 3. Next phase: art assets + Magicavoxel structures
- Status: IN PROGRESS — diorama pipeline live (art/diorama.gd), mastaba pilot
  iterating; roll-out to 9 levels after pilot approval.
- Fronts:
  - Art assets: current voxel look (plain boxes + flat colors) vs Kenney /
    Asset Forge sets already in the repo, material differentiation per
    structure (limestone vs mudbrick vs marble), lighting/atmosphere.
    NOTE: light rig rebalanced (sun 1.4→1.15, fill 0.5→0.4, ambient 0.6→0.5)
    to stop overexposure washing out floor texture; verify blocks still read
    well on device.
  - Magicavoxel: authoring REAL historical structures in MagicaVoxel,
    voxelizing them, and generating build targets/puzzles from them —
    feasibility, pipeline (export format → levels.json), piece/block size
    scale, and which structures would be worth the effort.
  - Kenney Isometric PNGs (4 rotations per model) could serve as tray/UI
    icons later — parked until the UI/HUD discussion.

### 4. Camera pan (drag-to-pan)
- Status: IMPLEMENTED (BUILD 21/22, two-finger ground-plane pan + gesture
  latch) — remaining polish parked.
- P3 polish items (user, BUILD 22 playtest: "slight edge cases in pan, but
  workable for most part — park as P3"):
  - Edge cases seen: pan/rotate boundary quirks at extreme angles, tiny
    drift on finger lift near gesture edges. Capture exact repros when they
    annoy during play; fix batch-style, not per-playtest.
- Why (original): dioramas cover ~3×3 phone widths at normal zoom; orbiting
  alone won't frame the whole stage.

### 5. World-map vision: spin-the-globe era selector (long-term)
- Status: parked vision (user, BUILD 22 discussion — feasibility unknown)
- The flow the earth-slice diorama is building toward:
  - World map UI: a spinning earth; player rotates it to move forward/back
    in time (era selector) and picks a region to work on.
  - Selecting an area pops its earth-slice diorama OUT of the globe, zooms
    into the build view (the slice is lifted from the earth; background is
    pure sky — no horizon).
  - When an area completes, the slice inserts itself back into the earth.
- Notes: the user's earlier "hemisphere" background idea is really THIS
  view (the globe), not the build view — the build view is the floating
  slice. Keep the two layers distinct when this is eventually scoped.
- Not before: biomes roll-out, structure pipeline, UI/HUD review.

### 6. Diorama generator rules (Lua, Asset Forge)
- Status: flagged (user, 2026-08-25): "the diorama generator needs work. I
  think some rules need to be in place to make the structures created look
  good as dioramas. currently it looks too random and in some aspects too
  similar to each other as well. ... good to know that we can script together
  dioramas. we'll explore this during scaling."
- Fronts to explore when scoped:
  - Composition rules: fewer models + overlap (the composed-platform
    aesthetic from B27), structure-area earmark handling (square platform /
    L-bracket markers), variety knobs so re-rolls differ beyond a seed.
  - Anti-similarity: why outputs feel samey (profile/shape distributions,
    corner/edge handling, prop placement) and how to widen the space.
  - Scripted co-authoring: user hand-tweaks after F5 re-roll, generator
    respects manual edits on re-run (selection-aware generation?).
- Not before: mastaba pilot sign-off + this .model transcription flow stable.

## Parked/deferred elsewhere

- Memory Atlas free-rotate exit resets tool to SINGLE on next swatch pick
  (already behaves; revisit only if it confuses during playtest).
