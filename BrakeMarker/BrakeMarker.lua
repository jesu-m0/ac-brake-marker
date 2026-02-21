-- BrakeMarker.lua
-- Place visual braking reference markers on the track surface.
-- Markers render as a portico (gate) shape with a 3D label sign above.
---------------------------------------------------------------------
-- Config
---------------------------------------------------------------------
local MARKER_WIDTH       = 6     -- meters across the track
local MARKER_POST_WIDTH  = 0.3   -- meters, width of vertical posts
local MARKER_POST_HEIGHT = 2     -- meters, height of vertical posts
local MARKER_BAR_HEIGHT  = 0.3   -- meters, height of top/bottom bars
local MARKER_COLOR       = rgbm(1, 0, 0, 0.7)
local LABEL_SIGN_WIDTH   = 5     -- meters, width of the label sign
local LABEL_SIGN_HEIGHT  = 1.2   -- meters, height of the label sign
local LABEL_OFFSET_Y     = 0.3   -- meters gap above the top bar
local LABEL_BG_COLOR     = rgbm(0, 0, 0, 0.85)
local LABEL_TEXT_COLOR    = rgbm(1, 1, 1, 1)
local LABEL_FONT_SIZE    = 64
local CANVAS_W           = 512
local CANVAS_H           = 128
---------------------------------------------------------------------
-- Key binding setup
---------------------------------------------------------------------
local KEY_NAMES = {
  'A','B','C','D','E','F','G','H','I','J','K','L','M',
  'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
  '0','1','2','3','4','5','6','7','8','9',
}
local KEY_MAP = {}
for _, name in ipairs(KEY_NAMES) do
  KEY_MAP[name] = ui.KeyIndex[name]
end
local settings = ac.storage{
  keyPlace = 'B',
  keyDelete = 'X',
}
local function getKeyIndex(name)
  return KEY_MAP[name] or ui.KeyIndex.B
end
---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local sim = ac.getSim()
local car = ac.getCar(0)
local markers = {}
local editingIndex = nil
local editText = ''
local isEditing = false
local canvases = {}

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
      label = m.label,
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
      label = d.label or ('Marker ' .. i),
    }
  end
end

---------------------------------------------------------------------
-- Canvas management
---------------------------------------------------------------------
local function updateCanvas(index)
  local m = markers[index]
  if not m then return end
  local entry = canvases[index]
  if not entry then
    entry = { canvas = ui.ExtraCanvas(vec2(CANVAS_W, CANVAS_H)), label = '' }
    canvases[index] = entry
  end
  if entry.label == m.label then return end
  entry.label = m.label
  entry.canvas:clear(LABEL_BG_COLOR)
  entry.canvas:update(function(dt)
    ui.drawRectFilled(vec2(0, 0), vec2(CANVAS_W, CANVAS_H), LABEL_BG_COLOR)
    ui.drawRect(vec2(2, 2), vec2(CANVAS_W - 2, CANVAS_H - 2), rgbm(1, 0.3, 0.3, 0.9), 0, 0, 3)
    ui.pushFont(ui.Font.Main)
    ui.dwriteTextAligned(m.label, LABEL_FONT_SIZE, 0.5, 0.5,
      vec2(CANVAS_W, CANVAS_H), true, LABEL_TEXT_COLOR)
    ui.popFont()
  end)
end

local function rebuildAllCanvases()
  for _, entry in pairs(canvases) do
    if entry.canvas then entry.canvas:dispose() end
  end
  canvases = {}
  for i = 1, #markers do updateCanvas(i) end
end

---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
loadMarkers()
for i = 1, #markers do updateCanvas(i) end

---------------------------------------------------------------------
-- Marker actions
---------------------------------------------------------------------
local function placeMarker()
  local look = vec3(car.look.x, 0, car.look.z):normalize()
  local right = vec3.cross(look, vec3(0, 1, 0)):normalize()
  local newIndex = #markers + 1
  table.insert(markers, {
    pos   = car.position:clone(),
    right = right,
    label = 'Marker ' .. newIndex,
  })
  updateCanvas(newIndex)
  saveMarkers()
end
local function deleteMarker(index)
  if index >= 1 and index <= #markers then
    table.remove(markers, index)
    if editingIndex == index then editingIndex = nil; editText = ''
    elseif editingIndex and editingIndex > index then editingIndex = editingIndex - 1 end
    rebuildAllCanvases()
    saveMarkers()
  end
end
local function clearMarkers()
  markers = {}
  editingIndex = nil; editText = ''
  rebuildAllCanvases()
  saveMarkers()
end

---------------------------------------------------------------------
-- Input
---------------------------------------------------------------------
local prevPlace = false
local prevDelete = false
function script.update(dt)
  if isEditing then prevPlace = false; prevDelete = false; return end
  local place  = ac.isKeyDown(getKeyIndex(settings.keyPlace))
  local delete = ac.isKeyDown(getKeyIndex(settings.keyDelete))
  if place  and not prevPlace  then placeMarker() end
  if delete and not prevDelete then deleteMarker(#markers) end
  prevPlace  = place
  prevDelete = delete
end

---------------------------------------------------------------------
-- 3D rendering
---------------------------------------------------------------------
-- Shader flips UV so text reads correctly from the front
local labelShader = [[
  float4 main(PS_IN pin) {
    float2 uv = float2(pin.Tex.x, 1.0 - pin.Tex.y);
    return txLabel.Sample(samAnisotropic, uv);
  }
]]

local labelQuadParams = {
  async = true,
  textures = { txLabel = false },
  values = {},
  shader = labelShader,
}

function script.draw3D(dt)
  if #markers == 0 then return end
  local halfW = MARKER_WIDTH * 0.5
  local up    = vec3(0, 1, 0)

  for i, m in ipairs(markers) do
    local base  = m.pos + vec3(0, 0.05, 0)
    local right = m.right

    local leftBase   = base + right * (-halfW)
    local rightBase  = base + right * ( halfW)
    local leftTop    = leftBase  + up * MARKER_POST_HEIGHT
    local rightTop   = rightBase + up * MARKER_POST_HEIGHT

    -- Portico
    render.quad(leftBase, rightBase,
      rightBase + up * MARKER_BAR_HEIGHT, leftBase + up * MARKER_BAR_HEIGHT, MARKER_COLOR)
    render.quad(leftBase, leftBase + right * MARKER_POST_WIDTH,
      leftBase + right * MARKER_POST_WIDTH + up * MARKER_POST_HEIGHT, leftTop, MARKER_COLOR)
    render.quad(rightBase + right * (-MARKER_POST_WIDTH), rightBase,
      rightTop, rightBase + right * (-MARKER_POST_WIDTH) + up * MARKER_POST_HEIGHT, MARKER_COLOR)
    render.quad(leftTop + up * (-MARKER_BAR_HEIGHT), rightTop + up * (-MARKER_BAR_HEIGHT),
      rightTop, leftTop, MARKER_COLOR)

    -- Label sign
    local entry = canvases[i]
    if entry and entry.canvas then
      local signBase = base + up * (MARKER_POST_HEIGHT + LABEL_OFFSET_Y)
      local halfSignW = LABEL_SIGN_WIDTH * 0.5

      local p1 = signBase + right * (-halfSignW)
      local p2 = signBase + right * ( halfSignW)
      local p3 = signBase + right * ( halfSignW) + up * LABEL_SIGN_HEIGHT
      local p4 = signBase + right * (-halfSignW) + up * LABEL_SIGN_HEIGHT

      labelQuadParams.p1 = p1
      labelQuadParams.p2 = p2
      labelQuadParams.p3 = p3
      labelQuadParams.p4 = p4
      labelQuadParams.textures.txLabel = entry.canvas

      render.setBlendMode(render.BlendMode.AlphaBlend)
      render.setDepthMode(render.DepthMode.Normal)
      render.setCullMode(render.CullMode.None)
      render.shaderedQuad(labelQuadParams)
    end
  end
end

---------------------------------------------------------------------
-- ImGui window
---------------------------------------------------------------------
local function keyNameIndex(name)
  for i, k in ipairs(KEY_NAMES) do
    if k == name then return i - 1 end
  end
  return 1
end
local KEY_COMBO_STR = table.concat(KEY_NAMES, '\0') .. '\0'

function script.windowMain(dt)
  ui.text('Car: ' .. (ac.getCarID(0) or '?'))
  ui.text('Track: ' .. (ac.getTrackFullID('') or '?'))
  ui.separator()
  ui.text('Key bindings:')
  ui.pushItemWidth(50)
  local changed, newIdx
  changed, newIdx = ui.combo('Place##keyPlace', keyNameIndex(settings.keyPlace), KEY_COMBO_STR)
  if changed then settings.keyPlace = KEY_NAMES[newIdx + 1] end
  changed, newIdx = ui.combo('Delete last##keyDelete', keyNameIndex(settings.keyDelete), KEY_COMBO_STR)
  if changed then settings.keyDelete = KEY_NAMES[newIdx + 1] end
  ui.popItemWidth()
  ui.separator()
  ui.text('Markers: ' .. #markers)
  if ui.button('Place marker  [' .. settings.keyPlace .. ']', vec2(-0.1, 0)) then placeMarker() end
  if #markers > 0 then
    if ui.button('Clear all markers', vec2(-0.1, 0)) then clearMarkers() end
  end
  if #markers > 0 then
    ui.separator()
    local anyEditing = false
    local toDelete = nil
    for i, m in ipairs(markers) do
      if editingIndex == i then
        anyEditing = true
        ui.captureKeyboard()
        ui.pushItemWidth(-0.1)
        local newText, textChanged, enterPressed = ui.inputText('##label' .. i, editText)
        editText = newText
        ui.popItemWidth()
        if ui.button('Save##save' .. i, vec2(55, 0)) or enterPressed then
          m.label = editText; editingIndex = nil; editText = ''
          updateCanvas(i); saveMarkers()
        end
        ui.sameLine(0, 4)
        if ui.button('Cancel##cancel' .. i) then editingIndex = nil; editText = '' end
      else
        if ui.button('X##del' .. i, vec2(25, 0)) then toDelete = i end
        ui.sameLine(0, 4)
        ui.text(m.label)
        ui.sameLine(0, 8)
        if ui.button('Edit##edit' .. i, vec2(40, 0)) then editingIndex = i; editText = m.label end
      end
    end
    isEditing = anyEditing
    if toDelete then deleteMarker(toDelete) end
  else
    isEditing = false
  end
end