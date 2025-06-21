# Sprite Requirements

## Individual Files (32x32 base grid)
- `hq_base.png` - Player headquarters/starting base
- `tile_empty.png` - Empty tiles mixed in grid (not capturable)
- `store_generic.png` - Business tiles that can be captured
- `mobster.png` - Player character (24x24, bigger square)
- `henchman.png` - Unit sprite (16x16, small square)
- `tile_borders.png` - Adjacency highlights
- `fog_overlay.png` - Fog of war overlay

## Runtime Tinting Guidelines
- Create sprites in **light gray (#C0C0C0)** for areas that need player colors
- Use **black (#000000)** for outlines/borders
- Use **mid-gray (#808080)** for shadows/details
- Player colors applied via `sprite.modulate` in Godot

## Purpose
Low pixel count, abstract pixel art for tile-based strategy game. Each tile 32x32, units fit within tiles, player colors distinguish ownership.

Note: Using individual files for faster iteration. Spritesheets can be added later for optimization.