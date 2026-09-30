return function(ctx)
  local T = ctx.T
  local S = assert(loadfile(ctx.root .. "\\scenery_patterns.lua"))()
  local B = assert(loadfile(ctx.root .. "\\void_backdrop.lua"))()
  -- This whole file assumes FRLG's own verified MID families. Force that
  -- context regardless of what any earlier test left GameVersion set to,
  -- and restore it afterward so later tests are unaffected.
  local GameVersion = require("src.core.GameVersion")
  local savedVersion = GameVersion.current
  GameVersion.current = "firered"
  local trees = { w = 2, h = 2, mids = { 0x1C, 0x1D, 0x14, 0x15 } }
  local ocean = { w = 1, h = 1, mids = { 0x1D9 } }
  local Fill = { primaryFor = function(pair) return pair == "general" and "general" or "building" end,
    borderFor = function(mode) return mode == "trees" and trees or ocean end }
  local Native = { hasMid = function() return true end }
  local mid = 0x1C
  local layout = { width = 5, height = 5, midAt = function() return mid end }
  for _, depth in ipairs({ 1, 2, 8, 16 }) do
    local r = S.new(layout, "general", Fill, Native, depth)
    T.eq(r.sample(2, 2), nil, "scenery resolver never replaces real map cells")
    T.check(r.periodX % 2 == 0 and r.periodY % 2 == 0, "whole tree periods never cut at fallback depth")
    T.check(r.periodX % math.min(5, depth) == 0 and r.periodY % math.min(5, depth) == 0,
      "combined periods preserve the exact fallback strip period")
    for _, p in ipairs({ { -1, 2 }, { 5, 2 }, { 2, -1 }, { 2, 5 },
      { -3, -3 }, { 7, -3 }, { -3, 7 }, { 7, 7 } }) do
      local x, y = unpack(p)
      local bx, by = math.max(0, math.min(4, x)), math.max(0, math.min(4, y))
      for i, m in ipairs(trees.mids) do
        mid = m
        local tx, ty = (i - 1) % 2, math.floor((i - 1) / 2)
        T.eq(r.sample(x, y), trees.mids[((ty + y - by) % 2) * 2 + (tx + x - bx) % 2 + 1],
          "tree continuation retains phase on all edges and corners")
      end
      for _, rock in ipairs({ 0x110, 0x111, 0x118, 0x119, 0x1CB, 0x1CC, 0x1D3, 0x1D4 }) do
        mid = rock
        T.eq(r.sample(x, y), 0x1D9, "water rock extension is ocean, not duplicated rock")
        T.eq(r.finish(x, y), nil, "water rock has no repeated shoreline overlay")
      end
    end
    mid = 0x123
    T.eq(r.sample(2, 5), 0x1D9, "water-facing shoreline switches to ocean")
    T.eq(r.finish(2, 5), 0x12B, "shoreline has a finite completion")
    T.eq(r.finish(2, 6), nil, "shoreline does not repeat offshore")
    T.eq(r.sample(2, -1), nil, "land-facing shoreline remains fallback")
    mid = 0x12A
    T.eq(r.finish(5, 2), 0x12B, "west coast completes eastward")
    mid = 0x12C
    T.eq(r.finish(-1, 2), 0x12B, "east coast completes westward")
    mid = 0x1234
    T.eq(r.sample(-1, -1), nil, "unknown scenery explicitly retains strips")
  end
  T.eq(S.new(layout, "building", Fill, Native, 1), nil, "different primary is never classified by General IDs")
  Native.hasMid = function(_, m) return m ~= 0x1D9 end
  mid = 0x1CB
  T.eq(S.new(layout, "general", Fill, Native, 1).sample(-1, 2), nil,
    "missing ocean atlas tile keeps fallback instead of slot zero")
  Native.hasMid = function(_, m) return m ~= 0x12B end
  mid = 0x123
  T.eq(S.new(layout, "general", Fill, Native, 1).sample(2, 5), nil,
    "missing coastal completion leaves the original shoreline strip")
  Native.hasMid = function() return true end
  local borderFor = Fill.borderFor
  Fill.borderFor = function() return nil end
  T.eq(S.new(layout, "general", Fill, Native, 1), nil, "unavailable source maps preserve original extrusion")
  Fill.borderFor = borderFor
  Native.hasMid = function(_, m) return m ~= 0x15 end
  mid = 0x1C
  T.eq(S.new(layout, "general", Fill, Native, 1).sample(-1, 2), nil,
    "incomplete tree motif never silently substitutes atlas slot zero")
  Native.hasMid = function() return true end
  local midAt = layout.midAt
  layout.midAt = function(_, x, y) return x % 2 == 0 and 0x1C or 0x77 end
  local mixed = S.new(layout, "general", Fill, Native, 3)
  T.eq(mixed.sample(1, -1), nil, "mixed edge leaves unknown lane on strip fallback")
  T.eq(mixed.sample(2, -1), 0x14, "mixed edge completes recognized lane independently")
  layout.midAt = midAt
  local forest = { 0x298, 0x299, 0x29A, 0x290, 0x291, 0x292 }
  local patternBush = { 0x290, 0x291, 0x292, 0x298, 0x299, 0x29A }
  local safari = { 0x2F5, 0x2F6, 0x2F7, 0x2FD, 0x2FE, 0x2FF }
  for _, depth in ipairs({ 1, 2, 8, 16 }) do
    local resolver = S.new(layout, "general", Fill, Native, depth)
    for _, m in ipairs({ 0x212, 0x213, 0x21A, 0x21B, 0x1D1, 0x1D8 }) do
      mid = m
      T.eq(resolver.sample(5, 3), 0x1D9, "Route 13/18 water variants become ocean")
    end
    for _, m in ipairs({ 0x068, 0x069, 0x06A, 0x06B, 0x06C, 0x06D, 0x070, 0x071,
      0x072, 0x073, 0x075, 0x078, 0x079, 0x07A, 0x07B, 0x07C, 0x07D, 0x080, 0x081, 0x0B2, 0x0B3 }) do
      mid = m
      T.eq(resolver.sample(2, 2), nil, "real cliff faces remain untouched")
    end
    for _, m in ipairs({ 0x044, 0x045, 0x046, 0x04C, 0x04D, 0x04E, 0x183, 0x1B6, 0x05C, 0x064 }) do
      mid = m
      T.eq(resolver.sample(-3, 2), 0x1D, "building fragments become whole General trees")
    end
    for _, entry in ipairs({ { 0x016, 0, 1 }, { 0x017, 1, 1 }, { 0x01E, 0, 0 },
      { 0x01F, 1, 0 }, { 0x026, 0, 1 }, { 0x027, 1, 1 } }) do
      mid = entry[1]
      T.eq(resolver.sample(-1, 2), trees.mids[entry[3] * 2 + (entry[2] - 1) % 2 + 1],
        "outer General tree variants retain complete motif phase")
    end
    layout.borderWidth, layout.borderHeight, layout.borderMids = 3, 2, forest
    resolver = S.new(layout, "general", Fill, Native, depth)
    T.eq(resolver.periodX % 3, 0, "forest keeps complete three-column motifs at every depth")
    for i, m in ipairs(forest) do
      mid = m
      for _, p in ipairs({ { -1, 2 }, { 5, 2 }, { 2, -1 }, { 2, 5 }, { -1, -1 }, { 5, 5 } }) do
        local x, y = unpack(p)
        local bx, by = math.max(0, math.min(4, x)), math.max(0, math.min(4, y))
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        T.eq(resolver.sample(x, y), forest[((row + y - by) % 2) * 3 + (col + x - bx) % 3 + 1],
          "forest edge and corner continuation uses its own atlas motif")
      end
    end
    mid = 0x04D
    T.eq(resolver.sample(-1, 2), 0x29A, "forest gatehouse extension uses forest trees, not Pallet trees")
    for _, m in ipairs({ 0x0EA, 0x28B, 0x28C, 0x28D, 0x293, 0x294, 0x29D, 0x29E }) do
      mid = m
      T.eq(resolver.sample(-1, 2), 0x29A, "forest-only gate trim does not extrude into stripes")
    end
    layout.borderMids = patternBush
    resolver = S.new(layout, "general", Fill, Native, depth)
    T.eq(resolver.periodX % 3, 0, "Pattern Bush keeps complete three-column motifs at every depth")
    for i, m in ipairs(patternBush) do
      mid = m
      for _, p in ipairs({ { -1, 2 }, { 5, 2 }, { 2, -1 }, { 2, 5 }, { -1, -1 }, { 5, 5 } }) do
        local x, y = unpack(p)
        local bx, by = math.max(0, math.min(4, x)), math.max(0, math.min(4, y))
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        T.eq(resolver.sample(x, y), patternBush[((row + y - by) % 2) * 3 + (col + x - bx) % 3 + 1],
          "Pattern Bush edge and corner continuation uses its own reversed border motif")
      end
    end
    layout.borderMids = safari
    resolver = S.new(layout, "general", Fill, Native, depth)
    T.eq(resolver.periodX % 3, 0, "Safari border keeps complete three-column motifs at every depth")
    for i, m in ipairs(safari) do
      mid = m
      for _, p in ipairs({ { -1, 2 }, { 5, 2 }, { 2, -1 }, { 2, 5 }, { -1, -1 }, { 5, 5 } }) do
        local x, y = unpack(p)
        local bx, by = math.max(0, math.min(4, x)), math.max(0, math.min(4, y))
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        T.eq(resolver.sample(x, y), safari[((row + y - by) % 2) * 3 + (col + x - bx) % 3 + 1],
          "Safari bush edge and corner continuation uses its authored border motif")
      end
    end
    layout.borderWidth, layout.borderHeight, layout.borderMids = nil, nil, nil
    mid = 0x298
    T.eq(S.new(layout, "general", Fill, Native, depth).sample(-1, 2), nil,
      "same secondary MID in a different tileset is not automatically a forest tree")
  end
  layout.borderWidth, layout.borderHeight, layout.borderMids = 3, 2, forest
  Native.hasMid = function(_, m) return m ~= 0x299 end
  mid = 0x298
  T.eq(S.new(layout, "general", Fill, Native, 1).sample(-1, 2), nil,
    "partial forest atlas retains safe strips rather than substituting unrelated tiles")
  Native.hasMid = function() return true end
  layout.borderMids = { 0x298, 0x299, 0x29A, 0x290, 0x291, 0x293 }
  T.eq(S.new(layout, "general", Fill, Native, 1).sample(-1, 2), nil,
    "similar but different border cannot enable forest secondary rules")
  layout.borderWidth, layout.borderHeight, layout.borderMids = nil, nil, nil
  Native.hasMid = function(_, m) return m ~= 0x071 end
  mid = 0x071
  T.eq(S.new(layout, "general", Fill, Native, 1).sample(-1, 2), nil,
    "missing plateau replacement keeps original strip")
  Native.hasMid = function() return true end
  local wallCases = {
    { 0x068, 0x069, 0x070 }, { 0x06A, 0x069, 0x072 },
    { 0x06B, 0x06C, 0x073 }, { 0x06D, 0x06C, 0x075 },
    { 0x078, 0x079, 0x070 }, { 0x07A, 0x079, 0x072 },
    { 0x07B, 0x07C, 0x073 }, { 0x07D, 0x07C, 0x075 },
    { 0x0B2, 0x07C, 0x075 }, { 0x0B3, 0x07C, 0x073 },
  }
  for _, depth in ipairs({ 1, 2, 8, 16 }) do
    local r = S.new(layout, "general", Fill, Native, depth)
    for _, case in ipairs(wallCases) do
      mid = case[1]
      for _, x in ipairs({ -1, -8, 5, 12 }) do
        T.eq(r.sample(x, 2), case[2], "corner wall extends horizontally in both boundary orientations")
      end
      for _, y in ipairs({ -1, -8, 5, 12 }) do
        T.eq(r.sample(2, y), case[3], "corner wall extends vertically in both boundary orientations")
      end
      T.eq(r.sample(-1, -1), case[1], "immediate diagonal cliff corner keeps authored corner artwork")
      T.eq(r.sample(-2, -1), case[3], "diagonal cells closer to the top/bottom edge keep the matching wall axis")
      T.eq(r.sample(-1, -2), case[2], "diagonal cells closer to the side edge keep the matching wall axis")
    end
    for _, m in ipairs({ 0x069, 0x06C, 0x079, 0x07C }) do
      mid = m
      T.eq(r.sample(-1, 2), m, "straight horizontal wall remains a wall, not plateau")
      T.eq(r.sample(5, 2), m, "straight horizontal wall continues rightward")
      T.eq(r.sample(-1, -1), 0x071, "straight horizontal wall still falls back to plateau at the corner tie")
    end
    for _, m in ipairs({ 0x070, 0x072, 0x073, 0x075 }) do
      mid = m
      T.eq(r.sample(2, -1), m, "straight vertical wall continues upward")
      T.eq(r.sample(2, 5), m, "straight vertical wall continues downward")
      T.eq(r.sample(-1, -1), 0x071, "straight vertical wall still falls back to plateau at the corner tie")
    end
    for _, m in ipairs({ 0x10F, 0x117, 0x11F, 0x129, 0x1DA, 0x1E1 }) do
      mid = m
      T.eq(r.sample(2, -1), 0x1D9, "Seafoam mixed mountain/water boundary becomes ocean")
    end
    mid = 0x10B
    T.eq(r.sample(5, 2), 0x10A, "water-facing tree crown alternates its complete pair eastward")
    T.eq(r.sample(6, 2), 0x10B, "water-facing tree crown retains second half")
    T.eq(r.sample(2, -1), 0x1D9, "water-facing tree extends as ocean to north")
    T.eq(r.finish(2, 5), 0x0FB, "partial crown completes once below its edge")
    mid = 0x0FB
    T.eq(r.sample(5, 2), 0x0FA, "second canopy row aligns with the first")
    mid = 0x00F
    T.eq(r.sample(5, 2), 0x00E, "grass-facing crown uses its complete paired artwork")
    mid = 0x0D6
    T.eq(r.sample(-1, 2), 0x0D6, "fence edges repeat as themselves instead of falling into tree logic")
    T.eq(r.sample(-1, -1), 0x0D6, "fence corners keep the same fence MID when both sides agree")
    for _, m in ipairs({ 0x0F4, 0x29B, 0x29C, 0x2D3 }) do
      mid = m
      T.eq(r.sample(-1, 2), m, "guardrail/additional fence posts also repeat as themselves")
    end
  end
  layout.midAt = function(_, x, y)
    if x == 0 then return 0x06D end
    if y == 0 then return 0x00E end
    return 0x77
  end
  local mixedCorner = S.new(layout, "general", Fill, Native, 3)
  T.eq(mixedCorner.sample(-1, -1), 0x06D, "diagonal ties keep the authored cliff corner when both recognized sides disagree")
  T.eq(mixedCorner.sample(-3, -1), 0x15, "diagonal cells nearer the top edge keep the tree phase instead of the cliff")
  T.eq(mixedCorner.sample(-1, -3), 0x06C, "diagonal cells nearer the side edge keep the matching cliff axis instead of the tree")
  -- Regression: one side of a corner recognized (a building extending as trees
  -- along the top edge) while the other side, and the literal corner tile
  -- itself, are ordinary unrecognized terrain (a common real map layout).
  -- Distance-based tie-breaking must never discard the one valid match.
  layout.midAt = function(_, x, y)
    if x == 0 and y == 0 then return 0x77 end
    if y == 0 then return 0x044 end
    return 0x77
  end
  local rowCorner = S.new(layout, "general", Fill, Native, 3)
  T.check(rowCorner.sample(-2, -4) ~= nil,
    "diagonal corner keeps its one recognized (row) side even when farther from that edge")
  layout.midAt = function(_, x, y)
    if x == 0 and y == 0 then return 0x77 end
    if x == 0 then return 0x044 end
    return 0x77
  end
  local columnCorner = S.new(layout, "general", Fill, Native, 3)
  T.check(columnCorner.sample(-4, -2) ~= nil,
    "diagonal corner keeps its one recognized (column) side even when farther from that edge")
  layout.midAt = midAt
  Native.hasMid = function(_, m) return m ~= 0x075 end
  mid = 0x07D
  T.eq(S.new(layout, "general", Fill, Native, 1).sample(2, 5), nil,
    "missing oriented wall preserves strip fallback instead of wrong plateau")
  Native.hasMid = function() return true end

  -- Emerald ships an entirely different ROM with its own "general"-primary
  -- tileset; FRLG-verified hardcoded MIDs (cliffs, water quarters, fences,
  -- forest/pattern-bush/safari borders, and FRLG's phase-alias table) must
  -- never fire there even if they numerically coincide with something in
  -- Emerald's own atlas. The dynamically-sourced tree/water quadrant (driven
  -- by the engine's own per-family VoidFill border, not a hardcoded FRLG
  -- list) is family-agnostic and should keep working for Emerald with
  -- Emerald's own border shape.
  mid = 0x1C
  layout.midAt = midAt
  if type(GameVersion.layout) == "function" and GameVersion.VERSIONS and GameVersion.VERSIONS.emerald then
    GameVersion.current = "emerald"
    T.eq(GameVersion.layout(GameVersion.current), "rse", "fixture actually exercises the rse layout")
    -- FRLG's own hardcoded families never fire under rse, even reusing the
    -- exact FRLG-shaped border/tree data and numerically-FRLG MIDs.
    mid = 0x0B -- FRLG-only tree phase alias
    T.eq(S.new(layout, "general", Fill, Native, 1).sample(-1, 2), nil,
      "FRLG's tree phase aliases never engage outside frlg layout")
    mid = 0x068 -- FRLG-only cliff/wall MID
    T.eq(S.new(layout, "general", Fill, Native, 1).sample(-1, 2), nil,
      "FRLG's cliff/wall family never engages outside frlg layout")
    mid = 0x0D6 -- FRLG-only fence MID
    T.eq(S.new(layout, "general", Fill, Native, 1).sample(-1, 2), nil,
      "FRLG's fence family never engages outside frlg layout")
    mid = 0x1C -- the fixture's own base tree quadrant tile
    T.eq(S.new(layout, "general", Fill, Native, 1).sample(-1, 2), 0x1D,
      "the family-agnostic tree quadrant (driven by the engine's own per-family "
      .. "border, not a hardcoded FRLG list) still completes under rse")
    -- Emerald's own verified General tree quadrant (Littleroot Town/Oldale
    -- Town/Route 101/Petalburg Woods' authored border), with its second,
    -- visually distinct canopy variant one column over in the atlas.
    local emeraldTrees = { w = 2, h = 2, mids = { 0x1D4, 0x1D5, 0x1DC, 0x1DD } }
    local oldBorderFor = Fill.borderFor
    Fill.borderFor = function(mode) return mode == "trees" and emeraldTrees or ocean end
    mid = 0x1D4
    local er = S.new(layout, "general", Fill, Native, 1)
    T.eq(er.sample(-1, 2), 0x1D5, "Emerald's own tree quadrant completes on its authored border")
    T.eq(er.sample(-1, -1), 0x1DD, "Emerald's own tree quadrant continues around corners")
    mid = 0x1D6
    T.eq(er.sample(5, 2), 0x1D5, "Emerald's second canopy variant completes using the base quadrant")
    T.eq(er.sample(2, 6), 0x1D4, "Emerald's second canopy variant continues vertically via the base quadrant")
    Native.hasMid = function(_, m) return m ~= 0x1D6 and m ~= 0x1D7 and m ~= 0x1DE and m ~= 0x1DF end
    mid = 0x1D6
    T.eq(S.new(layout, "general", Fill, Native, 1).sample(5, 2), nil,
      "Emerald's second canopy variant requires all of its own atlas slots to be present")
    mid = 0x1D4
    T.eq(S.new(layout, "general", Fill, Native, 1).sample(-1, 2), 0x1D5,
      "Emerald's base quadrant does not require the second canopy variant's atlas slots")
    Native.hasMid = function() return true end
    Fill.borderFor = oldBorderFor
    GameVersion.current = "firered"
  end

  if not love._staticCameraGpu then
    GameVersion.current = savedVersion
    return
  end
  local lg = love.graphics
  local originalFill, originalNative = package.loaded["src.core.game3.void_fill"],
    package.loaded["src.core.game3.tileset_native"]
  local owned = {}
  local function own(o) owned[#owned + 1] = o; return o end
  local ids = { 0x1C, 0x1D, 0x14, 0x15, 0x1D9, 0x12B, 0x123, 0x1CB, 0x77,
    0x21A, 0x071, 0x06C, 0x04D, 0x298, 0x299, 0x29A, 0x290, 0x291, 0x292,
    0x2F5, 0x2F6, 0x2F7, 0x2FD, 0x2FE, 0x2FF, 0x0D6, 0x07C, 0x07D, 0x075, 0x07B, 0x073, 0x068, 0x069, 0x070,
    0x06A, 0x072, 0x10F, 0x117, 0x10A, 0x10B, 0x0FA, 0x0FB, 0x00E, 0x00F }
  local colors, quads = {}, {}
  local data = own(love.image.newImageData(#ids * 16, 16))
  for i, m in ipairs(ids) do
    colors[m] = { i / (#ids + 1), 0.5, 0.25 }
    quads[m] = own(lg.newQuad((i - 1) * 16, 0, 16, 16, #ids * 16, 16))
  end
  data:mapPixel(function(x) local c = colors[ids[math.floor(x / 16) + 1]]; return c[1], c[2], c[3], 1 end)
  local image = own(lg.newImage(data))
  image:setFilter("nearest", "nearest")
  Native.get = function() return { image = image } end
  Native.slotFor = function(_, m) return m end
  Native.quad = function(_, m) return assert(quads[m], "unexpected fixture MID") end
  package.loaded["src.core.game3.void_fill"], package.loaded["src.core.game3.tileset_native"] = Fill, Native
  local backdrop = B.new(function(_, message) error(message) end, function(w, h)
    lg.setColor(0, 0, 0, 0.25)
    lg.rectangle("fill", 0, 0, w, h)
  end, S)
  local output = own(lg.newCanvas(256, 192))
  local Geometry = assert(loadfile(ctx.root .. "\\tilt_geometry.lua"))()
  local Tilt, Renderer = require("src.render.Tilt"), require("src.render.Renderer")
  local previousAngle = Tilt.angle
  local ok, err = xpcall(function()
    for _, depth in ipairs({ 1, 2, 8, 16 }) do
      for _, sourceMid in ipairs({ 0x1C, 0x1CB, 0x123, 0x77, 0x21A, 0x06C, 0x04D, 0x298, 0x292, 0x2F5, 0x0D6,
        0x07C, 0x07D, 0x07B, 0x068, 0x06A, 0x10F, 0x117, 0x10B, 0x0FB, 0x00F }) do
        mid = sourceMid
        if mid >= 0x2F5 and mid <= 0x2FF then
          layout.borderWidth, layout.borderHeight, layout.borderMids = 3, 2, safari
        elseif mid >= 0x280 then
          layout.borderWidth, layout.borderHeight, layout.borderMids = 3, 2, forest
        else layout.borderWidth, layout.borderHeight, layout.borderMids = nil, nil, nil end
        local resolver = S.new(layout, "general", Fill, Native, depth)
        local desc = backdrop.resolve(layout, "general", "extrude", depth)
        for _, degrees in ipairs({ 0, 15, 35, 50 }) do
          Tilt.angle = math.rad(degrees)
          local frame = degrees == 0 and { x = -88, y = -56, dx = 0, dy = 0, scale = 1 }
            or Geometry.project({ x = 0, y = 0, w = 80, h = 80 }, 256, 192, 0, 0, "full", 1, nil, Tilt)
          lg.push("all")
          lg.setCanvas(output)
          lg.origin()
          lg.setColor(1, 1, 1, 1)
          lg.clear(0, 0, 0, 0)
          backdrop.draw(desc, frame, 256, 192, {}, Renderer)
          lg.setCanvas()
          lg.pop()
          local pixels = output:newImageData()
          local samples = 0
          for sy = 2, 189, 3 do
            for sx = 2, 253, 3 do
              local wx, wy
              if degrees == 0 then wx, wy = sx + 0.5 - 88, sy + 0.5 - 56
              else wx, wy = frame.worldAt(sx + 0.5, sy + 0.5) end
              local x, y = math.floor(wx / 16), math.floor(wy / 16)
              if (x < 0 or x >= 5 or y < 0 or y >= 5)
                and wx % 16 > 3 and wx % 16 < 13 and wy % 16 > 3 and wy % 16 < 13
                and (degrees == 0 or sy > frame.horizon + 1) then
                local want = resolver.finish(x, y) or resolver.sample(x, y) or sourceMid
                local c = colors[want]
                local r, g, b, a = pixels:getPixel(sx, sy)
                T.check(math.abs(r - c[1] * 0.75) + math.abs(g - c[2] * 0.75)
                  + math.abs(b - c[3] * 0.75) < 0.035 and a > 0.99,
                  ("GPU: scenery source=%X depth=%d angle=%d world=%d,%d expected=%X rgb=%.3f,%.3f,%.3f")
                    :format(sourceMid, depth, degrees, x, y, want, r, g, b))
                samples = samples + 1
              end
            end
          end
          T.check(samples > 80, "GPU: content-aware fill samples meaningful outside area")
          pixels:release()
        end
      end
    end
  end, debug.traceback)
  Tilt.angle = previousAngle
  backdrop.dispose()
  package.loaded["src.core.game3.void_fill"], package.loaded["src.core.game3.tileset_native"] = originalFill, originalNative
  for _, o in ipairs(owned) do o:release() end
  GameVersion.current = savedVersion
  if not ok then error(err, 0) end
end
