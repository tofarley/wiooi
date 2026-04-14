# WITH IT OR ON IT - Digital Board Game Implementation

## Project Overview
Digital implementation of "With It Or On It" by Tom Russell, a counter wargame covering six famous hoplite battles from the Greco-Persian and Peloponnesian Wars. Part of the Shields & Swords Ancients series. Built in **Godot 4.6.2**.

## Source Material
- **Rulebook** (WIOOI_RB.pdf): 7 pages covering all game mechanics
- **Battle Book** (WIOOI_BB.pdf): 15 pages with 6 battle setups + player aid card (CRT/UTMM on back)

## Game Basics
- Square grid (26 cols x 20 rows), orthogonal adjacency only
- Two players alternate turns, each activating ONE wing per turn
- d8 for all rolls
- Units: Fresh (front) / Exhausted (back), double-sided with hidden info

## Unit Types
- Hoplite (HO) = 0, Foot | Heavy Infantry (HI) = 1, Foot
- Light Infantry (LI) = 2, Foot | Light Horse (LH) = 3, Horse
- Foot: orthogonal only, facing rules | Horse: all 8 directions

## Sequence of Play
1. Command Phase (auto-opens at turn start)
2. Action Phases (fixed order: Skirmish > Rally > Move > Combat)
3. Victory Phase (NOT YET - opponent checks victory)
4. Initiative Phase (declare for double turn or decline)

## Command System - ALL IMPLEMENTED
- Move/Combat (marker 1), Skirmish/Rally (marker 2), Strategos/Bonus (marker 3)
- Play 2 from different markers, auto-sorted to fixed execution order
- **Bonus** modifies paired command (enhanced effect)
- **Strategos** applies paired command to ALL wings (costs 1 Rally Limit)

## All Action Phases - IMPLEMENTED
- **Move**: 4 squares (1st action) or 2 (2nd action), wing/cluster selection, arrow keys, undo
- **Bonus Move**: 2 additional squares forward-only after normal move
- **Combat**: Primary + Support, CC borrowing for hoplites, UTMM + CRT, d8 roll
- **Rally**: d8 + modifiers, target 8+, natural 1 = eliminated (no rout), owner chooses units
- **Skirmish**: d8 + Skirmish Factor, target 8+, zone tracking, owner chooses exhaustion targets
- **Strategos**: Loops through all wings for the paired command, decrements Rally Limit

## Initiative Phase - IMPLEMENTED
- Dialog: Declare (pass marker, take double turn) or Decline
- UI shows who holds initiative with star indicator

## Project Structure
```
res://
├── main.tscn, project.godot (main scene = battle_select.tscn)
├── assets/ (map.png 3300x2550, counter_atlas.png 16x12@187px, counters_front/back.png 17x13)
├── scenes/ (battle_select, unit_counter, command_phase_ui, combat_phase_ui, rally_phase_ui)
└── scripts/
    ├── main.gd              # Game logic, deployment, all phases, turn flow
    ├── grid_manager.gd      # Grid geometry (26x20), cell occupancy
    ├── unit_counter.gd      # Unit display, atlas mapping, CC, state
    ├── battle_data.gd       # 6 battles + TEST scenario (class_name BattleData)
    ├── battle_select.gd     # Battle selection UI
    ├── command_phase_ui.gd  # Command selection (right panel)
    ├── combat_phase_ui.gd   # Combat resolution (right panel)
    ├── combat_resolver.gd   # CRT + UTMM tables (class_name CombatResolver)
    └── rally_phase_ui.gd    # Rally resolution (right panel)
```

## Counter Atlas
- 16 cols x 12 rows @ 187px per cell, even rows = front, odd = back
- Left half (0-7): warm (Red, Orange, Purple, Yellow, Brown)
- Right half (8-15): cool (Blue, Green, Pink)
- WING_ATLAS_MAP + WING_CC_MAP in unit_counter.gd
- Command markers in row 12 of counters_front.png (not in atlas)

## Grid Geometry
- V_LINES: 187-3112, H_LINES: 151-2401, center line at x=1650 (col 13)
- Forward: edge 1 -> +1 (down), edge 2 -> -1 (up)

## Rally Limit Tracks
- Left (Edge 1): x=82, y={0:259,1:371,2:484,3:596,4:709}
- Right (Edge 2): x=3220, y={4:1842,3:1955,2:2067,1:2180,0:2293}

## Movement Details
- Per-unit move_points_left tracking for split cluster movement
- Flood-fill cluster selection, click to toggle units in/out
- Arrow keys move group, Z undo, Enter/Space or Done button to finish
- Engagement: foot vs foot facing = locked, horse vs horse orthogonal = locked
- Foot can't move backward, can't advance forward without enemies ahead
- Bonus move: 2 squares forward-only, call_deferred to prevent Enter double-fire

## Combat Details
- Select Primary -> Select Defender -> Preview -> Roll d8 -> Apply Result
- CC borrowing via BFS through fresh hoplite chain
- CC mods: +1 vs exhausted, +1 flanking, -1 half wing gone (not HO)
- Results: DE/DX/AX/EX/AA with proper exhaustion/elimination
- Multiple attacks per phase, each unit participates once, each defender targeted once
- Click attacker/defender to cancel selection and re-choose
- Roll button signal properly reconnects between attacks

## Skirmish Details
- Zone tracking per wing (skirmish_zones_intact dictionary)
- Foot zones: 3 squares forward, disappear on enemy foot contact
- Horse zones: 2 squares all directions, never disappear
- d8 + Skirmish Factor, target 8+, in-zone = 2 hits, out = 1 hit
- Owner chooses which units to exhaust (right-side allocation panel)
- Bonus+Skirmish: two rolls against same target
- Zone contact checked after every wing movement

## Known Issues
- CC classification from atlas needs manual verification (A/B detected, C uncertain)
- Brittle and Leader detection from counter backs not implemented
- Split cluster movement bug occasionally (battle-specific?)
- Cancel command phase leaves player stuck
- edit_file and execute_editor_script string replacements unreliable - always verify

## NOT YET IMPLEMENTED
- Rout Checks (adjacency check after combat eliminations)
- Victory Phase (VP counting, win conditions)
- Exhaustion allocation choice in combat (defender pushing to adjacent)
- Leaders (revealed on flip, rally limit reduction on death)
- Brittle units (immediate elimination on exhaustion)
- Skirmish zone entry stopping movement (8.2)
- Special rules per battle
- Multiplayer networking

## Window/Camera
- Window: 1728x972, camera zoom 0.36, center (1650, 1275)
- Faction: PLAYER1=0 (edge 1, top), PLAYER2=1 (edge 2, bottom)

## TEST Battle
- "TEST - Contact" scenario: 5 units per side, directly adjacent (row 9 vs row 10)
- For quick testing of combat and rally without movement
