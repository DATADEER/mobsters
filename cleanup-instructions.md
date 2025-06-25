# Cleanup Instructions

This file documents exceptions and guidelines for code cleanup to avoid removing important files.

## Files to NEVER remove during cleanup:

### Documentation Files
- `quality-of-life-improvements.md` - Contains relevant improvement ideas
- `game-idea/` folder and all its contents - Ground truth for game design
- `CLAUDE.md` - Project instructions

### Asset Source Files
- All `.aseprite` files in `assets/` - Source files for sprites, keep for future editing

## General Cleanup Guidelines
- Remove debug print statements unless they provide essential game feedback
- Remove unused variables and constants
- Remove legacy compatibility code that's no longer needed
- Remove duplicate functionality
