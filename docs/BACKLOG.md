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
- Status: scheduled — discuss when the playtest round closes
- Fronts:
  - Art assets: current voxel look (plain boxes + flat colors) vs Kenney /
    Asset Forge sets already in the repo, material differentiation per
    structure (limestone vs mudbrick vs marble), lighting/atmosphere.
  - Magicavoxel: authoring REAL historical structures in MagicaVoxel,
    voxelizing them, and generating build targets/puzzles from them —
    feasibility, pipeline (export format → levels.json), piece/block size
    scale, and which structures would be worth the effort.

## Parked/deferred elsewhere

- Memory Atlas free-rotate exit resets tool to SINGLE on next swatch pick
  (already behaves; revisit only if it confuses during playtest).
