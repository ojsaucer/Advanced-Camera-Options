local G = {}

function G.finite(n)
  return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function G.clamp(n, lo, hi)
  return math.max(lo, math.min(hi, n))
end

function G.limitingAxes(width, height, vw, vh)
  local x, y = width / vw, height / vh
  local tolerance = 1e-7 * math.max(x, y)
  return x >= y - tolerance, y >= x - tolerance
end

function G.project(bounds, vw, vh, px, py, mode, zoom, referenceScale, maxScale)
  for _, key in ipairs({ "x", "y", "w", "h" }) do
    assert(G.finite(bounds[key]), "Invalid camera bound: " .. key)
  end
  assert(G.finite(vw) and G.finite(vh) and vw > 0 and vh > 0)
  assert(G.finite(px) and G.finite(py) and G.finite(zoom) and zoom > 0)
  assert(referenceScale == nil or (G.finite(referenceScale) and referenceScale > 0),
    "Invalid reference scale")
  assert(maxScale == nil or (G.finite(maxScale) and maxScale > 0), "Invalid maximum scale")
  assert(bounds.w > 0 and bounds.h > 0)
  local x, y, w, h = bounds.x, bounds.y, bounds.w, bounds.h
  local scale = math.min(vw / w, vh / h)
  if mode == "hybrid" then
    local constrainX, constrainY = G.limitingAxes(w, h, vw, vh)
    scale = scale * zoom
    local viewW, viewH = vw / scale, vh / scale
    local viewX, viewY = px + 8 - viewW / 2, py + 8 - viewH / 2
    if constrainX then viewX = G.clamp(viewX, x, x + w - viewW) end
    if constrainY then viewY = G.clamp(viewY, y, y + h - viewH) end
    local capture = G.intersection(bounds, { x = viewX, y = viewY, w = viewW, h = viewH })
    -- The adapter supplies an in-map player; keep direct off-map probes valid too.
    capture = capture or { x = G.clamp(px, x, x + w - 1),
      y = G.clamp(py, y, y + h - 1), w = 1, h = 1 }
    return { x = capture.x, y = capture.y, w = capture.w, h = capture.h,
      scale = scale, dx = (capture.x - viewX) * scale, dy = (capture.y - viewY) * scale,
      constrainX = constrainX, constrainY = constrainY }
  end
  if mode == "scroll" then
    -- Full's own scale is limited by whichever axis needs the MOST zoom-out
    -- (the min of the two fits). Scroll instead uses the LEAST zoom-out
    -- needed (the max): the axis that already fit without slack in Full stays
    -- locked here too, while the other axis - the one Full had to shrink
    -- further to accommodate - gets genuine room to scroll with the player,
    -- clamped to the map's own bounds so it never reveals anything past it.
    scale = math.max(vw / w, vh / h)
    local viewW, viewH = vw / scale, vh / scale
    local constrainY, constrainX = G.limitingAxes(w, h, vw, vh)
    local viewX = G.clamp(px + 8 - viewW / 2, x, x + w - viewW)
    local viewY = G.clamp(py + 8 - viewH / 2, y, y + h - viewH)
    return { x = viewX, y = viewY, w = viewW, h = viewH,
      scale = scale, dx = 0, dy = 0,
      constrainX = constrainX, constrainY = constrainY }
  end
  if mode == "partial" then
    -- Without a map-independent reference, retain the original area-relative fit.
    scale = math.max((referenceScale or scale) * zoom, vw / w, vh / h)
    if maxScale then scale = math.min(scale, maxScale) end
    w, h = math.min(w, vw / scale), math.min(h, vh / scale)
    x = G.clamp(px + 8 - w / 2, bounds.x, bounds.x + bounds.w - w)
    y = G.clamp(py + 8 - h / 2, bounds.y, bounds.y + bounds.h - h)
  end
  return { x = x, y = y, w = w, h = h, scale = scale,
    dx = (vw - w * scale) / 2, dy = (vh - h * scale) / 2 }
end

function G.mix(kind, progress, w, h, direction)
  local p = G.clamp(progress, 0, 1)
  if kind == "fade" then
    return { 0, 0, math.max(0, 1 - 2 * p) },
      { 0, 0, math.max(0, 2 * p - 1) }
  end
  local dx = direction == "east" and w or direction == "west" and -w or 0
  local dy = direction == "south" and h or direction == "north" and -h or 0
  assert(kind == "slide" and (dx ~= 0 or dy ~= 0), "Slide needs a crossing direction")
  return { -p * dx, -p * dy, 1 }, { (1 - p) * dx, (1 - p) * dy, 1 }
end

function G.intersection(a, b)
  local x, y = math.max(a.x, b.x), math.max(a.y, b.y)
  local r, bottom = math.min(a.x + a.w, b.x + b.w), math.min(a.y + a.h, b.y + b.h)
  if r <= x or bottom <= y then return nil end
  return { x = x, y = y, w = r - x, h = bottom - y }
end

G.directions = { { 0, -1, "up" }, { 0, 1, "down" },
  { -1, 0, "left" }, { 1, 0, "right" } }

-- A bounded graph traversal, not a mutation or simulation of player movement.
-- step(x,y,direction) supplies read-only terrain semantics from the adapter.
function G.reachable(width, height, sx, sy, padding, step)
  assert(width >= 1 and height >= 1 and width * height <= 32768)
  sx, sy = G.clamp(math.floor(sx), 0, width - 1), G.clamp(math.floor(sy), 0, height - 1)
  local queue, seen = { { sx, sy } }, { [sy * width + sx + 1] = true }
  local minX, maxX, minY, maxY = sx, sx, sy, sy
  local head = 1
  while head <= #queue do
    local cell = queue[head]
    head = head + 1
    for _, direction in ipairs(G.directions) do
      local x, y = step(cell[1], cell[2], direction)
      if x and y and x >= 0 and y >= 0 and x < width and y < height then
        local key = y * width + x + 1
        if not seen[key] then
          seen[key] = true
          queue[#queue + 1] = { x, y }
          minX, maxX = math.min(minX, x), math.max(maxX, x)
          minY, maxY = math.min(minY, y), math.max(maxY, y)
        end
      end
    end
  end
  minX, minY = math.max(0, minX - padding), math.max(0, minY - padding)
  maxX, maxY = math.min(width - 1, maxX + padding), math.min(height - 1, maxY + padding)
  return { x = minX * 16, y = minY * 16,
    w = (maxX - minX + 1) * 16, h = (maxY - minY + 1) * 16 }
end

return G
