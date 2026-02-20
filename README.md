# BrakeMarker

A CSP Lua app for Assetto Corsa that lets you place custom braking reference markers on the track by pressing a button. Red lines are painted across the track surface so you can see them from a distance as you approach.

## Requirements

- [Assetto Corsa](https://store.steampowered.com/app/244210/Assetto_Corsa/)
- [Custom Shaders Patch (CSP)](https://acstuff.ru/patch/) installed

## Installation

1. Copy the `BrakeMarker/` folder into your Assetto Corsa Lua apps directory:

   ```
   <Assetto Corsa>/apps/lua/BrakeMarker/
   ```

   Typical Steam path:
   ```
   C:\Program Files (x86)\Steam\steamapps\common\assettocorsa\apps\lua\BrakeMarker\
   ```

2. Launch Assetto Corsa, go to **Settings > General > UI Modules** and enable **Brake Marker**.

3. In a session, open the app from the sidebar to see the control panel.

## Usage

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| **B** | Place a marker at your current position |
| **X** | Remove the most recently placed marker |
| **C** | Clear all markers |

### App window

The in-game window shows the current car, track, and marker count. It also has clickable buttons as an alternative to the keyboard shortcuts.

### Persistence

Markers are saved automatically per car + track combination. They will reload the next time you drive the same car on the same track.

## How it works

When you press **B**, the app captures your car's position and heading. It calculates a perpendicular vector and draws a thin red semi-transparent quad flat on the track surface — like a spray-painted line crossing the road at 90 degrees to your driving direction.

## Configuration

You can tweak these constants at the top of [BrakeMarker.lua](BrakeMarker/BrakeMarker.lua):

| Constant | Default | Description |
|----------|---------|-------------|
| `MARKER_WIDTH` | `8` | Width of the line across the track (meters) |
| `MARKER_THICKNESS` | `0.15` | Thickness of the line along the road (meters) |
| `MARKER_HEIGHT` | `0.05` | Height above the track surface (meters) |
| `MARKER_COLOR` | `rgbm(1, 0, 0, 0.7)` | Color and opacity (red, 70% opaque) |
| `KEY_PLACE` | `B` | Key to place a marker |
| `KEY_UNDO` | `X` | Key to undo the last marker |
| `KEY_CLEAR` | `C` | Key to clear all markers |

## License

[MIT](LICENSE)
