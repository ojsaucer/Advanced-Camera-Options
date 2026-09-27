return function(ctx)
  local T, native, settings = ctx.T, ctx.native, ctx.settings
  local lg = love.graphics
  local Player = require("src.core.game3.player")
  local oldX, oldY = Player.px, Player.py
  local oldImage, oldQuad = native.image, native.testQuad
  local oldLayered, oldOverImage, oldOverQuad = native.layered, native.overImage, native.testOverQuad
  local oldMode, oldZoom, oldStyle = settings.mode, settings.zoom, settings.zoom_style
  local pixels = love.image.newImageData(1024, 1024)
  pixels:mapPixel(function(x, y)
    if x >= 16 and x < 32 and y >= 16 and y < 32 then return 0, 1, 0, 1 end
    return 1, 0, 1, 1
  end)
  local image = lg.newImage(pixels)
  image:setFilter("nearest", "nearest")
  local quad = lg.newQuad(16, 16, 16, 16, 1024, 1024)
  local overPixels = love.image.newImageData(1024, 1024)
  overPixels:mapPixel(function(x, y)
    if x >= 16 and x < 32 and y >= 16 and y < 32 then return 0, 0, 0, 0 end
    return 0, 1, 1, 1
  end)
  local overImage = lg.newImage(overPixels)
  overImage:setFilter("nearest", "nearest")
  native.image, native.testQuad = image, quad
  native.layered, native.overImage, native.testOverQuad = true, overImage, quad
  settings.zoom_style = "consistent"
  local totalFrames = 0
  local function checkView(mode, view)
    local badFrames, firstBad, frames = 0, nil, 0
    for _, zoom in ipairs({ 55, 65, 75, 85, 95 }) do
      settings.zoom = zoom
      for step = 0, 15 do
        Player.px, Player.py = 260 + step * 0.5, 200 + step * 0.5
        local output = ctx.capture(view[1], view[2], view[3], view[4])
        local bad = false
        local function check(x, y)
          local r, green, blue = output:getPixel(x, y)
          if blue > 0.99 and (r > 0.99 or green > 0.99) then
            bad = true
            firstBad = firstBad or string.format("zoom=%s step=%s pixel=%s,%s rgb=%.3f,%.3f,%.3f",
              zoom, step, x, y, r, green, blue)
          end
        end
        -- Cross every horizontal and vertical seam; stay below the UI marker.
        for x = 180, 1359, 131 do
          for y = 160, 767 do check(x, y) end
        end
        for y = 160, 767, 137 do
          for x = 0, 1359 do check(x, y) end
        end
        if bad then badFrames = badFrames + 1 end
        frames = frames + 1
        output:release()
      end
    end
    totalFrames = totalFrames + frames
    T.eq(badFrames, 0, "GPU: moving " .. mode .. " " .. view[1] .. " DPI=" .. view[2]
      .. " ground/overhead atlas has no seams in " .. frames
      .. " frames" .. (firstBad and " (" .. firstBad .. ")" or ""))
  end
  for _, mode in ipairs({ "normal", "full", "partial" }) do
    settings.mode = mode
    for _, view in ipairs({ { "screen", 1, 1360, 768 }, { "screen", 2, 680, 384 },
      { "retro", 1, 1360, 768 } }) do checkView(mode, view) end
  end
  T.eq(totalFrames, 720, "all moving ground/overhead atlas cases were executed")
  settings.mode, settings.zoom, settings.zoom_style = oldMode, oldZoom, oldStyle
  native.image, native.testQuad = oldImage, oldQuad
  native.layered, native.overImage, native.testOverQuad = oldLayered, oldOverImage, oldOverQuad
  Player.px, Player.py = oldX, oldY
  ctx.capture("screen", 1, 720, 480):release()
  pixels:release()
  overPixels:release()
  image:release()
  overImage:release()
  quad:release()
end
