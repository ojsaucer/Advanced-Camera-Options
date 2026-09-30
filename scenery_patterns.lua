local S = {}

-- General-primary metatile IDs, not packed atlas slots. These families were
-- checked against the imported FRLG under/over artwork and are gated to the
-- "frlg" ROM layout below; Emerald's own separate rules are further down.
local water = {}
for _, mid in ipairs({ 0x110, 0x111, 0x118, 0x119, 0x1CB, 0x1CC, 0x1D3, 0x1D4,
  0x12B, 0x1D0, 0x1D1, 0x1D2, 0x1D8, 0x1D9, 0x1E0, 0x1E2,
  0x212, 0x213, 0x21A, 0x21B, 0x10F, 0x117, 0x11F, 0x129, 0x1DA, 0x1E1 }) do water[mid] = true end
local cliffs, buildings = {}, {}
for _, mid in ipairs({ 0x068, 0x069, 0x06A, 0x06B, 0x06C, 0x06D, 0x070, 0x071, 0x072, 0x073, 0x075,
  0x078, 0x079, 0x07A, 0x07B, 0x07C, 0x07D, 0x080, 0x081, 0x0B2, 0x0B3 }) do cliffs[mid] = true end
-- Horizontal/vertical continuations of each authored wall piece. A cut
-- through a corner straightens only the axis crossing that map boundary.
local walls = {
  [0x068] = { 0x069, 0x070 }, [0x069] = { 0x069, false }, [0x06A] = { 0x069, 0x072 },
  [0x06B] = { 0x06C, 0x073 }, [0x06C] = { 0x06C, false }, [0x06D] = { 0x06C, 0x075 },
  [0x070] = { false, 0x070 }, [0x072] = { false, 0x072 },
  [0x073] = { false, 0x073 }, [0x075] = { false, 0x075 },
  [0x078] = { 0x079, 0x070 }, [0x079] = { 0x079, false }, [0x07A] = { 0x079, 0x072 },
  [0x07B] = { 0x07C, 0x073 }, [0x07C] = { 0x07C, false }, [0x07D] = { 0x07C, 0x075 },
  [0x0B2] = { 0x07C, 0x075 }, [0x0B3] = { 0x07C, 0x073 },
}
local treeRows = {
  [0x00E] = { 0x00E, 0x00F, 0 }, [0x00F] = { 0x00E, 0x00F, 1 },
  [0x10A] = { 0x10A, 0x10B, 0, true }, [0x10B] = { 0x10A, 0x10B, 1, true },
  [0x0FA] = { 0x0FA, 0x0FB, 0 }, [0x0FB] = { 0x0FA, 0x0FB, 1 },
}
local fences = {}
for _, mid in ipairs({
  0x0D6, 0x0D7, 0x0E6, 0x0E7, 0x0E8, 0x0E9, 0x0EC, 0x0ED, 0x0EE, 0x0F4,
  -- Guardrail/handrail posts (e.g. Route 11's bridge, Rock Tunnel/Victory
  -- Road entrances): same "self-repeat" treatment as wooden fence posts.
  0x29B, 0x29C, 0x2D3,
  0x315, 0x316, 0x317, 0x31D, 0x320, 0x325, 0x326, 0x327,
}) do fences[mid] = true end
for _, mid in ipairs({ 0x044, 0x045, 0x046, 0x048, 0x049, 0x04A, 0x04B, 0x04C, 0x04D, 0x04E,
  0x050, 0x051, 0x052, 0x053, 0x054, 0x055, 0x056, 0x058, 0x059, 0x05A, 0x05B, 0x05C,
  0x060, 0x061, 0x062, 0x063, 0x064, 0x065, 0x066, 0x067, 0x183, 0x184, 0x185,
  0x186, 0x187, 0x188, 0x189, 0x18A, 0x18B, 0x18C, 0x18F, 0x1B5, 0x1B6 }) do buildings[mid] = true end
local forestBorder = { 0x298, 0x299, 0x29A, 0x290, 0x291, 0x292 }
local patternBushBorder = { 0x290, 0x291, 0x292, 0x298, 0x299, 0x29A }
local safariBorder = { 0x2F5, 0x2F6, 0x2F7, 0x2FD, 0x2FE, 0x2FF }
local forestGate = { [0x0EA] = true, [0x28B] = true, [0x28C] = true, [0x28D] = true,
  [0x293] = true, [0x294] = true, [0x29D] = true, [0x29E] = true }
local shore = {
  [0x108] = { 0, 1 }, [0x109] = { 0, 1 },
  [0x112] = { 1, 0 }, [0x113] = { -1, 0 },
  [0x11A] = { 1, 0 }, [0x11B] = { -1, 0 },
  [0x122] = { 1, 1 }, [0x123] = { 0, 1 }, [0x124] = { -1, 1 },
  [0x12A] = { 1, 0 }, [0x12C] = { -1, 0 },
  [0x1C7] = { 0, 1 }, [0x1CF] = { 0, 1 },
}

local function gcd(a, b)
  while b ~= 0 do a, b = b, a % b end
  return a
end

-- Most of these metatile IDs were verified against FireRed/LeafGreen's own
-- "General" tileset artwork; Emerald ships a completely different ROM with a
-- same-named "general" primary tileset that has no relation to these exact
-- IDs, so applying FRLG-specific rules there would replace tiles with
-- unrelated, wrong artwork. `family()` reports which ROM's layout is active
-- so each rule table below can be scoped to the one game it was verified
-- against. Older engines (0.3.19/0.3.22) predate GameVersion.layout entirely
-- and only ever shipped frlg-layout games.
local function family()
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if not ok or type(GameVersion.layout) ~= "function" then return "frlg" end
  local ok2, layout = pcall(GameVersion.layout, GameVersion.get())
  if not ok2 or layout == nil then return "frlg" end
  return layout
end

function S.new(layout, pair, Fill, Native, depth)
  local fam = family()
  if fam ~= "frlg" and fam ~= "rse" then return nil end
  if not Fill.primaryFor or Fill.primaryFor(pair) ~= "general"
    or not Fill.borderFor or not Native.hasMid then return nil end
  local function available(p)
    if not p or p.w < 1 or p.h < 1 or p.w * p.h > 16 then return nil end
    for i = 1, p.w * p.h do
      if not p.mids[i] or not Native.hasMid(pair, p.mids[i]) then return nil end
    end
    return p
  end
  local trees, ocean = available(Fill.borderFor("trees")), available(Fill.borderFor("water"))
  local motifDefs = fam == "frlg" and {
    { name = "forest", mids = forestBorder, gates = forestGate },
    { name = "patternBush", mids = patternBushBorder },
    { name = "safari", mids = safariBorder },
  } or {}
  local borderPattern
  if layout.borderWidth == 3 and layout.borderHeight == 2 and layout.borderMids then
    for _, def in ipairs(motifDefs) do
      local matches = true
      for i, mid in ipairs(def.mids) do
        if layout.borderMids[i] ~= mid then matches = false end
      end
      if matches then
        local motif = available({ w = 3, h = 2, mids = def.mids })
        if motif then
          borderPattern = { name = def.name, motif = motif, gates = def.gates }
          break
        end
      end
    end
  end
  if not trees and not ocean and not borderPattern then return nil end
  local phases = {}
  if trees then
    for i, mid in ipairs(trees.mids) do
      if phases[mid] then
        -- Ambiguous source phases cannot safely complete a partial tree.
        trees, phases = nil, {}
        break
      end
      phases[mid] = { (i - 1) % trees.w, math.floor((i - 1) / trees.w) }
    end
    if trees and fam == "frlg" and trees.w == 2 and trees.h == 2
      and trees.mids[1] == 0x1C and trees.mids[2] == 0x1D
      and trees.mids[3] == 0x14 and trees.mids[4] == 0x15 then
      phases[0x0C], phases[0x0D] = { 0, 0 }, { 1, 0 }
      phases[0x24], phases[0x25] = { 0, 1 }, { 1, 1 }
      phases[0x0B], phases[0x0E] = { 1, 0 }, { 0, 0 }
      phases[0x16], phases[0x17] = { 0, 1 }, { 1, 1 }
      phases[0x1E], phases[0x1F] = { 0, 0 }, { 1, 0 }
      phases[0x26], phases[0x27] = { 0, 1 }, { 1, 1 }
    end
    -- Emerald's own General tree quadrant (verified against Littleroot Town/
    -- Oldale Town/Route 101/Petalburg Woods' authored border). A second,
    -- visually distinct canopy variant sits at the same relative quadrant
    -- offsets one column over in the atlas and completes the same way.
    if trees and fam == "rse" and trees.w == 2 and trees.h == 2
      and trees.mids[1] == 0x1D4 and trees.mids[2] == 0x1D5
      and trees.mids[3] == 0x1DC and trees.mids[4] == 0x1DD
      and Native.hasMid(pair, 0x1D6) and Native.hasMid(pair, 0x1D7)
      and Native.hasMid(pair, 0x1DE) and Native.hasMid(pair, 0x1DF) then
      phases[0x1D6], phases[0x1D7] = { 0, 0 }, { 1, 0 }
      phases[0x1DE], phases[0x1DF] = { 0, 1 }, { 1, 1 }
    end
  end
  local borderPhases = {}
  if borderPattern then
    for i, mid in ipairs(borderPattern.motif.mids) do
      borderPhases[mid] = { (i - 1) % 3, math.floor((i - 1) / 3) }
    end
    if borderPattern.name == "forest" then
      for x = 0, 2 do
        borderPhases[0x288 + x] = { x, 0 }
        borderPhases[0x2A0 + x] = { x, 1 }
        borderPhases[0x2A3 + x] = { x, 0 }
      end
      borderPhases[0x28E], borderPhases[0x28F] = { 0, 1 }, { 2, 1 }
    end
  end
  local w, h = layout.width, layout.height
  local coastAvailable = fam == "frlg" and ocean and Native.hasMid(pair, 0x12B)
  local completeCrown = fam == "frlg" and trees and Native.hasMid(pair, 0x0FA) and Native.hasMid(pair, 0x0FB)
  local function at(p, x, y) return p.mids[(y % p.h) * p.w + x % p.w + 1] end
  local function period(size, axis)
    local p = math.min(size, depth)
    for _, motif in ipairs({
      trees or false, ocean or false, borderPattern and borderPattern.motif or false,
    }) do
      if motif then p = p / gcd(p, motif[axis]) * motif[axis] end
    end
    return p
  end
  local periodX, periodY = period(w, "w"), period(h, "h")
  local function strip(position, size)
    local d = math.min(size, depth)
    if position < 0 then return (-position - 1) % d end
    if position >= size then return size - 1 - (position - size) % d end
    return position
  end
  local function cornerDistance(position, size, span)
    if position < 0 then return (-position - 1) % span + 1 end
    if position >= size then return (position - size) % span + 1 end
    return 0
  end
  local function edge(x, y)
    local bx, by = math.max(0, math.min(w - 1, x)), math.max(0, math.min(h - 1, y))
    return bx, by, layout:midAt(bx, by)
  end
  local function oceanSide(mid, x, y)
    local direction = shore[mid]
    return direction and (x == 0 or x * direction[1] > 0)
      and (y == 0 or y * direction[2] > 0)
  end
  local function cliffCorner(mid)
    local wall = walls[mid]
    return wall and wall[1] and wall[2] and mid or nil
  end
  local function classifySource(sx, sy, mid, x, y, axis)
    local dx, dy = x - sx, y - sy
    local motif = borderPattern and borderPattern.motif
    local motifPhase = borderPhases[mid]
    if motif and motifPhase then return at(motif, motifPhase[1] + dx, motifPhase[2] + dy) end
    local row = fam == "frlg" and treeRows[mid]
    if row then
      if not Native.hasMid(pair, row[1]) or not Native.hasMid(pair, row[2]) then return nil end
      if y == sy then return row[(row[3] + dx) % 2 + 1] end
      if row[4] and y < sy and ocean then return at(ocean, x, y) end
      if trees then return at(trees, row[3] + dx, dy + (row[4] and 1 or 0)) end
    end
    local phase = phases[mid]
    if trees and phase then return at(trees, phase[1] + dx, phase[2] + dy) end
    if fam == "frlg" and ocean and (water[mid] or coastAvailable and oceanSide(mid, dx, dy)) then
      return at(ocean, x, y)
    end
    if fam == "frlg" and cliffs[mid] then
      local wall = walls[mid]
      local target = axis == "horizontal" and wall and wall[2]
        or axis == "vertical" and wall and wall[1]
        or axis == "corner" and cliffCorner(mid)
        or 0x071
      if target and Native.hasMid(pair, target) then return target end
    end
    if fam == "frlg" and fences[mid] then return mid end
    if motif and borderPattern.gates and borderPattern.gates[mid] then return at(motif, x, y) end
    if fam == "frlg" and buildings[mid] and (motif or trees) then return at(motif or trees, x, y) end
  end
  local function mergeCorner(horizontal, vertical, corner, x, y)
    if horizontal and vertical then
      local ax, ay = cornerDistance(x, w, periodX), cornerDistance(y, h, periodY)
      if horizontal == vertical then return horizontal end
      if ax < ay then return vertical end
      if ay < ax then return horizontal end
      return corner or horizontal
    end
    -- Only one side matched a recognized family (the other is unrecognized/plain
    -- terrain): always use it rather than letting distance discard a valid match.
    return horizontal or vertical or corner
  end
  local function classify(x, y)
    if x >= 0 and x < w and y >= 0 and y < h then return nil end
    local bx, by, mid = edge(x, y)
    if x ~= bx and y ~= by then
      local sx, sy = strip(x, w), strip(y, h)
      return mergeCorner(
        classifySource(sx, by, layout:midAt(sx, by), x, y, "horizontal"),
        classifySource(bx, sy, layout:midAt(bx, sy), x, y, "vertical"),
        classifySource(bx, by, mid, x, y, "corner"),
        x, y)
    end
    return classifySource(bx, by, mid, x, y, x == bx and "horizontal" or "vertical")
  end
  return {
    sample = classify,
    periodX = periodX, periodY = periodY,
    finish = function(x, y)
      local bx, by, mid = edge(x, y)
      local row = treeRows[mid]
      if row and row[4] and completeCrown and y - by == 1 and math.abs(x - bx) <= 1 then
        return (row[3] + x - bx) % 2 == 0 and 0x0FA or 0x0FB
      end
      if coastAvailable and oceanSide(mid, x - bx, y - by)
        and math.max(math.abs(x - bx), math.abs(y - by)) == 1 then return 0x12B end
    end,
  }
end

return S
