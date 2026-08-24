-- ============================================================
-- DIORAMA GENERATOR v2 for Asset Forge — "History in Voxels"
-- ============================================================
-- Floating-island diorama built from your Collections folders.
-- Blocks are "CollectionName/BlockName" — swap COLLECTION to restyle,
-- add folders to MIX to blend other themes in.
--
-- v2: coastline chunks now vary in shape (TALL / WIDE / SQUAT / NORMAL),
-- appear at CORNERS sometimes and EDGES sometimes, some chunks carry a
-- small PERCHED model on top; hexagon overhang blocks join the rim;
-- flowers / rocks / plant / grass cluster together sometimes.
--
-- HOW TO USE:
--   1. Script menu → Open Lua → dioramaGenerator.lua → Run
--      (F5 re-runs with a NEW random seed → browse shapes)
--   2. Tweak by hand if you like. 3. File → Save → drop the .model here.
-- Top surface at y=0, island centered on origin, centre box kept clear
-- for the structure (no marker).
-- ============================================================

-- ---------------- CONFIG ----------------
COLLECTION = "kenney_platformer-kit"  -- theme folder under Collections/
MIX = {}                               -- extra folders, e.g. MIX = {"Test"}
                                       -- (every 3rd prop comes from MIX[1])
SEED = os.time() % 9973                -- fixed number = reproduce that shape
RADIUS = 8.0                           -- island radius (world units)
STRATA = 2.2                           -- depth of the brown body below the top
CHUNKS = 10                            -- coastline chunks (edge + corner)
CORNER_SHARE = 0.4                     -- fraction of chunks at 45° corners
PERCH = 0.35                           -- chance a chunk carries a small model
HEXES = 3                              -- hexagon overhang blocks on the rim
LEDGES = 2                             -- overhang ledges poking out
RAISED = 1                             -- raised platforms (trees sit on them)
TREES = 5                              -- round trees
PINES = 5                              -- pine trees
PLANTS = 2                             -- small plants
STONES = 3                             -- rock clusters
FLOWERS = 2                            -- flower patches
FLOWERS_TALL = 2                       -- tall flowers
GRASS = 4                              -- grass tufts
ROCKS = 2                              -- rock boulders
CLUSTER = 0.5                          -- chance flowers/rocks/plant/grass group
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

local placed = { chunks = 0, perches = 0, hexes = 0, ledges = 0, raised = 0, props = 0 }

-- --- Main base: one big slab, top surface at y=0 -------------------------
-- block-grass-overhang-large-tall is 2 units tall natively; scale Y by
-- STRATA/2 makes the body exactly STRATA deep, so its top lands on y=0.
forge.build(key(COLLECTION, "block-grass-overhang-large-tall"),
    { 0, -STRATA, 0 }, { 0, 0, 0 }, { RADIUS, STRATA / 2, RADIUS })

-- --- Coastline chunks: corners + edges, four shape profiles ---------------
-- Corner chunks sit at the 45° diagonals, edge chunks on the cardinals.
-- Shapes: TALL pokes above the lawn, WIDE spreads sideways, SQUAT is a low
-- pad below the lawn line, NORMAL is flush. Perch: some chunks carry a small
-- model (stones/plant/grass/flowers) on top.
local PERCH_BLOCKS = { "stones", "plant", "grass", "flowers", "block-grass" }

for i = 1, CHUNKS do
    local corner = (i % math.ceil(1.0 / CORNER_SHARE)) == 0
    local baseAngle = (corner and 1 or 0) * math.pi / 4.0
        + math.floor((i - 1) / (1 + (1 - CORNER_SHARE) / CORNER_SHARE)) * math.pi / 2.0
    local angle = baseAngle + (math.random() * 2.0 - 1.0) * 0.25
    local n = forge.getNoise(math.floor(i * 3.7), math.floor(SEED % 977))
    if n > 0.38 then
        local dist = RADIUS * (0.68 + n * 0.22)
        local cx = math.cos(angle) * dist
        local cz = math.sin(angle) * dist
        local roll = math.random()
        local sx, sy, sz
        if roll < 0.30 then          -- TALL
            sx, sy, sz = 1.1 + n * 0.7, 1.25 + n * 0.55, 1.1 + n * 0.7
        elseif roll < 0.55 then      -- WIDE
            sx, sy, sz = 1.9 + n * 1.0, 0.95 + n * 0.1, 1.9 + n * 1.0
        elseif roll < 0.75 then      -- SQUAT (low pad)
            sx, sy, sz = 2.3 + n * 1.0, 0.55 + n * 0.2, 2.3 + n * 1.0
        else                         -- NORMAL
            sx, sy, sz = 1.3 + n * 0.5, 1.0, 1.3 + n * 0.5
        end
        forge.build(key(COLLECTION, "block-grass-large-tall"),
            { cx, -STRATA, cz }, { 0, math.random(0, 360), 0 }, { sx, sy, sz })
        placed.chunks = placed.chunks + 1
        -- Perch a small model on top of TALL chunks.
        if sy > 1.2 and math.random() < PERCH then
            local topY = -STRATA + 2.0 * sy
            forge.build(key(mixCollection(), PERCH_BLOCKS[math.random(#PERCH_BLOCKS)]),
                { cx, topY, cz }, { 0, math.random(0, 360), 0 }, { 1.0, 1.0, 1.0 })
            placed.perches = placed.perches + 1
            placed.props = placed.props + 1
        end
    end
end

-- --- Hexagon overhang blocks along the rim (30°-stepped rotations) ---------
for i = 1, HEXES do
    local angle = (i / HEXES) * math.pi * 2.0 + 0.35
    local hx = math.cos(angle) * RADIUS * 0.9
    local hz = math.sin(angle) * RADIUS * 0.9
    local rotY = math.floor(angle / (math.pi / 6.0)) * 30.0 + 30.0
    local n = forge.getNoise(math.floor(i * 17.0), math.floor(SEED % 733))
    forge.build(key(COLLECTION, "block-grass-overhang-hexagon"),
        { hx, -1.0, hz }, { 0, rotY, 0 }, { 1.2 + n * 0.5, 1.0, 1.2 + n * 0.5 })
    placed.hexes = placed.hexes + 1
end

-- --- Ledges: overhang blocks hanging off the rim --------------------------
for i = 1, LEDGES do
    local angle = (i / LEDGES) * math.pi * 2.0 + 0.7
    local lx = math.cos(angle) * RADIUS * 0.92
    local lz = math.sin(angle) * RADIUS * 0.92
    local rotY = math.deg(angle) + 90.0 + math.random(-15, 15)
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
        { px + (math.random() * 2.0 - 1.0) * 0.3, 2.0, pz + (math.random() * 2.0 - 1.0) * 0.3 },
        { 0, math.random(0, 360), 0 }, { 1.0, 1.0, 1.0 })
    placed.raised = placed.raised + 1
    placed.props = placed.props + 1
end

-- --- Props on the lawn (kept out of the centre build box) ------------------
-- Clusterable props (flowers/rocks/plant/grass/flowers-tall) group 2-5 of
-- the same block in a tight bunch when the dice says so.
local function placeProp(block, clusterable)
    local x, z
    local found = false
    for attempt = 1, 40 do
        local tx = (math.random() * 2.0 - 1.0) * RADIUS * 0.82
        local tz = (math.random() * 2.0 - 1.0) * RADIUS * 0.82
        if not nearCenter(tx, tz) then
            x, z = tx, tz
            found = true
            break
        end
    end
    if not found then
        return
    end
    forge.build(key(mixCollection(), block), { x, 0, z },
        { 0, math.random(0, 360), 0 }, { 1.0, 1.0, 1.0 })
    placed.props = placed.props + 1
    if clusterable and math.random() < CLUSTER then
        local extra = math.random(1, 4)   -- 2-5 total in the bunch
        for k = 1, extra do
            local jx = x + (math.random() * 2.0 - 1.0) * 1.3
            local jz = z + (math.random() * 2.0 - 1.0) * 1.3
            if not nearCenter(jx, jz) then
                forge.build(key(mixCollection(), block), { jx, 0, jz },
                    { 0, math.random(0, 360), 0 }, { 0.9 + math.random() * 0.2, 0.9 + math.random() * 0.2, 0.9 + math.random() * 0.2 })
                placed.props = placed.props + 1
            end
        end
    end
end

for i = 1, TREES        do placeProp("tree", false)          end
for i = 1, PINES        do placeProp("tree-pine-small", false) end
for i = 1, PLANTS       do placeProp("plant", true)          end
for i = 1, STONES       do placeProp("stones", true)         end
for i = 1, FLOWERS      do placeProp("flowers", true)        end
for i = 1, FLOWERS_TALL do placeProp("flowers-tall", true)   end
for i = 1, GRASS        do placeProp("grass", true)          end
for i = 1, ROCKS        do placeProp("rocks", true)          end

-- --- Done ------------------------------------------------------------------
forge.print("Diorama v2 built! seed=" .. SEED
    .. " chunks=" .. placed.chunks
    .. " perches=" .. placed.perches
    .. " hexes=" .. placed.hexes
    .. " ledges=" .. placed.ledges
    .. " raised=" .. placed.raised
    .. " props=" .. placed.props)
forge.print("Like it? File > Save. F5 = new random shape.")
