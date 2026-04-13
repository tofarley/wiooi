extends Node2D

const GridManager = preload("res://scripts/grid_manager.gd")
const CELL_SIZE = 112

var current_player_index: int = 0
var turn_number: int = 1
var battle_config: BattleData.BattleConfig = null

var grid: GridManager
var selected_unit: Node2D = null
var all_units: Array = []

var is_panning: bool = false
var pan_start: Vector2 = Vector2.ZERO
var camera_start: Vector2 = Vector2.ZERO

@onready var camera: Camera2D = $Camera2D
@onready var map_sprite: Sprite2D = $MapSprite
@onready var units_layer: Node2D = $UnitsLayer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var turn_label: Label = $UILayer/TurnLabel
@onready var phase_label: Label = $UILayer/PhaseLabel
@onready var end_turn_button: Button = $UILayer/EndTurnButton
@onready var highlight_layer: Node2D = $HighlightLayer

var initiative_label: Label = null

var move_highlights: Array = []
var unit_counter_scene = preload("res://scenes/unit_counter.tscn")
var command_phase_scene = preload("res://scenes/command_phase_ui.tscn")
var combat_phase_scene = preload("res://scenes/combat_phase_ui.tscn")
var combat_ui: Control = null
var command_ui: Control = null

# Active command state
var active_wing_color: String = ""
var active_commands: Array = []
var current_action_index: int = 0
var is_in_move_phase: bool = false
var is_bonus_move: bool = false
var move_points_remaining: int = 0
var wing_move_mode: bool = false  # true = moving whole wing, false = individual
var move_history: Array = []  # Array of snapshots for undo

# Fixed action phase execution order per rulebook section 4.0
const ACTION_ORDER = ["Skirmish", "Rally", "Move", "Combat"]

# Initiative: 0 = player1 holds it, 1 = player2 holds it
var initiative_holder: int = 0
var used_initiative_this_turn: bool = false

var player1_name: String = "Player 1"
var player2_name: String = "Player 2"

# Rally Limit Track positions (pixel coordinates on the map)
# Left track (Edge 1 player): numbers 0-4 from top to bottom
# Right track (Edge 2 player): numbers 4-0 from top to bottom
const RALLY_TRACK_LEFT_X = 82
const RALLY_TRACK_RIGHT_X = 3220
# Y positions for each number value on each track
const RALLY_TRACK_EDGE1_Y = {0: 259, 1: 371, 2: 484, 3: 596, 4: 709}
const RALLY_TRACK_EDGE2_Y = {4: 1842, 3: 1955, 2: 2067, 1: 2180, 0: 2293}

var rally_marker_p1: Node2D = null
var rally_marker_p2: Node2D = null

func _ready() -> void:
	grid = GridManager.new()
	add_child(grid)
	_setup_map()
	_setup_ui()
	if get_tree().has_meta("selected_battle"):
		battle_config = get_tree().get_meta("selected_battle")
		player1_name = battle_config.player1.player_name
		player2_name = battle_config.player2.player_name
		_spawn_battle_units()
		_place_rally_markers()
		if battle_config.player2.first_turn:
			current_player_index = 1
		else:
			current_player_index = 0
		# Set initial initiative holder
		if battle_config.player1.has_initiative:
			initiative_holder = 0
		else:
			initiative_holder = 1
	else:
		player1_name = "Greek"
		player2_name = "Persian"
		_spawn_fallback_units()
	_update_ui()
	_open_command_phase()

func _setup_map() -> void:
	var texture = load("res://assets/map.png")
	map_sprite.texture = texture
	map_sprite.centered = false
	map_sprite.position = Vector2(0, 0)
	camera.position = Vector2(1650, 1275)
	camera.zoom = Vector2(0.36, 0.36)

func _setup_ui() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	var panel_bg = ColorRect.new()
	panel_bg.color = Color(0.08, 0.08, 0.12, 0.80)
	panel_bg.size = Vector2(200, 270)
	panel_bg.position = Vector2(10, 10)
	ui_layer.add_child(panel_bg)
	ui_layer.move_child(panel_bg, 0)
	turn_label.add_theme_font_size_override("font_size", 14)
	turn_label.add_theme_color_override("font_color", Color(1, 1, 1))
	phase_label.add_theme_font_size_override("font_size", 15)
	end_turn_button.add_theme_font_size_override("font_size", 14)
	initiative_label = Label.new()
	initiative_label.position = Vector2(20, 70)
	# Move the scene's EndTurnButton down to make room
	end_turn_button.position = Vector2(20, 92)
	initiative_label.add_theme_font_size_override("font_size", 13)
	initiative_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	initiative_label.text = "Initiative: ---"
	initiative_label.z_index = 100
	ui_layer.add_child(initiative_label)
	var back_btn = Button.new()
	back_btn.text = "Back to Menu"
	back_btn.position = Vector2(20, 116)
	back_btn.add_theme_font_size_override("font_size", 12)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle_select.tscn"))
	ui_layer.add_child(back_btn)
	var info = Label.new()
	info.text = "LClick: Select/Move\nRClick: Flip | RDrag: Pan\nScroll: Zoom\nArrows: Move wing\nZ: Undo | Enter: Done\nEsc: Cancel"
	info.position = Vector2(20, 148)
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	ui_layer.add_child(info)

# =================== BATTLE SETUP ===================

func _spawn_battle_units() -> void:
	_deploy_player(battle_config.player1, 0)
	_deploy_player(battle_config.player2, 1)

func _deploy_player(player: BattleData.PlayerSetup, faction: int) -> void:
	var center_col = 13
	var wing_infos = []
	for wing in player.wings:
		var total = 0
		for u in wing.units:
			total += u["count"]
		var depth_val = wing.depth + 1
		var cols_per_row = ceili(float(total) / float(depth_val))
		wing_infos.append({"total": total, "depth": depth_val, "cols": cols_per_row})

	var start_cols = []
	for i in range(player.wings.size()):
		var wing = player.wings[i]
		var cols_needed = wing_infos[i]["cols"]
		var sc = _calc_start_col(wing, cols_needed, center_col, player.wings, start_cols, wing_infos)
		sc = clampi(sc, 0, grid.COLS - cols_needed)
		start_cols.append(sc)

	for i in range(player.wings.size()):
		var wing = player.wings[i]
		if wing.off_map:
			continue
		var edge_dist = wing.edge_distance
		var front_row: int
		if player.edge == 1:
			front_row = edge_dist - 1
		else:
			front_row = grid.ROWS - edge_dist
		var cols_per_row = wing_infos[i]["cols"]
		var num_rows = wing_infos[i]["depth"]
		var sc = start_cols[i]
		var unit_list = []
		for u in wing.units:
			for j in range(u["count"]):
				unit_list.append({"type": u["type"], "is_leader": j < u["leaders"]})
		var unit_idx = 0
		for r in range(num_rows):
			var row: int
			if player.edge == 1:
				row = front_row + r
			else:
				row = front_row - r
			for c in range(cols_per_row):
				if unit_idx >= unit_list.size():
					break
				var col = sc + c
				if col < 0 or col >= grid.COLS or row < 0 or row >= grid.ROWS:
					unit_idx += 1
					continue
				var u = unit_list[unit_idx]
				var type_abbr = ["HO", "HI", "LI", "LH"][u["type"]]
				var dname = wing.color_name + " " + type_abbr + " " + str(unit_idx + 1)
				if u["is_leader"]:
					dname += " *"
				_spawn_unit(dname, faction, col, row, u["type"], 2, 3, 3, wing.color_name, unit_idx)
				unit_idx += 1

func _calc_start_col(wing: BattleData.WingSetup, cols_needed: int, center_col: int, all_wings: Array, prev_cols: Array, prev_infos: Array) -> int:
	match wing.placement:
		BattleData.HPlacement.CENTER:
			return center_col - cols_needed / 2
		BattleData.HPlacement.LEFT_OF_WING, BattleData.HPlacement.LEFT_OF_CENTER:
			var ref_idx = _find_wing_idx(all_wings, wing.placement_ref)
			if ref_idx >= 0 and ref_idx < prev_cols.size():
				return prev_cols[ref_idx] - cols_needed
			return center_col - cols_needed - 4
		BattleData.HPlacement.RIGHT_OF_WING, BattleData.HPlacement.RIGHT_OF_CENTER:
			var ref_idx = _find_wing_idx(all_wings, wing.placement_ref)
			if ref_idx >= 0 and ref_idx < prev_cols.size():
				return prev_cols[ref_idx] + prev_infos[ref_idx]["cols"]
			return center_col + 4
		BattleData.HPlacement.CUSTOM:
			return _custom_col(wing, cols_needed, center_col)
		_:
			return center_col - cols_needed / 2

func _find_wing_idx(wings: Array, wname: String) -> int:
	for i in range(wings.size()):
		if wings[i].wing_name == wname:
			return i
	return -1

func _custom_col(wing: BattleData.WingSetup, cols_needed: int, center_col: int) -> int:
	var n = wing.special_notes.to_lower()
	if "right of dotted line" in n or "right side of the dotted line" in n:
		if "4 squares" in n:
			return center_col + 4
		return center_col + 1
	elif "left of dotted line" in n or "left of the dotted line" in n:
		if "4 squares" in n:
			return center_col - 4 - cols_needed
		return center_col - cols_needed
	elif "left of left wing" in n:
		return 0
	elif "right of right wing" in n:
		return grid.COLS - cols_needed
	return center_col - cols_needed / 2

func _spawn_unit(uname: String, faction: int, col: int, row: int, utype: int, move: int, atk: int, def_val: int, wcolor: String = "Red", counter_idx: int = 0) -> void:
	var unit = unit_counter_scene.instantiate()
	units_layer.add_child(unit)
	unit.unit_name = uname
	unit.faction = faction
	unit.unit_type = utype
	unit.movement_points = move
	unit.attack = atk
	unit.defense = def_val
	unit.wing_color = wcolor
	unit._counter_index = counter_idx
	unit._setup_visuals()
	var gpos = Vector2i(col, row)
	if grid.is_cell_occupied(gpos):
		for off in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1)]:
			var alt = gpos + off
			if grid.is_valid_cell(alt) and not grid.is_cell_occupied(alt):
				gpos = alt
				break
	unit.grid_pos = gpos
	unit.position = grid.grid_to_world(gpos)
	grid.occupy_cell(gpos, unit)
	all_units.append(unit)

func _spawn_fallback_units() -> void:
	_spawn_unit("Hoplite I", 0, 1, 0, 0, 2, 3, 3, "Red", 0)
	_spawn_unit("Hoplite II", 0, 3, 0, 0, 2, 3, 3, "Red", 1)
	_spawn_unit("Hoplite III", 0, 5, 0, 0, 2, 3, 3, "Red", 2)
	_spawn_unit("Immortal I", 1, 1, 19, 0, 2, 3, 3, "Blue", 0)
	_spawn_unit("Immortal II", 1, 3, 19, 0, 2, 3, 3, "Blue", 1)
	_spawn_unit("Immortal III", 1, 5, 19, 0, 2, 3, 3, "Blue", 2)

# =================== RALLY LIMIT MARKERS ===================

func _place_rally_markers() -> void:
	if not battle_config:
		return
	rally_marker_p1 = _create_rally_marker(battle_config.player1)
	rally_marker_p2 = _create_rally_marker(battle_config.player2)

func _create_rally_marker(player: BattleData.PlayerSetup) -> Node2D:
	var marker = Node2D.new()
	units_layer.add_child(marker)
	
	var bg = ColorRect.new()
	bg.size = Vector2(80, 80)
	bg.position = Vector2(-40, -40)
	if player.edge == 1:
		bg.color = Color(0.3, 0.5, 0.8, 0.85)
	else:
		bg.color = Color(0.8, 0.4, 0.15, 0.85)
	marker.add_child(bg)
	
	var border = ColorRect.new()
	border.size = Vector2(84, 84)
	border.position = Vector2(-42, -42)
	border.color = Color(0.2, 0.15, 0.1, 0.9)
	marker.add_child(border)
	marker.move_child(border, 0)
	
	var label = Label.new()
	label.text = "RL"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(80, 80)
	label.position = Vector2(-40, -40)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	marker.add_child(label)
	
	# Position on the correct track
	var x: float
	var y_map: Dictionary
	if player.edge == 1:
		x = RALLY_TRACK_LEFT_X
		y_map = RALLY_TRACK_EDGE1_Y
	else:
		x = RALLY_TRACK_RIGHT_X
		y_map = RALLY_TRACK_EDGE2_Y
	
	var limit = clampi(player.rally_limit, 0, 4)
	var y = y_map.get(limit, y_map.get(0, 207))
	marker.position = Vector2(x, y)
	marker.z_index = 5
	
	return marker

func _update_rally_marker(marker: Node2D, edge: int, new_limit: int) -> void:
	if not marker:
		return
	var y_map: Dictionary
	var x: float
	if edge == 1:
		x = RALLY_TRACK_LEFT_X
		y_map = RALLY_TRACK_EDGE1_Y
	else:
		x = RALLY_TRACK_RIGHT_X
		y_map = RALLY_TRACK_EDGE2_Y
	var limit = clampi(new_limit, 0, 4)
	marker.position = Vector2(x, y_map.get(limit, y_map.get(0, 207)))

# =================== COMBAT PHASE ===================

func _enter_combat_phase() -> void:
	var is_bonus = "Bonus" in active_commands and "Combat" in active_commands
	combat_ui = combat_phase_scene.instantiate()
	ui_layer.add_child(combat_ui)
	combat_ui.setup(self, all_units, grid, active_wing_color, current_player_index, is_bonus)
	combat_ui.combat_phase_done.connect(_on_combat_done)
	phase_label.text += " - COMBAT %s" % active_wing_color

func _on_combat_done() -> void:
	if combat_ui:
		combat_ui.queue_free()
		combat_ui = null
	current_action_index += 1
	_begin_next_action()

# =================== INITIATIVE PHASE ===================

func _initiative_phase() -> void:
	if initiative_holder == current_player_index and not used_initiative_this_turn:
		# This player holds initiative - ask if they want to declare it
		_show_initiative_dialog()
	else:
		# Don't hold initiative or already used it - pass to opponent
		_switch_to_next_player()

func _show_initiative_dialog() -> void:
	var dialog = PanelContainer.new()
	dialog.name = "InitiativeDialog"
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.custom_minimum_size = Vector2(400, 200)
	dialog.offset_left = -200
	dialog.offset_top = -100
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.14)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.7, 0.5, 0.15)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	dialog.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	dialog.add_child(vbox)
	
	var title = Label.new()
	title.text = "INITIATIVE PHASE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 0.20))
	vbox.add_child(title)
	
	var current_name = player1_name if current_player_index == 0 else player2_name
	var desc = Label.new()
	desc.text = "%s holds Initiative.\nDeclare Initiative to take a second turn?\n(Initiative marker passes to opponent)" % current_name
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	vbox.add_child(desc)
	
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)
	
	var decline_btn = Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(120, 40)
	decline_btn.add_theme_font_size_override("font_size", 16)
	decline_btn.pressed.connect(func():
		dialog.queue_free()
		_switch_to_next_player()
	)
	buttons.add_child(decline_btn)
	
	var declare_btn = Button.new()
	declare_btn.text = "Declare!"
	declare_btn.custom_minimum_size = Vector2(120, 40)
	declare_btn.add_theme_font_size_override("font_size", 16)
	var ds = StyleBoxFlat.new()
	ds.bg_color = Color(0.55, 0.35, 0.08)
	ds.corner_radius_top_left = 6
	ds.corner_radius_top_right = 6
	ds.corner_radius_bottom_left = 6
	ds.corner_radius_bottom_right = 6
	ds.content_margin_left = 12
	ds.content_margin_right = 12
	ds.content_margin_top = 8
	ds.content_margin_bottom = 8
	declare_btn.add_theme_stylebox_override("normal", ds)
	declare_btn.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	declare_btn.pressed.connect(func():
		dialog.queue_free()
		_declare_initiative()
	)
	buttons.add_child(declare_btn)
	
	ui_layer.add_child(dialog)

func _declare_initiative() -> void:
	# Pass initiative marker to opponent
	if initiative_holder == 0:
		initiative_holder = 1
	else:
		initiative_holder = 0
	used_initiative_this_turn = true
	# Take another full turn (same player, new command phase)
	_update_ui()
	_open_command_phase()

func _switch_to_next_player() -> void:
	used_initiative_this_turn = false
	if current_player_index == 0:
		current_player_index = 1
	else:
		current_player_index = 0
		turn_number += 1
	_update_ui()
	_open_command_phase()

# =================== COMMAND PHASE ===================

func _open_command_phase() -> void:
	if not battle_config:
		return
	var player = battle_config.player1 if current_player_index == 0 else battle_config.player2
	var wings = []
	for w in player.wings:
		if not w.off_map:
			wings.append({"name": w.wing_name + " (" + w.color_name + ")", "color_name": w.color_name})
	
	command_ui = command_phase_scene.instantiate()
	ui_layer.add_child(command_ui)
	command_ui.setup(wings, player.player_name)
	command_ui.commands_selected.connect(_on_commands_confirmed)
	command_ui.cancelled.connect(_on_commands_cancelled)

func _on_commands_confirmed(wing_index: int, cmd1: String, cmd2: String) -> void:
	var player = battle_config.player1 if current_player_index == 0 else battle_config.player2
	var visible_wings = []
	for w in player.wings:
		if not w.off_map:
			visible_wings.append(w)
	if wing_index < visible_wings.size():
		active_wing_color = visible_wings[wing_index].color_name
	# Sort commands into fixed execution order: Skirmish > Rally > Move > Combat
	var cmds = [cmd1, cmd2]
	# Strategos and Bonus are special - they modify the other command
	var sorted_cmds = []
	var special = ""
	for c in cmds:
		if c == "Strategos" or c == "Bonus":
			special = c
		else:
			sorted_cmds.append(c)
	# Sort the regular commands by ACTION_ORDER
	sorted_cmds.sort_custom(func(a, b): return ACTION_ORDER.find(a) < ACTION_ORDER.find(b))
	# Re-add special command at the end (it modifies, doesn't have its own phase)
	if special != "":
		sorted_cmds.append(special)
	active_commands = sorted_cmds
	current_action_index = 0
	is_bonus_move = false
	if command_ui:
		command_ui.queue_free()
		command_ui = null
	_begin_next_action()

func _begin_next_action() -> void:
	if current_action_index >= active_commands.size():
		_end_action_phases()
		return
	var cmd = active_commands[current_action_index]
	if cmd == "Move":
		_enter_move_phase(false)
	elif cmd == "Combat":
		_enter_combat_phase()
	elif cmd == "Bonus":
		current_action_index += 1
		_begin_next_action()
	else:
		current_action_index += 1
		_begin_next_action()

func _enter_move_phase(bonus: bool) -> void:
	is_in_move_phase = true
	is_bonus_move = bonus
	move_history.clear()
	var mp = _get_move_points()
	move_points_remaining = mp
	wing_move_mode = false
	for u in all_units:
		if u.faction == current_player_index and u.wing_color == active_wing_color:
			u.set_moved(false)
			u.move_points_left = mp
	_update_ui()
	var suffix = " (Bonus)" if bonus else ""
	phase_label.text += " - MOVE %s%s" % [active_wing_color, suffix]

func _end_move_phase() -> void:
	is_in_move_phase = false
	_clear_highlights()
	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null
	if not is_bonus_move and "Bonus" in active_commands and "Move" in active_commands:
		is_bonus_move = true
		_enter_move_phase(true)
		return
	current_action_index += 1
	_begin_next_action()

func _end_action_phases() -> void:
	active_wing_color = ""
	active_commands.clear()
	current_action_index = 0
	is_in_move_phase = false
	is_bonus_move = false
	for u in all_units:
		if u.faction == current_player_index:
			u.set_moved(false)
	# TODO: Victory Phase check here
	# Initiative Phase
	_initiative_phase()

func _on_commands_cancelled() -> void:
	if command_ui:
		command_ui.queue_free()
		command_ui = null

# =================== INPUT ===================

func _input(event: InputEvent) -> void:
	# Keyboard input
	if event is InputEventKey and event.pressed:
		if (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER) and is_in_move_phase:
			_exit_wing_move_mode()
			_end_move_phase()
			return
		if event.keycode == KEY_ESCAPE and wing_move_mode:
			_exit_wing_move_mode()
			return
		if event.keycode == KEY_Z and wing_move_mode:
			_undo_last_move()
			return
		if wing_move_mode:
			match event.keycode:
				KEY_UP:
					_move_wing_direction(0, -1)
					return
				KEY_DOWN:
					_move_wing_direction(0, 1)
					return
				KEY_LEFT:
					_move_wing_direction(-1, 0)
					return
				KEY_RIGHT:
					_move_wing_direction(1, 0)
					return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var world_pos = get_global_mouse_position()
				var clicked_grid = grid.world_to_grid(world_pos)
				var unit_at = grid.get_unit_at(clicked_grid)
				if unit_at != null:
					unit_at.flip()
				else:
					is_panning = true
					pan_start = event.position
					camera_start = camera.position
			else:
				is_panning = false
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.2, 0.2), Vector2(2.0, 2.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom * 0.9).clamp(Vector2(0.2, 0.2), Vector2(2.0, 2.0))
	elif event is InputEventMouseMotion and is_panning:
		camera.position = camera_start - (event.position - pan_start) / camera.zoom

func _handle_left_click(world_pos: Vector2) -> void:
	var clicked_grid = grid.world_to_grid(world_pos)
	# Route to combat UI if active
	if combat_ui:
		combat_ui.handle_click(clicked_grid)
		return
	if not is_in_move_phase:
		return
	var unit_at = grid.get_unit_at(clicked_grid)
	# Wing move mode: click units to toggle them in/out of the group
	if wing_move_mode:
		if unit_at and unit_at.faction == current_player_index and unit_at.wing_color == active_wing_color and unit_at.is_fresh():
			unit_at.set_selected(not unit_at.is_selected)
		return
	# Individual mode: move a selected unit to highlighted cell
	if selected_unit != null:
		if _is_highlighted_cell(clicked_grid):
			_move_unit(selected_unit, clicked_grid)
			_clear_highlights()
			selected_unit.set_selected(false)
			selected_unit = null
			return
		_clear_highlights()
		selected_unit.set_selected(false)
		selected_unit = null
	# Click on a wing unit to enter wing move mode
	if unit_at == null or unit_at.is_exhausted:
		return
	if unit_at.faction != current_player_index or unit_at.wing_color != active_wing_color:
		return
	if unit_at.move_points_left <= 0:
		return
	_enter_wing_move_mode(unit_at)

func _get_cluster(start_unit: Node2D) -> Array:
	# Flood-fill to find all orthogonally adjacent fresh wing units
	var cluster = []
	var visited = {}
	var queue = [start_unit.grid_pos]
	visited[start_unit.grid_pos] = true
	while queue.size() > 0:
		var pos = queue.pop_front()
		var u = grid.get_unit_at(pos)
		if u and u.faction == current_player_index and u.wing_color == active_wing_color and u.is_fresh():
			cluster.append(u)
			for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var adj = pos + off
				if not visited.has(adj) and grid.is_valid_cell(adj):
					visited[adj] = true
					queue.append(adj)
	return cluster

func _enter_wing_move_mode(clicked_unit: Node2D = null) -> void:
	wing_move_mode = true
	_clear_highlights()
	# Deselect all first
	for u in all_units:
		u.set_selected(false)
	# Select only the cluster connected to the clicked unit
	if clicked_unit:
		var cluster = _get_cluster(clicked_unit)
		for u in cluster:
			if u.move_points_left > 0 and not u.is_exhausted:
				u.set_selected(true)
	else:
		# Fallback: select all fresh wing units
		for u in all_units:
			if u.faction == current_player_index and u.wing_color == active_wing_color and u.is_fresh() and u.move_points_left > 0:
				u.set_selected(true)
	_update_ui()

func _exit_wing_move_mode() -> void:
	wing_move_mode = false
	for u in all_units:
		u.set_selected(false)
	_clear_highlights()

func _get_wing_units() -> Array:
	# Returns only the selected (active group) units
	var units = []
	for u in all_units:
		if u.faction == current_player_index and u.wing_color == active_wing_color and u.is_selected and u.is_fresh():
			units.append(u)
	return units

func _save_move_snapshot() -> void:
	var snapshot = []
	for u in all_units:
		if u.faction == current_player_index and u.wing_color == active_wing_color:
			snapshot.append({"unit": u, "pos": u.grid_pos, "selected": u.is_selected, "mp": u.move_points_left})
	move_history.append({"positions": snapshot, "mp": move_points_remaining})

func _undo_last_move() -> void:
	if move_history.is_empty():
		return
	var snapshot = move_history.pop_back()
	# Restore positions
	for entry in snapshot["positions"]:
		var u = entry["unit"]
		grid.free_cell(u.grid_pos)
	for entry in snapshot["positions"]:
		var u = entry["unit"]
		u.grid_pos = entry["pos"]
		u.position = grid.grid_to_world(entry["pos"])
		grid.occupy_cell(entry["pos"], u)
		u.set_selected(entry["selected"])
		u.move_points_left = entry["mp"]
	move_points_remaining = snapshot["mp"]
	_update_ui()

func _move_wing_direction(dx: int, dy: int) -> void:
	if not wing_move_mode:
		return
	var wing_units_check = _get_wing_units()
	if wing_units_check.is_empty():
		return
	var min_mp = 999
	for u in wing_units_check:
		if u.move_points_left < min_mp:
			min_mp = u.move_points_left
	if min_mp <= 0:
		return
	_save_move_snapshot()
	var fwd = _get_forward_dir()
	var wing_units = _get_wing_units()
	if wing_units.is_empty():
		return
	# Validate: check all units can move in this direction
	# For foot units: cannot move backward (toward own edge)
	# For bonus move: forward only
	var can_all_move = true
	var new_positions = {}
	for u in wing_units:
		var target = Vector2i(u.grid_pos.x + dx, u.grid_pos.y + dy)
		# Validate direction for foot
		if u.is_foot():
			# Cannot move backward
			if dy != 0 and dy != fwd and dx == 0:
				can_all_move = false
				break
			# Cannot move diagonally
			if dx != 0 and dy != 0:
				can_all_move = false
				break
			# Bonus move: forward only
			if is_bonus_move and not (dx == 0 and dy == fwd):
				can_all_move = false
				break
			# Cannot move forward if no enemies ahead
			if dy == fwd and dx == 0 and not _is_enemy_ahead(u.grid_pos, fwd):
				can_all_move = false
				break
		# Check valid cell
		if not grid.is_valid_cell(target):
			can_all_move = false
			break
		# Check not occupied by non-wing unit
		var occupant = grid.get_unit_at(target)
		if occupant != null and not (occupant.faction == current_player_index and occupant.wing_color == active_wing_color and occupant.is_fresh()):
			can_all_move = false
			break
		# Check engagement
		if u.is_foot() and _is_foot_engaged_at(u, u.grid_pos):
			can_all_move = false
			break
		new_positions[u] = target
	if not can_all_move:
		return
	# Check for collisions within the wing (two units trying to go to same spot)
	var target_set = {}
	for u in new_positions:
		var t = new_positions[u]
		if target_set.has(t):
			return  # Collision
		target_set[t] = true
	# Also check targets aren't occupied by units NOT in our move set
	for u in new_positions:
		var t = new_positions[u]
		var occ = grid.get_unit_at(t)
		if occ != null and not new_positions.has(occ):
			return  # Blocked by unit not moving
	# Execute the move - free all first, then place all
	for u in new_positions:
		grid.free_cell(u.grid_pos)
	for u in new_positions:
		var target = new_positions[u]
		u.grid_pos = target
		u.position = grid.grid_to_world(target)
		grid.occupy_cell(target, u)
	for u in new_positions:
		u.move_points_left -= 1
	# Update global for UI display
	var min_left = 999
	for u in new_positions:
		if u.move_points_left < min_left:
			min_left = u.move_points_left
	move_points_remaining = min_left
	_update_ui()
	if min_left <= 0:
		_exit_wing_move_mode()

func _get_move_points() -> int:
	if is_bonus_move:
		return 2
	# Count how many real action phases come before Move in the sorted commands
	# Strategos and Bonus don't count as separate action phases
	var real_actions_before = 0
	for c in active_commands:
		if c == "Move":
			break
		if c != "Strategos" and c != "Bonus":
			real_actions_before += 1
	return 4 if real_actions_before == 0 else 2

func _get_forward_dir() -> int:
	if not battle_config:
		return 1
	var player = battle_config.player1 if current_player_index == 0 else battle_config.player2
	return 1 if player.edge == 1 else -1

func _is_enemy_ahead(pos: Vector2i, fwd: int) -> bool:
	var row = pos.y + fwd
	var end_row = grid.ROWS if fwd > 0 else -1
	while row != end_row:
		for u in all_units:
			if u.faction != current_player_index and u.grid_pos.y == row:
				return true
		row += fwd
	return false

func _is_foot_engaged_at(unit: Node2D, pos: Vector2i) -> bool:
	if not unit.is_foot():
		return false
	var fwd = _get_forward_dir()
	var ahead = Vector2i(pos.x, pos.y + fwd)
	var enemy = grid.get_unit_at(ahead)
	return enemy != null and enemy.faction != unit.faction and enemy.is_foot()

func _is_horse_engaged_at(unit: Node2D, pos: Vector2i) -> bool:
	if not unit.is_horse():
		return false
	for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var other = grid.get_unit_at(pos + off)
		if other and other.faction != unit.faction and other.is_horse():
			return true
	return false

func _show_move_highlights(unit: Node2D) -> void:
	_clear_highlights()
	if unit.is_exhausted:
		return
	var origin = unit.grid_pos
	var mp = _get_move_points()
	var fwd = _get_forward_dir()
	var is_foot = unit.is_foot()
	var is_horse = unit.is_horse()
	if is_foot and _is_foot_engaged_at(unit, origin):
		return
	if is_horse and _is_horse_engaged_at(unit, origin):
		return
	var reachable = []
	var visited = {}
	var queue = [{"pos": origin, "remaining": mp}]
	visited[origin] = true
	while queue.size() > 0:
		var current = queue.pop_front()
		var pos = current["pos"]
		var rem = current["remaining"]
		if pos != origin:
			reachable.append(pos)
		if rem <= 0:
			continue
		var neighbors = []
		if is_horse:
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					neighbors.append(Vector2i(pos.x + dx, pos.y + dy))
		else:
			neighbors.append(Vector2i(pos.x - 1, pos.y))
			neighbors.append(Vector2i(pos.x + 1, pos.y))
			if _is_enemy_ahead(pos, fwd):
				neighbors.append(Vector2i(pos.x, pos.y + fwd))
			if is_bonus_move:
				neighbors = []
				if _is_enemy_ahead(pos, fwd):
					neighbors.append(Vector2i(pos.x, pos.y + fwd))
		for n in neighbors:
			if not grid.is_valid_cell(n) or visited.has(n) or grid.is_cell_occupied(n):
				continue
			visited[n] = true
			var stops = false
			if is_foot and _is_foot_engaged_at(unit, n):
				stops = true
			if is_horse and _is_horse_engaged_at(unit, n):
				stops = true
			if stops:
				reachable.append(n)
			else:
				queue.append({"pos": n, "remaining": rem - 1})
	for cell in reachable:
		var hl = ColorRect.new()
		var cw = grid.get_cell_width(cell.x)
		var ch = grid.get_cell_height(cell.y)
		hl.size = Vector2(cw - 2, ch - 2)
		hl.position = grid.grid_to_world(cell) - Vector2(cw / 2.0 - 1, ch / 2.0 - 1)
		hl.color = Color(0.2, 0.9, 0.2, 0.35)
		highlight_layer.add_child(hl)
		move_highlights.append({"rect": hl, "cell": cell})

func _is_highlighted_cell(gpos: Vector2i) -> bool:
	for h in move_highlights:
		if h["cell"] == gpos:
			return true
	return false

func _clear_highlights() -> void:
	for h in move_highlights:
		h["rect"].queue_free()
	move_highlights.clear()

func _move_unit(unit: Node2D, target: Vector2i) -> void:
	grid.free_cell(unit.grid_pos)
	unit.grid_pos = target
	unit.position = grid.grid_to_world(target)
	grid.occupy_cell(target, unit)
	unit.set_moved(true)

func _on_end_turn_pressed() -> void:
	_clear_highlights()
	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null
	for u in all_units:
		if u.faction == current_player_index:
			u.reset_turn()
	if current_player_index == 0:
		current_player_index = 1
	else:
		current_player_index = 0
		turn_number += 1
	_update_ui()
	_open_command_phase()

func _update_ui() -> void:
	var current_name = player1_name if current_player_index == 0 else player2_name
	if battle_config:
		turn_label.text = battle_config.battle_name + " — Turn %d" % turn_number
	else:
		turn_label.text = "Turn %d" % turn_number
	phase_label.text = current_name.to_upper() + " TURN"
	if current_player_index == 0:
		phase_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	else:
		phase_label.add_theme_color_override("font_color", Color(1.0, 0.60, 0.15))
	# Update initiative label
	if initiative_label:
		var init_name = player1_name if initiative_holder == 0 else player2_name
		if initiative_holder == current_player_index:
			initiative_label.text = "★ Initiative: " + init_name
			initiative_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
		else:
			initiative_label.text = "Initiative: " + init_name
			initiative_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
