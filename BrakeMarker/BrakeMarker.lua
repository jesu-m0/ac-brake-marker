-- BrakeMarker.lua
-- Place visual braking reference markers on the track surface.
-- Markers render as a portico (gate) shape with a label floating above.
---------------------------------------------------------------------
-- Config
---------------------------------------------------------------------
local MARKER_WIDTH       = 6     -- meters across the track
local MARKER_POST_WIDTH  = 0.3   -- meters, width of vertical posts
local MARKER_POST_HEIGHT = 2     -- meters, height of vertical posts
local MARKER_BAR_HEIGHT  = 0.3   -- meters, height of top/bottom bars
local MARKER_COLOR       = rgbm(1, 0, 0, 0.7)
local LABEL_COLOR        = rgbm(1, 1, 1, 1)
local LABEL_SCALE        = 2
local LABEL_OFFSET_Y     = 0.6   -- meters above the top bar
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
local editingIndex = nil  -- which marker label is being edited
local editText = ''       -- text buffer for editing
local isEditing = false   -- true while a text field has focus
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
loadMarkers()
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
  saveMarkers()
end
local function deleteMarker(index)
  if index >= 1 and index <= #markers then
    table.remove(markers, index)
    if editingIndex == index then
      editingIndex = nil
      editText = ''
    elseif editingIndex and editingIndex > index then
      editingIndex = editingIndex - 1
    end
    saveMarkers()
  end
end
local function clearMarkers()
  markers = {}
  editingIndex = nil
  editText = ''
  saveMarkers()
end
---------------------------------------------------------------------
-- Input (runs every frame)
-- Hotkeys are DISABLED while editing a label
---------------------------------------------------------------------
local prevPlace = false
local prevDelete = false
function script.update(dt)
  if isEditing then
    -- Don't process hotkeys while typing
    prevPlace = false
    prevDelete = false
    return
  end
  local place  = ac.isKeyDown(getKeyIndex(settings.keyPlace))
  local delete = ac.isKeyDown(getKeyIndex(settings.keyDelete))
  if place  and not prevPlace  then placeMarker() end
  if delete and not prevDelete then deleteMarker(#markers) end
  prevPlace  = place
  prevDelete = delete
end
---------------------------------------------------------------------
-- 3D rendering — portico + floating label
---------------------------------------------------------------------
function script.draw3D(dt)
  if #markers == 0 then return end

  local halfW = MARKER_WIDTH * 0.5
  local up    = vec3(0, 1, 0)

  for _, m in ipairs(markers) do
    local base  = m.pos + vec3(0, 0.05, 0)
    local right = m.right

    local leftBase   = base + right * (-halfW)
    local rightBase  = base + right * ( halfW)
    local leftTop    = leftBase  + up * MARKER_POST_HEIGHT
    local rightTop   = rightBase + up * MARKER_POST_HEIGHT

    -- Bottom bar
    render.quad(
      leftBase,
      rightBase,
      rightBase + up * MARKER_BAR_HEIGHT,
      leftBase  + up * MARKER_BAR_HEIGHT,
      MARKER_COLOR
    )
    -- Left post
    render.quad(
      leftBase,
      leftBase + right * MARKER_POST_WIDTH,
      leftBase + right * MARKER_POST_WIDTH + up * MARKER_POST_HEIGHT,
      leftTop,
      MARKER_COLOR
    )
    -- Right post
    render.quad(
      rightBase + right * (-MARKER_POST_WIDTH),
      rightBase,
      rightTop,
      rightBase + right * (-MARKER_POST_WIDTH) + up * MARKER_POST_HEIGHT,
      MARKER_COLOR
    )
    -- Top bar
    render.quad(
      leftTop  + up * (-MARKER_BAR_HEIGHT),
      rightTop + up * (-MARKER_BAR_HEIGHT),
      rightTop,
      leftTop,
      MARKER_COLOR
    )

    -- Label above the portico
    local labelPos = base + up * (MARKER_POST_HEIGHT + LABEL_OFFSET_Y)
    render.debugText(labelPos, m.label, LABEL_COLOR, LABEL_SCALE)
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
  local carId   = ac.getCarID(0) or '?'
  local trackId = ac.getTrackFullID('') or '?'
  ui.text('Car: ' .. carId)
  ui.text('Track: ' .. trackId)
  ui.separator()

  -- Key bindings
  ui.text('Key bindings:')
  ui.pushItemWidth(50)
  local changed, newIdx
  changed, newIdx = ui.combo('Place##keyPlace', keyNameIndex(settings.keyPlace), KEY_COMBO_STR)
  if changed then settings.keyPlace = KEY_NAMES[newIdx + 1] end
  changed, newIdx = ui.combo('Delete last##keyDelete', keyNameIndex(settings.keyDelete), KEY_COMBO_STR)
  if changed then settings.keyDelete = KEY_NAMES[newIdx + 1] end
  ui.popItemWidth()
  ui.separator()

  -- Place button
  ui.text('Markers: ' .. #markers)
  if ui.button('Place marker  [' .. settings.keyPlace .. ']', vec2(-0.1, 0)) then
    placeMarker()
  end

  -- Clear all — button only, no hotkey
  if #markers > 0 then
    if ui.button('Clear all markers', vec2(-0.1, 0)) then
      clearMarkers()
    end
  end

  -- Marker list with labels and edit/delete
  if #markers > 0 then
    ui.separator()
    -- Track if any text field is active this frame
    local anyEditing = false
    local toDelete = nil

    for i, m in ipairs(markers) do
      if editingIndex == i then
        -- Editing mode
        anyEditing = true
        -- Capture keyboard so hotkeys and game controls don't fire
        ui.captureKeyboard()

        ui.pushItemWidth(-0.1)
        local newText, textChanged, enterPressed = ui.inputText('##label' .. i, editText)
        editText = newText
        ui.popItemWidth()

        if ui.button('Save##save' .. i, vec2(55, 0)) or enterPressed then
          m.label = editText
          editingIndex = nil
          editText = ''
          saveMarkers()
        end
        ui.sameLine(0, 4)
        if ui.button('Cancel##cancel' .. i) then
          editingIndex = nil
          editText = ''
        end
      else
        -- Display mode
        if ui.button('X##del' .. i, vec2(25, 0)) then
          toDelete = i
        end
        ui.sameLine(0, 4)
        ui.text(m.label)
        ui.sameLine(0, 8)
        if ui.button('Edit##edit' .. i, vec2(40, 0)) then
          editingIndex = i
          editText = m.label
        end
      end
    end

    isEditing = anyEditing

    if toDelete then
      deleteMarker(toDelete)
    end
  else
    isEditing = false
  end
end