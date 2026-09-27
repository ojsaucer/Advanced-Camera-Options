local T = {}

function T.envelope(sizes, previous)
  local e = { left = 8, right = 8, top = 48, bottom = 0 }
  for _, s in ipairs(sizes) do
    local width, height = s.width or 16, s.height or 32
    e.left, e.right = math.max(e.left, width / 2), math.max(e.right, width / 2)
    e.top = math.max(e.top, height + 16)
  end
  if previous then
    for k, v in pairs(previous) do e[k] = math.max(e[k], v) end
  end
  return e
end

-- Inverse of audited 0.3.19 Tilt.groundPoint. Coordinates are relative
-- to the projection centre, before the camera's world-unit scale.
function T.inverse(x, y, vw, vh, angle, focal)
  local d = focal * vh
  local v = y - vh / 2
  local w = v * d / (math.cos(angle) * d + v * math.sin(angle))
  return (x - vw / 2) * (d - w * math.sin(angle)) / d, w
end

function T.project(bounds, vw, vh, px, py, mode, zoom, referenceScale, Tilt, envelope)
  local angle, focal = Tilt.angle, Tilt.FOCAL
  assert(angle >= 0 and angle <= math.rad(50) + 1e-8 and focal > 0,
    "Unsupported Tilt projection")
  local groundPoint = Tilt.groundPoint
  envelope = envelope or T.envelope({})
  local margin = math.max(160, envelope.left, envelope.right, envelope.top, envelope.bottom)
  local function point(x, y, cx, cy, scale)
    return groundPoint(vw / 2 + (x - cx) * scale,
      vh / 2 + (y - cy) * scale, vw, vh)
  end
  local cx, cy = bounds.x + bounds.w / 2, bounds.y + bounds.h / 2
  local corners = { { bounds.x, bounds.y }, { bounds.x + bounds.w, bounds.y },
    { bounds.x + bounds.w, bounds.y + bounds.h }, { bounds.x, bounds.y + bounds.h } }
  local function extents(scale)
    local l, t, r, b = math.huge, math.huge, -math.huge, -math.huge
    for _, p in ipairs(corners) do
      local x, y, q = point(p[1], p[2], cx, cy, scale)
      if q <= 0 then return nil end
      l, t = math.min(l, x - envelope.left * scale * q), math.min(t, y - envelope.top * scale * q)
      r, b = math.max(r, x + envelope.right * scale * q), math.max(b, y + envelope.bottom * scale * q)
    end
    return l, t, r, b
  end
  local lo, hi = 0, math.min(vw / bounds.w, vh / bounds.h)
  for _ = 1, 52 do
    local mid = (lo + hi) / 2
    local l, t, r, b = extents(mid)
    if l and r - l <= vw and b - t <= vh then lo = mid else hi = mid end
  end
  local fullScale, scale, dx, dy = lo, lo, 0, 0
  local capture = { x = bounds.x, y = bounds.y, w = bounds.w, h = bounds.h }
  local footprint, ground = nil, capture
  if mode == "partial" then
    local l, t, r, b = math.huge, math.huge, -math.huge, -math.huge
    footprint = {}
    for i, p in ipairs({ { 0, 0 }, { vw, 0 }, { vw, vh }, { 0, vh } }) do
      local x, y = T.inverse(p[1], p[2], vw, vh, angle, focal)
      footprint[i] = { x, y }
      l, t, r, b = math.min(l, x), math.min(t, y), math.max(r, x), math.max(b, y)
    end
    scale = math.max((referenceScale or fullScale) * zoom,
      (r - l) / bounds.w, (b - t) / bounds.h)
    local function clamp(n, low, high) return math.max(low, math.min(high, n)) end
    cx = clamp(px + 8, bounds.x - l / scale, bounds.x + bounds.w - r / scale)
    cy = clamp(py + 8, bounds.y - t / scale, bounds.y + bounds.h - b / scale)
    for _, p in ipairs(footprint) do p[1], p[2] = cx + p[1] / scale, cy + p[2] / scale end
    ground = { x = cx + l / scale, y = cy + t / scale,
      w = (r - l) / scale, h = (b - t) / scale }
    -- Include offscreen feet whose upright sprite can still enter the frame.
    local x, y = math.max(bounds.x, cx + l / scale - margin), math.max(bounds.y, cy + t / scale - margin)
    capture = { x = x, y = y,
      w = math.min(bounds.x + bounds.w, cx + r / scale + margin) - x,
      h = math.min(bounds.y + bounds.h, cy + b / scale + margin) - y }
  else
    local l, t, r, b = extents(scale)
    dx, dy = (vw - l - r) / 2, (vh - t - b) / 2
  end
  local frame = { x = capture.x, y = capture.y, w = capture.w, h = capture.h,
    scale = scale, dx = dx, dy = dy, cx = cx, cy = cy, vw = vw, vh = vh,
    footprint = footprint, angle = angle, bounds = bounds, ground = ground }
  frame.horizon = angle > 0 and vh / 2 + dy - focal * vh / math.tan(angle) or -math.huge
  function frame.worldAt(sx, sy)
    local x, y = T.inverse(sx - dx, sy - dy, vw, vh, angle, focal)
    return cx + x / scale, cy + y / scale
  end
  function frame.point(x, y)
    local sx, sy, q = point(x, y, cx, cy, scale)
    return sx + dx, sy + dy, q
  end
  return frame
end

return T
