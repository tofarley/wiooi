extends Node

# Exact grid geometry extracted by pixel-scanning map.png
# NOTE: The center vertical line is a dark dotted line (not white) at x=1650 - included manually
const V_LINES = [187, 300, 412, 525, 637, 750, 862, 975, 1087, 1200, 1312, 1425, 1537, 1650, 1762, 1875, 1987, 2100, 2212, 2325, 2437, 2550, 2663, 2775, 2888, 3000, 3112]
const H_LINES = [151, 264, 376, 489, 601, 714, 826, 939, 1051, 1164, 1276, 1389, 1502, 1614, 1726, 1839, 1952, 2064, 2177, 2289, 2401]

# Cell centers (midpoint between adjacent lines)
const COL_CENTERS = [243, 356, 468, 581, 693, 806, 918, 1031, 1143, 1256, 1368, 1481, 1593, 1706, 1818, 1931, 2043, 2156, 2268, 2381, 2493, 2606, 2719, 2831, 2944, 3056]
const ROW_CENTERS = [207, 320, 432, 545, 657, 770, 882, 995, 1107, 1220, 1332, 1445, 1558, 1670, 1782, 1895, 2008, 2120, 2233, 2345]

const COLS = 26
const ROWS = 20
const CELL_SIZE = 112  # nominal size for highlight rectangles

var occupied_cells: Dictionary = {}

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	if grid_pos.x < 0 or grid_pos.x >= COLS or grid_pos.y < 0 or grid_pos.y >= ROWS:
		return Vector2(-9999, -9999)
	return Vector2(COL_CENTERS[grid_pos.x], ROW_CENTERS[grid_pos.y])

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var col = -1
	for i in range(V_LINES.size() - 1):
		if world_pos.x >= V_LINES[i] and world_pos.x < V_LINES[i + 1]:
			col = i
			break
	var row = -1
	for i in range(H_LINES.size() - 1):
		if world_pos.y >= H_LINES[i] and world_pos.y < H_LINES[i + 1]:
			row = i
			break
	return Vector2i(col, row)

func snap_to_grid(world_pos: Vector2) -> Vector2:
	return grid_to_world(world_to_grid(world_pos))

func is_cell_occupied(grid_pos: Vector2i) -> bool:
	return occupied_cells.has(grid_pos)

func get_unit_at(grid_pos: Vector2i) -> Node:
	return occupied_cells.get(grid_pos, null)

func occupy_cell(grid_pos: Vector2i, unit: Node) -> void:
	occupied_cells[grid_pos] = unit

func free_cell(grid_pos: Vector2i) -> void:
	occupied_cells.erase(grid_pos)

func is_valid_cell(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < COLS and grid_pos.y >= 0 and grid_pos.y < ROWS

func get_cell_width(col: int) -> int:
	if col < 0 or col >= COLS:
		return CELL_SIZE
	return V_LINES[col + 1] - V_LINES[col]

func get_cell_height(row: int) -> int:
	if row < 0 or row >= ROWS:
		return CELL_SIZE
	return H_LINES[row + 1] - H_LINES[row]
