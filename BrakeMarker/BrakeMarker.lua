-- BrakeMarker.lua
-- Place visual braking reference markers on the track surface.
-- Markers render as a portico (gate) shape visible from a distance.

---------------------------------------------------------------------
-- Config
---------------------------------------------------------------------
local MARKER_WIDTH       = 8     -- meters across the track
local MARKER_THICKNESS   = 0.3   -- meters, thickness of bars/posts
local MARKER_POST_HEIGHT = 3     -- meters, height of vertical posts
local MARKER_COLOR       = rgbm(1, 0, 0, 0.7)

---------------------------------------------------------------------
-- Key binding setup
---------------------------------------------------------------------
-- Available keys for the user to choose from
local KEY_NAMES = {
  'A','B','C','D','E','F','G','H','I','J','K','L','M',
  'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
  '0','1','2','3','4','5','6','7','8','9',
}

-- Map key name string -> ui.KeyIndex value
local KEY_MAP = {}
for _, name in ipairs(KEY_NAMES) do
  KEY_MAP[name] = ui.KeyIndex[name]
end

-- Persistent settings (keybindings stored as strings)
local settings = ac.storage{
  keyPlace = 'B',
  keyDelete = 'X',
  keyClear = 'C',
}

-- Resolve current key indices from settings
local function getKeyIndex(name)
  return KEY_MAP[name] or ui.KeyIndex.B
end

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local sim = ac.getSim()
local car = ac.getCar(0)

-- Each marker stores: { pos = vec3, right = vec3 }
local markers = {}

---------------------------------------------------------------------
-- Persistence helpers
---------------------------------------------------------------------
local function storageKey()
  local carId   = ac.getCarID(0) or 'car'
  local trackId = ac.getTrackFullID('') or 'track'
  return 'markers_' .. carId .. '_' .. trackId
end

local function saveMarkers()
  local data = {}
  for i, m in ipairs(markers) do
    data[i] = {
      px = m.pos.x, py = m.pos.y, pz = m.pos.z,
      rx = m.right.x, ry = m.right.y, rz = m.right.z,
    }
  end
  ac.storage[storageKey()] = stringify(data, true)
end

local function loadMarkers()
  local raw = ac.storage[storageKey()]
  if not raw or raw == '' then return end
  local data = stringify.tryParse(raw, nil)
  if not data then return end
  markers = {}
  for i, d in ipairs(data) do
    markers[i] = {
      pos   = vec3(d.px, d.py, d.pz),
      right = vec3(d.rx, d.ry, d.rz),
    }
  end
end

loadMarkers()

---------------------------------------------------------------------
-- Marker actions
---------------------------------------------------------------------
local function placeMarker()
  local look = vec3(car.look.x, 0, car.look.z):normalize()
  local right = vec3.cross(look, vec3(0, 1, 0)):normalize()
  table.insert(markers, {
    pos   = car.position:clone(),
    right = right,
  })
  saveMarkers()
end

local function deleteMarker(index)
  if index >= 1 and index <= #markers then
    table.remove(markers, index)
    saveMarkers()
  end
end

local function clearMarkers()
  markers = {}
  saveMarkers()
end

---------------------------------------------------------------------
-- Input (runs every frame)
---------------------------------------------------------------------
local prevPlace = false
local prevDelete = false
local prevClear = false

function script.update(dt)
  local place  = ac.isKeyDown(getKeyIndex(settings.keyPlace))
  local delete = ac.isKeyDown(getKeyIndex(settings.keyDelete))
  local clear  = ac.isKeyDown(getKeyIndex(settings.keyClear))

  if place  and not prevPlace  then placeMarker() end
  if delete and not prevDelete then deleteMarker(#markers) end
  if clear  and not prevClear  then clearMarkers() end

  prevPlace  = place
  prevDelete = delete
  prevClear  = clear
end

---------------------------------------------------------------------
-- 3D rendering — portico (gate) shape
---------------------------------------------------------------------
local markerShader = [[
  float4 main(PS_IN pin) {
    return gColor;
  }
]]

local function drawQuad(p1, p2, p3, p4)
  render.shaderedQuad({
    p1 = p1, p2 = p2, p3 = p3, p4 = p4,
    async = true,
    blendMode = render.BlendMode.AlphaBlend,
    depthMode = render.DepthMode.ReadOnly,
    cullMode  = render.CullMode.None,
    values    = { gColor = MARKER_COLOR },
    shader    = markerShader,
  })
end

function script.draw3D()
  if #markers == 0 then return end

  local halfW = MARKER_WIDTH * 0.5
  local halfT = MARKER_THICKNESS * 0.5
  local up    = vec3(0, 1, 0)

  for _, m in ipairs(markers) do
    local pos   = m.pos
    local right = m.right
    local fwd   = vec3.cross(up, right):normalize()

    -- Base positions at ground level (slightly above track)
    local groundY = vec3(0, 0.02, 0)
    local leftBottom  = pos + right * (-halfW) + groundY
    local rightBottom = pos + right * ( halfW) + groundY
    local leftTop     = leftBottom  + up * MARKER_POST_HEIGHT
    local rightTop    = rightBottom + up * MARKER_POST_HEIGHT

    -- 1. Ground bar (flat on track, full width)
    drawQuad(
      leftBottom  + fwd * (-halfT),
      rightBottom + fwd * (-halfT),
      rightBottom + fwd * ( halfT),
      leftBottom  + fwd * ( halfT)
    )

    -- 2. Left post (vertical, at left end)
    drawQuad(
      leftBottom + fwd * (-halfT),
      leftBottom + fwd * ( halfT),
      leftTop    + fwd * ( halfT),
      leftTop    + fwd * (-halfT)
    )

    -- 3. Right post (vertical, at right end)
    drawQuad(
      rightBottom + fwd * (-halfT),
      rightBottom + fwd * ( halfT),
      rightTop    + fwd * ( halfT),
      rightTop    + fwd * (-halfT)
    )

    -- 4. Top bar (horizontal, at post height, full width)
    drawQuad(
      leftTop  + fwd * (-halfT),
      rightTop + fwd * (-halfT),
      rightTop + fwd * ( halfT),
      leftTop  + fwd * ( halfT)
    )
  end
end

---------------------------------------------------------------------
-- ImGui window
---------------------------------------------------------------------
-- Helper: find index of a value in KEY_NAMES
local function keyNameIndex(name)
  for i, k in ipairs(KEY_NAMES) do
    if k == name then return i - 1 end  -- 0-based for ui.combo
  end
  return 1  -- default to 'B'
end

-- Build a single string with all key names for ui.combo
local KEY_COMBO_STR = table.concat(KEY_NAMES, '\0') .. '\0'

function script.windowMain(dt)
  local carId   = ac.getCarID(0) or '?'
  local trackId = ac.getTrackFullID('') or '?'

  ui.text('Car: ' .. carId)
  ui.text('Track: ' .. trackId)
  ui.separator()

  -- Keybinding config
  ui.text('Key bindings:')

  local changed, newIdx

  ui.pushItemWidth(60)

  ui.text('Place:')
  ui.sameLine(80)
  changed, newIdx = ui.combo('##keyPlace', keyNameIndex(settings.keyPlace), KEY_COMBO_STR)
  if changed then settings.keyPlace = KEY_NAMES[newIdx + 1] end

  ui.text('Delete:')
  ui.sameLine(80)
  changed, newIdx = ui.combo('##keyDelete', keyNameIndex(settings.keyDelete), KEY_COMBO_STR)
  if changed then settings.keyDelete = KEY_NAMES[newIdx + 1] end

  ui.text('Clear:')
  ui.sameLine(80)
  changed, newIdx = ui.combo('##keyClear', keyNameIndex(settings.keyClear), KEY_COMBO_STR)
  if changed then settings.keyClear = KEY_NAMES[newIdx + 1] end

  ui.popItemWidth()
  ui.separator()

  -- Place & clear buttons
  ui.text('Markers: ' .. #markers)
  if ui.button('Place marker  [' .. settings.keyPlace .. ']', vec2(-0.1, 0)) then
    placeMarker()
  end
  if ui.button('Clear all     [' .. settings.keyClear .. ']', vec2(-0.1, 0)) then
    clearMarkers()
  end
  ui.separator()

  -- Marker list with individual delete buttons
  if #markers > 0 then
    ui.text('Click to delete:')
    local toDelete = nil
    for i = 1, #markers do
      if ui.button('X##del' .. i) then
        toDelete = i
      end
      ui.sameLine(0, 8)
      ui.text('Marker ' .. i)
    end
    if toDelete then
      deleteMarker(toDelete)
    end
  end
end
