-- Run against an extracted runtime ZIP with the engine and tests.harness on LUA_PATH.
local root = assert(arg[1], "Pass the extracted mod directory")
local T = require("tests.harness").suite("Static Camera release metadata")
local Manifest = require("src.mods.Manifest")
local ModUpdate = require("src.mods.ModUpdate")
local Json = require("src.link.Json")
local GameVersion = require("src.core.GameVersion")

local function read(path)
  local file = assert(io.open(path, "rb"))
  local text = assert(file:read("*a"))
  file:close()
  return text
end

local m = Manifest.validate(assert(Json.decode(read(root .. "\\manifest.json"))), root)
T.eq(m.id, "static_camera", "existing mod ID is preserved")
T.eq(m.github, "ojsaucer/Advanced-Camera-Options", "launcher recognizes update repository")
T.eq(m.api, 2, "mod API remains unchanged")
T.eq(m.game_version, ">=0.3.19 <0.4.0", "engine compatibility is unchanged")
-- The manifest declares the "gen3" generation token, not individual game ids,
-- so it resolves to whichever Gen 3 games THIS engine knows (firered/leafgreen
-- on older engines, plus emerald once an engine adds it) without an "unknown
-- game" load error on engines that predate a newer Gen 3 addition.
local expectedGames = {}
for _, id in ipairs(GameVersion.ORDER) do
  if GameVersion.generation(id) == 3 then expectedGames[#expectedGames + 1] = id end
end
T.same(m.games, expectedGames, "declares every gen3 game this engine knows")
T.same(m.permissions, { "engine_internals" }, "no updater network permission added")
local card = assert(loadfile(root .. "\\mod.card"))()
T.eq(card.contact, "https://github.com/" .. m.github, "card links to the same project")
T.eq(card.credits[1].who, "Astra", "development disclosure is included in the card")

local tag = "v" .. m.version
local asset = m.id .. "-" .. m.version .. ".zip"
local url = "https://github.com/" .. m.github .. "/releases/download/" .. tag .. "/" .. asset
local fixture = Json.encode({
  { tag_name = tag, prerelease = false, assets = {
    { name = asset .. ".sha256", browser_download_url = url .. ".sha256" },
    { name = asset, browser_download_url = url },
  } },
})
local text = arg[2] and read(arg[2]) or fixture
local releases = assert(ModUpdate.parseReleases(text, m.id))
local best = assert(ModUpdate.pickBest(releases))
T.eq(best.tag, tag, "launcher selects this release")
T.eq(best.version, m.version, "release and packed versions agree")
T.eq(best.prerelease, false, "public release is stable")
T.eq(best.zip.name, asset, "launcher chooses the runtime ZIP")
T.eq(best.zip.url, url, "launcher chooses the intended download URL")
T.eq(ModUpdate.statusFor(m.version, releases), "current", "same version has no update")
T.eq(ModUpdate.statusFor("0.9.1", releases), "available", "older version sees an update")
T.eq(ModUpdate.statusFor("0.10.0", releases), "available", "previous release sees an update")
T.finish()
