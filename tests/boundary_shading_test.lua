return function(ctx)
  local T, lg = ctx.T, love.graphics
  local S = assert(loadfile(ctx.root .. "\\boundary_shading.lua"))()
  local originalDraw, newShader, setShader, getShader = lg.draw, lg.newShader, lg.setShader, lg.getShader
  local active, shader, warnings = nil, { send = function() end, release = function() end }, 0
  local base, over, actor = {}, {}, {}
  local field = { _nativeBatches = { base }, _nativeOverBatches = { over } }
  local seen = {}
  lg.newShader = function() return shader end
  lg.getShader = function() return active end
  lg.setShader = function(value) active = value end
  lg.draw = function(image) seen[image] = active or "none" end
  local draw = lg.draw
  local shading = S.new(function() warnings = warnings + 1 end)
  local ok, err = xpcall(function()
    shading.draw(field, -10, -10, 640, 480, "gradient", 0.6, 128, function()
      lg.draw(base, 0, 0); lg.draw(actor, 0, 0); lg.draw(over, 0, 0)
    end)
    T.eq(seen[base], shader, "neighbor tint applies to terrain batch")
    T.eq(seen[over], shader, "neighbor tint applies to overhead terrain")
    T.eq(seen[actor], "none", "neighbor tint leaves character draw unchanged")
    T.eq(lg.draw, draw, "neighbor tint restores graphics draw")
    T.eq(active, nil, "neighbor tint restores previous shader")
    T.raises(function()
      shading.draw(field, 0, 0, 640, 480, "uniform", 1, 128, function()
        error("injected shaded field error")
      end)
    end, "injected", "shaded drawing errors propagate")
    T.eq(lg.draw, draw, "neighbor tint restores draw after field error")
    shading.dispose()
    lg.newShader = function() error("injected shader failure") end
    shading.draw(field, 0, 0, 640, 480, "uniform", 1, 128, function() lg.draw(base) end)
    T.eq(warnings, 1, "shader failure is reported")
    T.eq(seen[base], "none", "shader failure preserves original terrain")
    local frame = { x = 0, y = 0, dx = 0, dy = 0, scale = 1 }
    shading.backdrop(frame, 720, 480, 640, 480, "uniform", 1, 128)
    T.eq(warnings, 2, "backdrop shader failure is reported independently")
    shading.backdrop(frame, 720, 480, 640, 480, "gradient", 1, 128)
    T.eq(warnings, 2, "backdrop shader failure is latched until disposal")
  end, debug.traceback)
  shading.dispose()
  lg.draw, lg.newShader, lg.setShader, lg.getShader = originalDraw, newShader, setShader, getShader
  if not ok then error(err, 0) end
end
