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
- Status: parked (user: "we'll need to implement a pan functionality... park
  that for now until we start playtesting").
- Why: dioramas now cover ~3×3 phone widths at normal zoom (future large
  structures); orbiting alone won't frame the whole stage. Two-finger drag
  to pan or a dedicated pan mode — decide in the UI/HUD discussion.
- Blocked by: nothing; deliberately deferred until playtesting starts.

## Parked/deferred elsewhere

- Memory Atlas free-rotate exit resets tool to SINGLE on next swatch pick
  (already behaves; revisit only if it confuses during playtest).
