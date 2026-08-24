-- ============================================================
-- DIORAMA GENERATOR for Asset Forge — "History in Voxels"
-- ============================================================
-- Builds a floating-island diorama from your Collections folders.
-- Blocks are referenced as "CollectionName/BlockName", so the theme is the
-- folder under Collections/ — swap COLLECTION to restyle the whole diorama,
-- and add folders to MIX to blend other themes in.
--
-- HOW TO USE:
--   1. Asset Forge → Script menu → Open Lua → dioramaGenerator.lua → Run
--      (F5 re-runs with a NEW random seed → keep hitting F5 to browse shapes)
--   2. Tweak blocks by hand if you like.
--   3. File → Save (Ctrl+S) → drop the .model file in the Hermes chat.
-- The port is 1:1 — no shifts needed: the top surface is built at y=0 and
-- the island is centered on the origin, exactly where the game puts the
-- structure. The centre CLEAR_X x CLEAR_Z box stays flat and empty for the
-- structure + baseplate (no 3x4 marker — that was just indicative).
-- ============================================================

-- ---------------- CONFIG ----------------
COLLECTION = "kenney_platformer-kit"  -- theme folder under Collections/
MIX = {}                               -- extra folders for variety, e.g. MIX = {"Test"}
                                       -- (every 3rd prop comes from MIX[1])
SEED = os.time() % 9973                -- fixed number = reproduce that shape
RADIUS = 8.0                           -- island radius (world units)
STRATA = 2.2                           -- depth of the brown body below the top
CHUNKS = 8                             -- max coastline chunks (organic outline)
LEDGES = 2                             -- overhang ledges poking out
RAISED = 1                             -- raised platforms (trees sit on them)
TREES = 5                              -- round trees
PINES = 5                              -- pine trees
PLANTS = 2                             -- small plants
STONES = 3                             -- rock clusters
FLOWERS = 2                            -- flower patches
CLEAR_X = 4.0                          -- keep |x| <= CLEAR_X and |z| <= CLEAR_Z
CLEAR_Z = 3.0                          -- free of props (the structure sits here)
-- ----------------------------------------

math.randomseed(SEED)

local function key(coll, block) return coll .. "/" .. block end

local function nearCenter(x, z)
    return math.abs(x) <= CLEAR_X and math.abs(z) <= CLEAR_Z
end

local function mixCollection()
    if #MIX > 0 and math.random(1, 3) == 1 then
        return MIX[math.random(#MIX)]
    end
    return COLLECTION
end

forge.clear()

local placed = { chunks = 0, ledges = 0, raised = 0, props = 0 }

-- --- Main base: one big slab, top surface at y=0 -------------------------
-- block-grass-overhang-large-tall is 2 units tall natively; scaling Y by
-- STRATA/2 makes the body exactly STRATA deep, so its top lands on y=0.
forge.build(key(COLLECTION, "block-grass-overhang-large-tall"),
    { 0, -STRATA, 0 }, { 0, 0, 0 }, { RADIUS, STRATA / 2, RADIUS })

-- --- Coastline chunks: Perlin-gated rim blocks, overlapping the base ------
for i = 1, CHUNKS do
    local angle = (i / CHUNKS) * math.pi * 2.0
    local n = forge.getNoise(math.floor(i * 3.7), math.floor(SEED % 977))
    if n > 0.42 then
        local dist = RADIUS * 0.55 + n * RADIUS * 0.3
        local cx = math.cos(angle) * dist
        local cz = math.sin(angle) * dist
        local n2 = forge.getNoise(math.floor(i * 13.0), math.floor(SEED % 911))
        local sx = 1.2 + n * 1.8
        local sz = 1.2 + (n2 + 0.5) * 1.8
        forge.build(key(COLLECTION, "block-grass-large-tall"),
            { cx, -STRATA, cz }, { 0, 0, 0 }, { sx, STRATA / 2, sz })
        placed.chunks = placed.chunks + 1
    end
end

-- --- Ledges: overhang blocks hanging off the rim --------------------------
for i = 1, LEDGES do
    local angle = (i / LEDGES) * math.pi * 2.0 + 0.7
    local dist = RADIUS * 0.92
    local lx = math.cos(angle) * dist
    local lz = math.sin(angle) * dist
    local rotY = math.deg(angle) + 90.0
    local n = forge.getNoise(math.floor(i * 5.0), math.floor(SEED % 823))
    forge.build(key(COLLECTION, "block-grass-overhang-long"),
        { lx, -1.0, lz }, { 0, rotY, 0 }, { 2.0, 1.0, 1.6 + n })
    placed.ledges = placed.ledges + 1
end

-- --- Raised platforms (back corners): a tree stands on each ----------------
for i = 1, RAISED do
    local angle = math.pi * (0.75 + (i - 1) * 0.5)   -- back-left / back-right
    local px = math.cos(angle) * RADIUS * 0.55
    local pz = math.sin(angle) * RADIUS * 0.55
    forge.build(key(COLLECTION, "block-grass-large-tall"),
        { px, 0, pz }, { 0, 0, 0 }, { 1.3, 1.0, 1.3 })
    forge.build(key(COLLECTION, "tree-pine"),
        { px + math.random(-1, 1) * 0.3, 2.0, pz + math.random(-1, 1) * 0.3 },
        { 0, math.random(0, 360), 0 }, { 1.0, 1.0, 1.0 })
    placed.raised = placed.raised + 1
    placed.props = placed.props + 1
end

-- --- Props on the lawn (kept out of the centre build box) ------------------
local function prop(block, y)
    for attempt = 1, 40 do
        local x = (math.random() * 2.0 - 1.0) * RADIUS * 0.82
        local z = (math.random() * 2.0 - 1.0) * RADIUS * 0.82
        if not nearCenter(x, z) then
            forge.build(key(mixCollection(), block),
                { x, y, z }, { 0, math.random(0, 360), 0 }, { 1.0, 1.0, 1.0 })
            placed.props = placed.props + 1
            return
        end
    end
end

for i = 1, TREES   do prop("tree", 0)        end
for i = 1, PINES   do prop("tree-pine-small", 0) end
for i = 1, PLANTS  do prop("plant", 0)       end
for i = 1, STONES  do prop("stones", 0)      end
for i = 1, FLOWERS do prop("flowers", 0)     end

-- --- Done ------------------------------------------------------------------
forge.print("Diorama built! seed=" .. SEED
    .. " chunks=" .. placed.chunks
    .. " ledges=" .. placed.ledges
    .. " raised=" .. placed.raised
    .. " props=" .. placed.props)
forge.print("Like it? File > Save. F5 = new random shape.")
