extends Control

signal combat_phase_done()

enum CombatStep { SELECT_ATTACKER, SELECT_DEFENDER, CONFIRM_ATTACK, SHOW_RESULT, ALLOCATE_EXHAUSTION, DONE }

var main_ref: Node2D  # reference to main.gd
var all_units: Array = []
var grid: Node
var active_wing_color: String = ""
var current_player_index: int = 0
var is_bonus_combat: bool = false

var step: int = CombatStep.SELECT_ATTACKER
var primary_attacker: Node2D = null
var defender: Node2D = null
var support_units: Array = []
var eligible_attackers: Array = []
var eligible_defenders: Array = []
var attacks_made: Array = []  # track which units already attacked/supported
var attacked_defenders: Array = []  # track which enemy units were already targeted

# Result state
var final_cc: String = ""
var final_drm: int = 0
var die_roll: int = 0
var modified_roll: int = 0
var combat_result: String = ""

var info_panel: PanelContainer
var info_vbox: VBoxContainer
var action_label: Label
var detail_label: Label
var roll_button: Button
var done_button: Button
var skip_button: Button

func setup(p_main: Node2D, p_units: Array, p_grid: Node, p_wing_color: String, p_player: int, p_bonus: bool) -> void:
	main_ref = p_main
	all_units = p_units
	grid = p_grid
	active_wing_color = p_wing_color
	current_player_index = p_player
	is_bonus_combat = p_bonus
	attacks_made.clear()
	attacked_defenders.clear()
	_build_ui()
	_begin_select_attacker()

func _build_ui() -> void:
	info_panel = PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	info_panel.offset_left = -320
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.11)
	style.border_width_left = 2
	style.border_color = Color(0.7, 0.2, 0.15)
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
	title.text = "COMBAT PHASE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.25, 0.20))
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

	skip_button = Button.new()
	skip_button.text = "Skip Attack"
	skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip_button.custom_minimum_size = Vector2(0, 36)
	skip_button.add_theme_font_size_override("font_size", 14)
	skip_button.pressed.connect(_on_skip_attack)
	btn_row.add_child(skip_button)

	done_button = Button.new()
	done_button.text = "Done Combat"
	done_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done_button.custom_minimum_size = Vector2(0, 36)
	done_button.add_theme_font_size_override("font_size", 14)
	done_button.pressed.connect(_on_done)
	btn_row.add_child(done_button)

func _begin_select_attacker() -> void:
	step = CombatStep.SELECT_ATTACKER
	primary_attacker = null
	defender = null
	support_units.clear()
	_find_eligible_attackers()
	if eligible_attackers.is_empty():
		action_label.text = "No units can attack."
		detail_label.text = "Press Done to end combat."
		roll_button.visible = false
		skip_button.visible = false
		return
	action_label.text = "Select PRIMARY ATTACKER"
	detail_label.text = "Click a fresh %s unit adjacent to an enemy." % active_wing_color
	roll_button.visible = false
	skip_button.visible = true
	# Highlight eligible attackers
	for u in eligible_attackers:
		u.set_selected(true)

func _find_eligible_attackers() -> void:
	eligible_attackers.clear()
	for u in all_units:
		if u.faction != current_player_index:
			continue
		if u.wing_color != active_wing_color:
			continue
		if u.is_exhausted or u in attacks_made:
			continue
		# Must be adjacent to at least one enemy
		if _has_adjacent_enemy(u):
			eligible_attackers.append(u)

func _has_adjacent_enemy(unit: Node2D) -> bool:
	for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var adj_pos = unit.grid_pos + off
		var adj_unit = grid.get_unit_at(adj_pos)
		if adj_unit and adj_unit.faction != unit.faction:
			return true
	return false

func _get_adjacent_enemies(unit: Node2D) -> Array:
	var enemies = []
	for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var adj_pos = unit.grid_pos + off
		var adj_unit = grid.get_unit_at(adj_pos)
		if adj_unit and adj_unit.faction != unit.faction and adj_unit not in attacked_defenders:
			enemies.append(adj_unit)
	return enemies

func _get_support_units(primary: Node2D, def: Node2D) -> Array:
	var supports = []
	for u in all_units:
		if u == primary or u in attacks_made:
			continue
		if u.faction != current_player_index or u.wing_color != active_wing_color:
			continue
		if u.is_exhausted:
			continue
		# Adjacent to primary OR defender
		var adj_to_primary = _is_adjacent(u, primary)
		var adj_to_defender = _is_adjacent(u, def)
		if adj_to_primary or adj_to_defender:
			supports.append(u)
	return supports

func _is_adjacent(a: Node2D, b: Node2D) -> bool:
	var diff = a.grid_pos - b.grid_pos
	return (abs(diff.x) + abs(diff.y)) == 1

func _has_flanking_bonus(def: Node2D) -> bool:
	# +1 CC if any friendly fresh unit (any wing) is also adjacent to defender
	for u in all_units:
		if u == primary_attacker:
			continue
		if u.faction != current_player_index:
			continue
		if u.is_exhausted:
			continue
		if _is_adjacent(u, def):
			return true
	return false

func _calc_cc(primary: Node2D, def: Node2D) -> String:
	var cc = primary.combat_class
	# Hoplite CC borrowing: chain of fresh hoplites to higher CC
	if primary.unit_type == 0:  # HOPLITE
		cc = _find_best_hoplite_cc(primary)
	# CC modifiers
	var mod = 0
	if def.is_exhausted:
		mod += 1
	if _has_flanking_bonus(def):
		mod += 1
	# -1 if half wing exhausted/eliminated (not for hoplites)
	if primary.unit_type != 0:
		var total = 0
		var gone = 0
		for u in all_units:
			if u.faction == current_player_index and u.wing_color == active_wing_color:
				total += 1
				if u.is_exhausted:
					gone += 1
		# Count eliminated (not on map anymore) - approximate
		if total > 0 and gone * 2 >= total:
			mod -= 1
	return CombatResolver.modify_cc(cc, mod)

func _find_best_hoplite_cc(start: Node2D) -> String:
	# BFS through chain of fresh hoplites in same wing to find highest CC
	var best_cc = start.combat_class
	var visited = {start.grid_pos: true}
	var queue = [start]
	while queue.size() > 0:
		var current = queue.pop_front()
		if CombatResolver.CC_ORDER.find(current.combat_class) > CombatResolver.CC_ORDER.find(best_cc):
			best_cc = current.combat_class
		for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var adj_pos = current.grid_pos + off
			if visited.has(adj_pos):
				continue
			visited[adj_pos] = true
			var adj = grid.get_unit_at(adj_pos)
			if adj and adj.faction == current.faction and adj.wing_color == current.wing_color:
				if adj.unit_type == 0 and not adj.is_exhausted:  # Fresh hoplite
					queue.append(adj)
	return best_cc

func handle_click(grid_pos: Vector2i) -> void:
	var clicked_unit = grid.get_unit_at(grid_pos)
	match step:
		CombatStep.SELECT_ATTACKER:
			if clicked_unit and clicked_unit in eligible_attackers:
				_select_attacker(clicked_unit)
		CombatStep.SELECT_DEFENDER:
			if clicked_unit and clicked_unit in eligible_defenders:
				_select_defender(clicked_unit)
			elif clicked_unit == primary_attacker:
				# Click attacker again to deselect and go back
				_cancel_attacker()
		CombatStep.CONFIRM_ATTACK:
			# Click defender to deselect it
			if clicked_unit == defender:
				_cancel_defender()
			# Click attacker to go all the way back
			elif clicked_unit == primary_attacker:
				_cancel_attacker()
		CombatStep.ALLOCATE_EXHAUSTION:
			_handle_exhaustion_click(clicked_unit)

func _cancel_attacker() -> void:
	# Go back to attacker selection
	if defender:
		defender.set_selected(false)
	if primary_attacker:
		primary_attacker.set_selected(false)
	for u in support_units:
		u.set_selected(false)
	defender = null
	primary_attacker = null
	support_units.clear()
	roll_button.visible = false
	_begin_select_attacker()

func _cancel_defender() -> void:
	# Go back to defender selection, keep attacker
	if defender:
		defender.set_selected(false)
	for u in support_units:
		u.set_selected(false)
	defender = null
	support_units.clear()
	roll_button.visible = false
	step = CombatStep.SELECT_DEFENDER
	eligible_defenders = _get_adjacent_enemies(primary_attacker)
	action_label.text = "Select DEFENDER"
	detail_label.text = "Click an enemy adjacent to %s.\nClick attacker to cancel." % primary_attacker.unit_name
	skip_button.visible = true

func _select_attacker(unit: Node2D) -> void:
	# Deselect all
	for u in eligible_attackers:
		u.set_selected(false)
	primary_attacker = unit
	primary_attacker.set_selected(true)
	step = CombatStep.SELECT_DEFENDER
	# Find eligible defenders
	eligible_defenders = _get_adjacent_enemies(primary_attacker)
	action_label.text = "Select DEFENDER"
	detail_label.text = "Click an enemy adjacent to %s.\nClick attacker to cancel." % primary_attacker.unit_name

func _select_defender(unit: Node2D) -> void:
	defender = unit
	defender.set_selected(true)
	support_units = _get_support_units(primary_attacker, defender)
	step = CombatStep.CONFIRM_ATTACK
	# Calculate combat preview
	final_cc = _calc_cc(primary_attacker, defender)
	var utmm_drm = CombatResolver.get_utmm_drm(primary_attacker.unit_type, defender.unit_type)
	final_drm = utmm_drm - support_units.size()
	if is_bonus_combat:
		final_drm -= 1
	var type_names = ["HO", "HI", "LI", "LH"]
	var atk_type = type_names[primary_attacker.unit_type]
	var def_type = type_names[defender.unit_type]
	skip_button.visible = false
	action_label.text = "ATTACK: %s (%s %s) → %s (%s)" % [primary_attacker.unit_name, atk_type, final_cc, defender.unit_name, def_type]
	var details = "UTMM: %+d" % utmm_drm
	if support_units.size() > 0:
		details += " | Support: -%d" % support_units.size()
	if is_bonus_combat:
		details += " | Bonus: -1"
	details += "\nFinal DRM: %+d | CC: %s" % [final_drm, final_cc]
	details += "\nSupport: %d units" % support_units.size()
	details += "\nClick defender/attacker to cancel"
	detail_label.text = details
	roll_button.visible = true
	roll_button.text = "Roll d8"
	# Ensure roll button is connected to _on_roll (reconnect after previous attack)
	if roll_button.pressed.is_connected(_apply_result):
		roll_button.pressed.disconnect(_apply_result)
	if not roll_button.pressed.is_connected(_on_roll):
		roll_button.pressed.connect(_on_roll)
	skip_button.visible = false
	# Highlight support units
	for u in support_units:
		u.set_selected(true)

func _on_roll() -> void:
	die_roll = CombatResolver.roll_d8()
	modified_roll = die_roll + final_drm
	combat_result = CombatResolver.resolve_crt(final_cc, modified_roll)
	step = CombatStep.SHOW_RESULT
	action_label.text = "RESULT: %s" % combat_result
	var result_desc = {"DE": "Defender ELIMINATED", "DX": "Defender Exhausted", "AX": "Attacker Exhausted", "EX": "Both Exhaust One", "AA": "All Attackers Exhausted"}
	detail_label.text = "Roll: %d + DRM %+d = %d\nCC: %s → %s\n%s" % [die_roll, final_drm, modified_roll, final_cc, combat_result, result_desc.get(combat_result, "")]
	roll_button.text = "Apply Result"
	roll_button.pressed.disconnect(_on_roll)
	roll_button.pressed.connect(_apply_result)

func _apply_result() -> void:
	roll_button.pressed.disconnect(_apply_result)
	# Mark all participants as having attacked
	attacked_defenders.append(defender)
	attacks_made.append(primary_attacker)
	for u in support_units:
		attacks_made.append(u)
	# Apply the combat result
	match combat_result:
		"DE":
			_eliminate_unit(defender)
		"DX":
			_exhaust_or_eliminate(defender, false)
		"AX":
			_exhaust_or_eliminate(primary_attacker, true)
		"EX":
			_exhaust_or_eliminate(defender, false)
			_exhaust_or_eliminate(primary_attacker, true)
		"AA":
			_exhaust_or_eliminate(primary_attacker, true)
			for u in support_units:
				_exhaust_or_eliminate(u, true)
	# Deselect all and start next attack
	for u in all_units:
		u.set_selected(false)
	_begin_select_attacker()

func _exhaust_or_eliminate(unit: Node2D, _is_attacker: bool) -> void:
	if unit.is_exhausted:
		_eliminate_unit(unit)
	else:
		unit.is_exhausted = true
		unit.flip()  # Show exhausted side
		# Check if brittle
		if unit.is_brittle:
			_eliminate_unit(unit)

func _eliminate_unit(unit: Node2D) -> void:
	grid.free_cell(unit.grid_pos)
	all_units.erase(unit)
	unit.queue_free()
	# TODO: score VP, trigger rout check
	detail_label.text += "\n%s ELIMINATED!" % unit.unit_name

func _on_skip_attack() -> void:
	for u in all_units:
		u.set_selected(false)
	_begin_select_attacker()

func _on_done() -> void:
	for u in all_units:
		u.set_selected(false)
	combat_phase_done.emit()

func _handle_exhaustion_click(_unit: Node2D) -> void:
	# TODO: let player choose which unit absorbs exhaustion
	pass
