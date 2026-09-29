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

function T.project(bounds, vw, vh, px, py, mode, zoom, referenceScale, Tilt, envelope, maxScale)
  local angle, focal = Tilt.angle, Tilt.FOCAL
  assert(angle >= 0 and angle <= math.rad(50) + 1e-8 and focal > 0,
    "Unsupported Tilt projection")
  assert(maxScale == nil or (type(maxScale) == "number" and maxScale > 0
    and maxScale < math.huge), "Invalid maximum scale")
  local groundPoint = Tilt.groundPoint
  local magnification = 1
  envelope = envelope or T.envelope({})
  local margin = math.max(160, envelope.left, envelope.right, envelope.top, envelope.bottom)
  local function point(x, y, cx, cy, scale)
    local sx, sy, q = groundPoint(vw / 2 + (x - cx) * scale / magnification,
      vh / 2 + (y - cy) * scale / magnification, vw, vh)
    return vw / 2 + (sx - vw / 2) * magnification,
      vh / 2 + (sy - vh / 2) * magnification, q
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
  local constrainX, constrainY
  if mode == "hybrid" or mode == "scroll" then
    local l, t, r, b = extents(fullScale)
    local xRatio, yRatio = (r - l) / vw, (b - t) / vh
    local tolerance = 1e-7 * math.max(xRatio, yRatio)
    local limitX, limitY = xRatio >= yRatio - tolerance, yRatio >= xRatio - tolerance
    local m = zoom
    if mode == "scroll" then
      -- Swapped from Hybrid: lock the axis that already fit Full without
      -- slack (limitX/limitY true), letting the OTHER axis - the one Full
      -- had to shrink further to accommodate - scroll with the player.
      -- Magnify by exactly enough that the now-locked axis's own projected
      -- envelope fits its viewport dimension precisely; the previously
      -- limiting axis then necessarily exceeds its dimension, giving genuine
      -- (still clamped, never void-revealing) room to scroll.
      constrainX, constrainY = limitY, limitX
      m = constrainX and (vw / (r - l)) or (vh / (b - t))
    else
      constrainX, constrainY = limitX, limitY
    end
    -- Magnify Full's actual projected envelope, not a new perspective fit.
    -- Scaling focal distance too preserves its horizon and upright proportions.
    magnification, scale, focal = m, fullScale * m, focal * m
    l, r = vw / 2 + (l - vw / 2) * m, vw / 2 + (r - vw / 2) * m
    t, b = vh / 2 + (t - vh / 2) * m, vh / 2 + (b - vh / 2) * m
    local sx, sy = point(px + 8, py + 8, cx, cy, scale)
    local function offset(n, low, high)
      if low > high then return (low + high) / 2 end
      return math.max(low, math.min(high, n))
    end
    if mode == "scroll" then
      -- Never expose void on either axis: the locked axis's range is a single
      -- point by construction above; the scrolling axis gets a real range.
      dx = offset(vw / 2 - sx, vw - r, -l)
      dy = offset(vh / 2 - sy, vh - b, -t)
    else
      dx = constrainX and offset(vw / 2 - sx, vw - r, -l) or vw / 2 - sx
      dy = constrainY and offset(vh / 2 - sy, vh - b, -t) or vh / 2 - sy
    end
    local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
    local horizon = angle > 0 and vh / 2 + dy - focal * vh / math.tan(angle) or -math.huge
    footprint = {}
    for i, p in ipairs({ { 0, math.max(0, horizon + 0.5) },
      { vw, math.max(0, horizon + 0.5) }, { vw, vh }, { 0, vh } }) do
      local x, y = T.inverse(p[1] - dx, p[2] - dy, vw, vh, angle, focal)
      x, y = cx + x / scale, cy + y / scale
      footprint[i] = { x, y }
      left, top, right, bottom = math.min(left, x), math.min(top, y),
        math.max(right, x), math.max(bottom, y)
    end
    ground = { x = left, y = top, w = right - left, h = bottom - top }
    local x, y = math.max(bounds.x, left - margin), math.max(bounds.y, top - margin)
    capture = { x = x, y = y, w = math.min(bounds.x + bounds.w, right + margin) - x,
      h = math.min(bounds.y + bounds.h, bottom + margin) - y }
  elseif mode == "partial" then
    local l, t, r, b = math.huge, math.huge, -math.huge, -math.huge
    footprint = {}
    for i, p in ipairs({ { 0, 0 }, { vw, 0 }, { vw, vh }, { 0, vh } }) do
      local x, y = T.inverse(p[1], p[2], vw, vh, angle, focal)
      footprint[i] = { x, y }
      l, t, r, b = math.min(l, x), math.min(t, y), math.max(r, x), math.max(b, y)
    end
    scale = math.max((referenceScale or fullScale) * zoom,
      (r - l) / bounds.w, (b - t) / bounds.h)
    if maxScale then scale = math.min(scale, maxScale) end
    local function clamp(n, low, high)
      -- An undersized axis has no containing position; center its footprint instead.
      if maxScale and low > high then return (low + high) / 2 end
      return math.max(low, math.min(high, n))
    end
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
    footprint = footprint, angle = angle, focal = focal, bounds = bounds, ground = ground }
  frame.constrainX, frame.constrainY = constrainX, constrainY
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
