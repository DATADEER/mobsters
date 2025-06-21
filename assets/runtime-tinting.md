# Runtime Tinting Guide

## Overview
Create sprites in neutral colors, then use Godot's `modulate` property to tint them for different players at runtime.

## Aseprite Creation Guidelines
- Use **light gray or white** as the base color for areas that will be tinted
- Keep **black outlines/borders** - these won't be affected by tinting
- Use **mid-gray** for shadows/details that should be darker when tinted
- Avoid saturated colors in areas that need player colors

## Color Scheme
- Base sprite: Light gray (#C0C0C0) for main areas
- Borders: Black (#000000) for outlines
- Details: Mid-gray (#808080) for shadows

## Godot Implementation

### Basic Tinting
```gdscript
# Set player color
var player_color = Color.RED  # or BLUE, GREEN, etc.
sprite.modulate = player_color
```

### Player Color System
```gdscript
enum PlayerColor { RED, BLUE, GREEN, YELLOW }

var player_colors = {
    PlayerColor.RED: Color.RED,
    PlayerColor.BLUE: Color.BLUE, 
    PlayerColor.GREEN: Color.GREEN,
    PlayerColor.YELLOW: Color.YELLOW
}

func set_player_color(sprite: Sprite2D, player: PlayerColor):
    sprite.modulate = player_colors[player]
```

## Benefits
- Single sprite file per type
- Infinite color variations
- Easy to change colors
- Small file sizes