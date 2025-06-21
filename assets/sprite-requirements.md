# Sprite Requirements

## Individual Files (32x32 base grid)
- `tile_base.png` - Basic uncaptured tile
- `mobster.png` - Player character (24x24, bigger square)
- `henchman.png` - Unit sprite (16x16, small square)
- `tile_borders.png` - Adjacency highlights
- `fog_overlay.png` - Fog of war overlay
- `store_generic.png` - Basic business tile

## Purpose
Low pixel count, abstract pixel art for tile-based strategy game. Each tile 32x32, units fit within tiles, player colors distinguish ownership.

Note: Using individual files for faster iteration. Spritesheets can be added later for optimization.