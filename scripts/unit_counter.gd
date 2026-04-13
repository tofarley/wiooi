extends Node2D

# Unit types from the rulebook
enum UnitType { HOPLITE, HEAVY_INFANTRY, LIGHT_INFANTRY, LIGHT_HORSE }

# Generic factions - player1 (0) and player2 (1)
enum Faction { PLAYER1, PLAYER2 }

@export var unit_type: int = UnitType.HOPLITE
@export var faction: int = Faction.PLAYER1
@export var unit_name: String = "Unit"
@export var movement_points: int = 2
@export var attack: int = 3
@export var defense: int = 3
@export var wing_color: String = "Red"
@export var combat_class: String = "B"  # A+, A, B, C, D
@export var is_leader: bool = false
@export var is_brittle: bool = false

# Atlas grid constants
const CELL_W = 187
const CELL_H = 187

# Wing color -> atlas region mapping
# Each entry: {row_start, col_start, count} where row_start is the atlas row pair (front row)
# and col_start/count define which columns within that pair hold counters of this color
# Atlas rows come in pairs: even=front, odd=back
const WING_ATLAS_MAP = {
	"Red": [
		{"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 0, "col": 3}, {"row": 0, "col": 4},
		{"row": 0, "col": 5}, {"row": 0, "col": 6}, {"row": 0, "col": 7},
		{"row": 2, "col": 1}, {"row": 2, "col": 2}, {"row": 2, "col": 3},
		{"row": 2, "col": 5}, {"row": 2, "col": 6},
	],
	"Orange": [
		{"row": 4, "col": 3}, {"row": 4, "col": 4}, {"row": 4, "col": 5}, {"row": 4, "col": 7},
		{"row": 6, "col": 0}, {"row": 6, "col": 1}, {"row": 6, "col": 2}, {"row": 6, "col": 3},
	],
	"Purple": [
		{"row": 6, "col": 5}, {"row": 6, "col": 6}, {"row": 6, "col": 7},
		{"row": 8, "col": 0}, {"row": 8, "col": 1}, {"row": 8, "col": 2}, {"row": 8, "col": 3},
		{"row": 8, "col": 4}, {"row": 8, "col": 5}, {"row": 8, "col": 6}, {"row": 8, "col": 7},
	],
	"Yellow": [
		{"row": 10, "col": 0}, {"row": 10, "col": 1}, {"row": 10, "col": 2}, {"row": 10, "col": 3},
	],
	"Brown": [
		{"row": 10, "col": 4}, {"row": 10, "col": 5}, {"row": 10, "col": 6}, {"row": 10, "col": 7},
	],
	"Blue": [
		{"row": 0, "col": 8}, {"row": 0, "col": 9}, {"row": 0, "col": 14}, {"row": 0, "col": 15},
		{"row": 2, "col": 8}, {"row": 2, "col": 14},
		{"row": 4, "col": 8}, {"row": 4, "col": 9}, {"row": 4, "col": 10}, {"row": 4, "col": 11},
		{"row": 4, "col": 12}, {"row": 4, "col": 13}, {"row": 4, "col": 14}, {"row": 4, "col": 15},
		{"row": 6, "col": 8}, {"row": 6, "col": 9}, {"row": 6, "col": 10}, {"row": 6, "col": 11},
		{"row": 6, "col": 12}, {"row": 6, "col": 13}, {"row": 6, "col": 14}, {"row": 6, "col": 15},
	],
	"Green": [
		{"row": 8, "col": 8}, {"row": 8, "col": 10}, {"row": 8, "col": 11},
		{"row": 8, "col": 13}, {"row": 8, "col": 14}, {"row": 8, "col": 15},
	],
	"Pink": [
		{"row": 10, "col": 8}, {"row": 10, "col": 9}, {"row": 10, "col": 11},
		{"row": 10, "col": 12}, {"row": 10, "col": 13}, {"row": 10, "col": 14}, {"row": 10, "col": 15},
	],
}


# Combat Class per counter (indexed by wing_color and counter position)
const WING_CC_MAP = {
	"Red": ["A","A","A","A","B","B","B","B","B","B","B","B"],
	"Orange": ["B","B","B","B","B","B","B","A"],
	"Purple": ["A","A","A","C","C","B","B","B","B","B","B"],
	"Blue": ["C","C","B","B","B","B","B","B","B","B","B","B","B","B","A","B","B","B","B","B","B","A"],
	"Green": ["A","B","B","B","B","A"],
	"Pink": ["B","B","B","B","A","A","A"],
	"Yellow": ["A","B","B","B"],
	"Brown": ["B","A","A","B"],
}

# Fallback: map old faction-based access for legacy/fallback code
const LEGACY_FACTION_COL_BASE = {0: 0, 1: 8}

var grid_pos: Vector2i = Vector2i(0, 0)
var has_moved: bool = false
var is_selected: bool = false
var is_face_up: bool = true
var is_exhausted: bool = false
var move_points_left: int = 0

const COUNTER_SIZE = 96

func is_foot() -> bool:
	return unit_type != UnitType.LIGHT_HORSE

func is_horse() -> bool:
	return unit_type == UnitType.LIGHT_HORSE

func is_fresh() -> bool:
	return not is_exhausted

# Track which counter index within the wing this unit uses
var _atlas_col: int = 0
var _atlas_row: int = 0
var _counter_index: int = 0  # Set externally to pick the right counter from the wing

@onready var sprite: Sprite2D = $Sprite2D
@onready var selection_ring: ColorRect = $SelectionRing
@onready var moved_overlay: ColorRect = $MovedOverlay

func _ready() -> void:
	_setup_visuals()
	z_index = 1

func _setup_visuals() -> void:
	var half = COUNTER_SIZE / 2.0

	selection_ring.size = Vector2(COUNTER_SIZE + 8, COUNTER_SIZE + 8)
	selection_ring.position = Vector2(-half - 4, -half - 4)
	selection_ring.color = Color(1, 1, 0, 0.9)
	selection_ring.visible = false

	moved_overlay.size = Vector2(COUNTER_SIZE, COUNTER_SIZE)
	moved_overlay.position = Vector2(-half, -half)
	moved_overlay.color = Color(0.15, 0.15, 0.15, 0.55)
	moved_overlay.visible = false

	sprite.centered = true
	sprite.position = Vector2(0, 0)
	sprite.scale = Vector2(float(COUNTER_SIZE) / CELL_W, float(COUNTER_SIZE) / CELL_H)

	_resolve_atlas_position()
	_update_sprite()

func _resolve_atlas_position() -> void:
	if WING_ATLAS_MAP.has(wing_color):
		var cells = WING_ATLAS_MAP[wing_color]
		var idx = _counter_index % cells.size()
		_atlas_row = cells[idx]["row"]
		_atlas_col = cells[idx]["col"]
		# Set combat class from CC map
		if WING_CC_MAP.has(wing_color):
			var cc_list = WING_CC_MAP[wing_color]
			if idx < cc_list.size():
				combat_class = cc_list[idx]
		return
	_atlas_col = LEGACY_FACTION_COL_BASE.get(faction, 0)
	_atlas_row = 0

func _update_sprite() -> void:
	var base_tex = load("res://assets/counter_atlas.png")
	if not base_tex:
		return

	# Atlas rows come in pairs: even=front, odd=back
	var atlas_row = _atlas_row + (0 if is_face_up else 1)

	var region = Rect2(_atlas_col * CELL_W, atlas_row * CELL_H, CELL_W, CELL_H)
	var at = AtlasTexture.new()
	at.atlas = base_tex
	at.region = region
	sprite.texture = at

func set_selected(sel: bool) -> void:
	is_selected = sel
	selection_ring.visible = sel
	z_index = 10 if sel else 1

func set_moved(moved: bool) -> void:
	has_moved = moved
	moved_overlay.visible = moved

func reset_turn() -> void:
	set_moved(false)
	move_points_left = 0

func flip() -> void:
	is_face_up = !is_face_up
	_update_sprite()

func get_input_rect() -> Rect2:
	var half = COUNTER_SIZE / 2.0
	return Rect2(position.x - half, position.y - half, COUNTER_SIZE, COUNTER_SIZE)
