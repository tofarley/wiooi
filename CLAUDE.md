# WITH IT OR ON IT - Digital Board Game Implementation

## Project Overview
Digital implementation of "With It Or On It" by Tom Russell, a counter wargame covering six famous hoplite battles from the Greco-Persian and Peloponnesian Wars. Part of the Shields & Swords Ancients series. Built in **Godot 4.6.2**.

## Source Material
- **Rulebook** (`WIOOI_RB.pdf`): 7 pages covering all game mechanics
- **Battle Book** (`WIOOI_BB.pdf`): 15 pages with historical context + 6 battle setups + player aid card (back page has CRT and UTMM)

## Game Basics
- **Square grid** (26 cols x 20 rows), NOT hexes
- **Adjacency is orthogonal only** (never diagonal) unless specified
- Two players alternate turns, each activating ONE wing per turn
- **8-sided die** (d8) for all rolls
- Units have a **Fresh** (front) and **Exhausted** (back) side
- Units are double-sided counters with hidden information (leaders, brittle units)

## Unit Types
- Hoplite (HO) = 0, Foot, orthogonal movement with facing
- Heavy Infantry (HI) = 1, Foot, orthogonal with facing
- Light Infantry (LI) = 2, Foot, orthogonal with facing
- Light Horse (LH) = 3, Horse, all 8 directions

## Sequence of Play (Section 4.0)
Each Player Turn:
1. **Command Phase** - Play 2 commands for one wing (auto-opens at turn start)
2. **Action Phases** (fixed execution order: Skirmish > Rally > Move > Combat)
3. **Victory Phase** - NON-ACTING player checks victory
4. **Initiative Phase** - Acting player may Declare Initiative for double turn
5. Switch to other player, repeat

## Command System (Section 5.0)
Three double-sided command markers:
- **Move / Combat** (opposite sides of marker 1)
- **Skirmish / Rally** (opposite sides of marker 2)
- **Strategos / Bonus** (opposite sides of marker 3)

Play 2 commands from different markers. Commands auto-sorted into fixed execution order.
- **Strategos + X**: X command applies to ALL wings (costs 1 Rally Limit)
- **Bonus + Move**: Extra move phase (2 squares, forward only)
- **Bonus + Combat**: -1 to combat die rolls
- **Bonus + Rally**: +1 to rally attempts
- **Bonus + Skirmish**: Two skirmish phases

## Movement Rules (Section 8.0)
- **First action phase**: 4 squares. **Second action phase**: 2 squares
- Only **Fresh** units move; Exhausted units stay
- **Foot**: orthogonal only, face forward (toward enemy edge), cannot move backward
- **Foot cannot move forward** if no enemy units exist between them and enemy edge
- **Horse**: all 8 directions
- **Engagement**: Opposing foot units adjacent AND facing = Engaged, cannot move
- **Bonus Move**: 2 squares, forward only
- Per-unit move_points_left tracking allows split cluster movement

## Combat Rules (Section 9.0) - BASIC IMPLEMENTATION
- Primary Attacker + optional Support units from same wing
- Support: fresh units adjacent to Primary OR Defender
- Hoplites can "borrow" higher CC through chain of fresh hoplites (BFS)
- CC modifiers: +1 vs Exhausted, +1 Flanking, -1 if wing half gone (not HO)
- DRM from Unit Type Modifier Matrix (UTMM), minus support count, minus bonus
- CRT cross-reference: modified roll vs CC -> DE/DX/AX/EX/AA
- NOT YET: Exhaustion allocation choice, proper Rout Check triggers

## Project Structure
```
res://
├── main.tscn                    # Main game scene (map + units)
├── project.godot                # Main scene = battle_select.tscn
├── assets/
│   ├── map.png                  # 3300x2550 game board
│   ├── counter_atlas.png        # 2992x2244 (16x12 cells at 187px) - unit counters
│   ├── counters_front.png       # 3263x2513 (17x13) - full sheet inc. command markers
│   └── counters_back.png        # 3263x2513 - backs
├── scenes/
│   ├── battle_select.tscn       # Battle selection screen (main scene)
│   ├── unit_counter.tscn        # Unit counter prefab
│   ├── command_phase_ui.tscn    # Command selection panel
│   └── combat_phase_ui.tscn     # Combat resolution panel
└── scripts/
    ├── main.gd                  # Game logic, deployment, movement, input, turn flow
    ├── grid_manager.gd          # Grid geometry (26x20), pixel coords, cell occupancy
    ├── unit_counter.gd          # Unit display, atlas mapping, state
    ├── battle_data.gd           # All 6 battle configs (class_name BattleData)
    ├── battle_select.gd         # Battle selection UI
    ├── command_phase_ui.gd      # Command selection panel
    ├── combat_phase_ui.gd       # Combat resolution UI
    └── combat_resolver.gd       # CRT + UTMM tables (class_name CombatResolver)
```

## Counter Atlas Layout
- Atlas (counter_atlas.png): 16 cols x 12 rows at 187px per cell
- Rows come in pairs: even = front, odd = back
- Left half (cols 0-7): warm colors (Red, Orange, Purple, Yellow, Brown)
- Right half (cols 8-15): cool colors (Blue, Green, Pink)
- WING_ATLAS_MAP in unit_counter.gd has exact valid cell lists per wing color
- WING_CC_MAP maps combat class per counter index per wing color
- Command markers are in row 12 of counters_front.png (NOT in atlas)

## Grid Geometry (grid_manager.gd)
- V_LINES: 27 values from 187 to 3112 (column boundaries)
- H_LINES: 21 values from 151 to 2401 (row boundaries)
- Center dotted line at x=1650 (col 13)
- Forward direction: edge 1 player -> +1 (down), edge 2 player -> -1 (up)

## Rally Limit Tracks
- Left track (Edge 1): x=82, y={0:259, 1:371, 2:484, 3:596, 4:709}
- Right track (Edge 2): x=3220, y={4:1842, 3:1955, 2:2067, 1:2180, 0:2293}

## CC Classification (NEEDS REFINEMENT)
CC letter (A, B, C) is in top-right corner of each counter front face.
Pixel analysis approach - fragile due to different wing background colors.
Current WING_CC_MAP likely has misclassifications. User should verify.

## Known Issues
- Split cluster movement bug: occasionally second cluster can't move (battle-specific?)
- CC classification needs manual verification against physical counters
- Wing color names don't match visual appearance (e.g. "Purple" looks pinkish)
- Canceling command phase leaves player stuck (need re-open mechanism)
- edit_file and execute_editor_script string replacements are unreliable - ALWAYS verify with read-back

## What's NOT Yet Implemented
- Skirmish Phase (zones, ranged attacks, skirmish factor)
- Rally Phase (d8 roll + modifiers, flip exhausted to fresh)
- Rout Checks (adjacency check after combat eliminations)
- Victory Phase (VP counting, win condition checking)
- Exhaustion allocation choice in combat
- Leaders (revealed leader mechanic, rally limit reduction)
- Brittle Units (immediate elimination on exhaustion)
- Special Rules per battle

## Window/Camera
- Window: 1728x972, camera zoom 0.36 centered at (1650, 1275)
- Faction: PLAYER1=0 (edge 1, top), PLAYER2=1 (edge 2, bottom)
