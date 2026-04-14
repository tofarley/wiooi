extends Control

signal rally_phase_done()

var all_units: Array = []
var grid: Node
var active_wing_color: String = ""
var current_player_index: int = 0
var is_bonus_rally: bool = false
var rally_limit: int = 0

var exhausted_units: Array = []  # eligible units for rally
var attempts_remaining: int = 0
var current_unit: Node2D = null
var attempted_units: Array = []  # units already attempted this phase

var info_panel: PanelContainer
var info_vbox: VBoxContainer
var action_label: Label
var detail_label: Label
var roll_button: Button
var done_button: Button
var results_label: Label

func setup(p_units: Array, p_grid: Node, p_wing_color: String, p_player: int, p_bonus: bool, p_rally_limit: int) -> void:
	all_units = p_units
	grid = p_grid
	active_wing_color = p_wing_color
	current_player_index = p_player
	is_bonus_rally = p_bonus
	rally_limit = p_rally_limit
	attempted_units.clear()
	_build_ui()
	_begin_rally()

func _build_ui() -> void:
	info_panel = PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	info_panel.offset_left = -320
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.11)
	style.border_width_left = 2
	style.border_color = Color(0.2, 0.6, 0.3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	info_panel.add_theme_stylebox_override("panel", style)
	add_child(info_panel)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_panel.add_child(scroll)

	info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 10)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(info_vbox)

	var title = Label.new()
	title.text = "RALLY PHASE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.25, 0.75, 0.35))
	info_vbox.add_child(title)

	info_vbox.add_child(HSeparator.new())

	action_label = Label.new()
	action_label.text = ""
	action_label.add_theme_font_size_override("font_size", 14)
	action_label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	info_vbox.add_child(action_label)

	detail_label = Label.new()
	detail_label.text = ""
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	info_vbox.add_child(detail_label)

	results_label = Label.new()
	results_label.text = ""
	results_label.add_theme_font_size_override("font_size", 12)
	results_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
	info_vbox.add_child(results_label)

	info_vbox.add_child(HSeparator.new())

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	info_vbox.add_child(btn_row)

	roll_button = Button.new()
	roll_button.text = "Roll d8"
	roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_button.custom_minimum_size = Vector2(0, 36)
	roll_button.add_theme_font_size_override("font_size", 14)
	roll_button.visible = false
	roll_button.pressed.connect(_on_roll)
	btn_row.add_child(roll_button)

	done_button = Button.new()
	done_button.text = "Done Rally"
	done_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done_button.custom_minimum_size = Vector2(0, 36)
	done_button.add_theme_font_size_override("font_size", 14)
	done_button.pressed.connect(_on_done)
	btn_row.add_child(done_button)

func _begin_rally() -> void:
	_find_exhausted_units()
	attempts_remaining = rally_limit
	current_unit = null
	if exhausted_units.is_empty():
		action_label.text = "No exhausted units to rally."
		detail_label.text = "Press Done to continue."
		roll_button.visible = false
		return
	action_label.text = "Select unit to Rally (%d attempts left)" % attempts_remaining
	detail_label.text = "Click an exhausted %s unit.\nRally Limit: %d" % [active_wing_color, rally_limit]
	if is_bonus_rally:
		detail_label.text += " (+1 Bonus)"
	roll_button.visible = false
	# Highlight exhausted units
	for u in exhausted_units:
		u.set_selected(true)

func _find_exhausted_units() -> void:
	exhausted_units.clear()
	for u in all_units:
		if u.faction != current_player_index:
			continue
		if u.wing_color != active_wing_color:
			continue
		if not u.is_exhausted:
			continue
		if u in attempted_units:
			continue
		# Revealed Leaders cannot be rallied
		# (we don't track revealed leader state fully yet, skip for now)
		exhausted_units.append(u)

func handle_click(grid_pos: Vector2i) -> void:
	if current_unit != null:
		return  # Already selected, waiting for roll
	if attempts_remaining <= 0:
		return
	var clicked = grid.get_unit_at(grid_pos)
	if clicked and clicked in exhausted_units:
		_select_rally_unit(clicked)

func _select_rally_unit(unit: Node2D) -> void:
	# Deselect all highlights
	for u in exhausted_units:
		u.set_selected(false)
	current_unit = unit
	current_unit.set_selected(true)
	# Calculate modifiers
	var adj_fresh = _count_adjacent_fresh(unit)
	var is_hoplite = unit.unit_type == 0
	var modifier = adj_fresh
	if is_hoplite:
		modifier += 1
	if is_bonus_rally:
		modifier += 1
	var needed = 8 - modifier
	var type_names = ["HO", "HI", "LI", "LH"]
	action_label.text = "Rally: %s (%s)" % [unit.unit_name, type_names[unit.unit_type]]
	var details = "Modifiers:"
	if adj_fresh > 0:
		details += "\n  +%d adjacent fresh units" % adj_fresh
	if is_hoplite:
		details += "\n  +1 Hoplite"
	if is_bonus_rally:
		details += "\n  +1 Bonus Rally"
	details += "\nTotal modifier: +%d" % modifier
	details += "\nNeed: %d+ on d8 (nat 1 = eliminated!)" % needed
	detail_label.text = details
	roll_button.visible = true

func _count_adjacent_fresh(unit: Node2D) -> int:
	var count = 0
	for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var adj_pos = unit.grid_pos + off
		var adj = grid.get_unit_at(adj_pos)
		if adj and adj.faction == unit.faction and adj.wing_color == unit.wing_color:
			if not adj.is_exhausted:
				count += 1
	return count

func _on_roll() -> void:
	if not current_unit:
		return
	var die = CombatResolver.roll_d8()
	var adj_fresh = _count_adjacent_fresh(current_unit)
	var modifier = adj_fresh
	if current_unit.unit_type == 0:
		modifier += 1
	if is_bonus_rally:
		modifier += 1
	var total = die + modifier
	roll_button.visible = false
	attempted_units.append(current_unit)
	attempts_remaining -= 1
	var result_text = ""
	if die == 1:
		# Natural 1 = eliminated regardless of modifiers
		result_text = "Roll: %d (NATURAL 1!) → %s ELIMINATED!" % [die, current_unit.unit_name]
		_eliminate_unit(current_unit)
	elif total >= 8:
		result_text = "Roll: %d + %d = %d ≥ 8 → %s RALLIED!" % [die, modifier, total, current_unit.unit_name]
		current_unit.is_exhausted = false
		current_unit.flip()  # Back to fresh side
	else:
		result_text = "Roll: %d + %d = %d < 8 → Rally FAILED" % [die, modifier, total]
	results_label.text += result_text + "\n"
	current_unit.set_selected(false)
	current_unit = null
	# Continue with more attempts
	_find_exhausted_units()
	if attempts_remaining <= 0 or exhausted_units.is_empty():
		action_label.text = "Rally phase complete."
		detail_label.text = "Press Done to continue."
	else:
		action_label.text = "Select unit to Rally (%d attempts left)" % attempts_remaining
		for u in exhausted_units:
			u.set_selected(true)

func _eliminate_unit(unit: Node2D) -> void:
	grid.free_cell(unit.grid_pos)
	all_units.erase(unit)
	unit.queue_free()
	# Note: rally elimination does NOT trigger rout check per rulebook

func _on_done() -> void:
	for u in all_units:
		u.set_selected(false)
	rally_phase_done.emit()
