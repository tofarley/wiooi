extends Control

signal commands_selected(wing_index: int, command1: String, command2: String)
signal cancelled()

const MARKERS = [
	{"side_a": "Move", "side_b": "Combat"},
	{"side_a": "Skirmish", "side_b": "Rally"},
	{"side_a": "Strategos", "side_b": "Bonus"},
]

const COMMAND_COLORS = {
	"Move": Color(0.55, 0.18, 0.12),
	"Combat": Color(0.18, 0.18, 0.18),
	"Skirmish": Color(0.50, 0.42, 0.28),
	"Rally": Color(0.50, 0.42, 0.28),
	"Strategos": Color(0.22, 0.22, 0.22),
	"Bonus": Color(0.22, 0.22, 0.22),
}

const COMMAND_ICONS = {
	"Move": "▲",
	"Combat": "🔥",
	"Skirmish": "»",
	"Rally": "✋",
	"Strategos": "⛑",
	"Bonus": "✊",
}

var wings_data: Array = []
var player_name: String = ""
var selected_wing_index: int = -1
var selected_commands: Array = []
var used_marker_indices: Array = []

var wing_buttons: Array = []
var command_buttons: Dictionary = {}
var confirm_button: Button
var info_label: Label
var wing_container: VBoxContainer

func _ready() -> void:
	_build_ui()

func setup(p_wings: Array, p_player_name: String) -> void:
	wings_data = p_wings
	player_name = p_player_name
	selected_wing_index = -1
	selected_commands.clear()
	used_marker_indices.clear()
	_rebuild_wing_buttons()
	_update_state()

func _build_ui() -> void:
	# Right-side panel
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -300
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.11)
	style.border_width_left = 2
	style.border_color = Color(0.5, 0.35, 0.12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "COMMAND PHASE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 0.20))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Step 1
	var s1 = Label.new()
	s1.text = "Select Wing:"
	s1.add_theme_font_size_override("font_size", 13)
	s1.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	vbox.add_child(s1)

	wing_container = VBoxContainer.new()
	wing_container.name = "WingContainer"
	wing_container.add_theme_constant_override("separation", 4)
	vbox.add_child(wing_container)

	vbox.add_child(HSeparator.new())

	# Step 2
	var s2 = Label.new()
	s2.text = "Play two Commands:"
	s2.add_theme_font_size_override("font_size", 13)
	s2.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	vbox.add_child(s2)

	# 3 markers, each as a pair of full-width buttons
	for i in range(MARKERS.size()):
		var marker_label = Label.new()
		marker_label.text = "Marker %d" % (i + 1)
		marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker_label.add_theme_font_size_override("font_size", 10)
		marker_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		vbox.add_child(marker_label)

		var pair = HBoxContainer.new()
		pair.add_theme_constant_override("separation", 4)
		vbox.add_child(pair)

		for side_key in ["side_a", "side_b"]:
			var cmd_name = MARKERS[i][side_key]
			var btn = Button.new()
			btn.text = COMMAND_ICONS[cmd_name] + " " + cmd_name
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 40)
			btn.add_theme_font_size_override("font_size", 14)
			var bs = _make_btn_style(COMMAND_COLORS[cmd_name])
			btn.add_theme_stylebox_override("normal", bs)
			btn.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
			btn.pressed.connect(_on_command_pressed.bind(cmd_name, i))
			pair.add_child(btn)
			command_buttons[cmd_name] = btn

	vbox.add_child(HSeparator.new())

	# Info label
	info_label = Label.new()
	info_label.text = "Select a wing to activate."
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	vbox.add_child(info_label)

	# Bottom buttons
	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, 36)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.pressed.connect(func(): cancelled.emit())
	bottom.add_child(cancel_btn)

	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.custom_minimum_size = Vector2(0, 36)
	confirm_button.add_theme_font_size_override("font_size", 14)
	confirm_button.disabled = true
	var cs = _make_btn_style(Color(0.45, 0.30, 0.08))
	confirm_button.add_theme_stylebox_override("normal", cs)
	var cd = _make_btn_style(Color(0.18, 0.16, 0.14))
	confirm_button.add_theme_stylebox_override("disabled", cd)
	confirm_button.pressed.connect(_on_confirm)
	bottom.add_child(confirm_button)

func _make_btn_style(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _rebuild_wing_buttons() -> void:
	for child in wing_container.get_children():
		child.queue_free()
	wing_buttons.clear()

	for i in range(wings_data.size()):
		var w = wings_data[i]
		var btn = Button.new()
		btn.text = w["name"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		btn.add_theme_font_size_override("font_size", 13)
		var bs = _make_btn_style(Color(0.16, 0.14, 0.18))
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
		btn.pressed.connect(_on_wing_pressed.bind(i))
		wing_container.add_child(btn)
		wing_buttons.append(btn)

func _on_wing_pressed(index: int) -> void:
	selected_wing_index = index
	_update_state()

func _on_command_pressed(cmd_name: String, marker_index: int) -> void:
	if selected_wing_index < 0:
		return
	if cmd_name in selected_commands:
		selected_commands.erase(cmd_name)
		used_marker_indices.erase(marker_index)
		_update_state()
		return
	if selected_commands.size() >= 2:
		return
	if marker_index in used_marker_indices:
		return
	selected_commands.append(cmd_name)
	used_marker_indices.append(marker_index)
	_update_state()

func _on_confirm() -> void:
	if selected_wing_index >= 0 and selected_commands.size() == 2:
		commands_selected.emit(selected_wing_index, selected_commands[0], selected_commands[1])

func _update_state() -> void:
	# Wing buttons
	for i in range(wing_buttons.size()):
		var btn = wing_buttons[i]
		if i == selected_wing_index:
			var s = _make_btn_style(Color(0.40, 0.28, 0.08))
			s.border_width_left = 3
			s.border_color = Color(0.85, 0.60, 0.15)
			btn.add_theme_stylebox_override("normal", s)
			btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.65))
		else:
			btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.16, 0.14, 0.18)))
			btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))

	# Command buttons
	for cmd_name in command_buttons:
		var btn = command_buttons[cmd_name]
		var is_sel = cmd_name in selected_commands
		var mi = _get_marker_index(cmd_name)
		var locked = mi in used_marker_indices and not is_sel
		var full = selected_commands.size() >= 2 and not is_sel

		if is_sel:
			var s = _make_btn_style(Color(0.12, 0.50, 0.22))
			s.border_width_top = 2
			s.border_width_bottom = 2
			s.border_width_left = 2
			s.border_width_right = 2
			s.border_color = Color(0.25, 0.85, 0.35)
			btn.add_theme_stylebox_override("normal", s)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
		elif locked or full:
			btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.10, 0.10, 0.10)))
			btn.add_theme_color_override("font_color", Color(0.30, 0.30, 0.30))
		else:
			btn.add_theme_stylebox_override("normal", _make_btn_style(COMMAND_COLORS[cmd_name]))
			btn.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
		btn.disabled = selected_wing_index < 0

	# Info
	if selected_wing_index < 0:
		info_label.text = "Select a wing to activate."
	elif selected_commands.size() == 0:
		info_label.text = wings_data[selected_wing_index]["name"] + "\nChoose two commands."
	elif selected_commands.size() == 1:
		info_label.text = selected_commands[0] + " selected.\nChoose one more."
	else:
		var txt = selected_commands[0] + " + " + selected_commands[1]
		if "Strategos" in selected_commands:
			var other = selected_commands[0] if selected_commands[1] == "Strategos" else selected_commands[1]
			txt += "\nAll wings: " + other + " (RL -1)"
		elif "Bonus" in selected_commands:
			var other = selected_commands[0] if selected_commands[1] == "Bonus" else selected_commands[1]
			txt += "\nEnhanced " + other
		info_label.text = txt

	confirm_button.disabled = not (selected_wing_index >= 0 and selected_commands.size() == 2)

func _get_marker_index(cmd_name: String) -> int:
	for i in range(MARKERS.size()):
		if MARKERS[i]["side_a"] == cmd_name or MARKERS[i]["side_b"] == cmd_name:
			return i
	return -1
