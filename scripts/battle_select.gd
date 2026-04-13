extends Control

const WING_COLORS = {
	"Red": Color(0.85, 0.20, 0.15),
	"Pink": Color(0.90, 0.45, 0.55),
	"Orange": Color(0.90, 0.55, 0.10),
	"Blue": Color(0.20, 0.40, 0.85),
	"Purple": Color(0.55, 0.25, 0.75),
	"Green": Color(0.20, 0.65, 0.30),
	"Yellow": Color(0.85, 0.80, 0.15),
	"Brown": Color(0.55, 0.35, 0.15),
}

const UNIT_TYPE_NAMES = ["Hoplite", "Heavy Infantry", "Light Infantry", "Light Horse"]
const UNIT_TYPE_ABBREV = ["HO", "HI", "LI", "LH"]
const DEPTH_NAMES = ["Single", "Double", "Triple"]

var selected_battle_index: int = -1
var battle_names: Array
var battle_descriptions: Array
var battle_player_names: Array
var all_battles: Array

# UI refs
var battle_list: VBoxContainer
var detail_panel: VBoxContainer
var start_button: Button
var title_label: Label
var description_label: RichTextLabel
var p1_section: VBoxContainer
var p2_section: VBoxContainer
var special_rules_section: VBoxContainer

func _ready() -> void:
	battle_names = BattleData.get_battle_names()
	battle_descriptions = BattleData.get_battle_descriptions()
	battle_player_names = BattleData.get_battle_player_names()
	all_battles = BattleData.get_all_battles()
	_build_ui()

func _build_ui() -> void:
	# Root background
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(root_vbox)

	# Header
	var header = Label.new()
	header.text = "WITH IT OR ON IT"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 42)
	header.add_theme_color_override("font_color", Color(0.82, 0.55, 0.15))
	root_vbox.add_child(header)

	var subtitle = Label.new()
	subtitle.text = "ἢ τὰν ἢ ἐπὶ τᾶς  —  Select a Battle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.55, 0.40))
	root_vbox.add_child(subtitle)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	root_vbox.add_child(sep)

	# Main content: left list + right details
	var hsplit = HBoxContainer.new()
	hsplit.add_theme_constant_override("separation", 24)
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.clip_contents = true
	root_vbox.add_child(hsplit)

	# Left panel - battle list
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(340, 0)
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.10, 0.09, 0.12)
	left_style.corner_radius_top_left = 8
	left_style.corner_radius_top_right = 8
	left_style.corner_radius_bottom_left = 8
	left_style.corner_radius_bottom_right = 8
	left_style.content_margin_left = 12
	left_style.content_margin_right = 12
	left_style.content_margin_top = 12
	left_style.content_margin_bottom = 12
	left_panel.add_theme_stylebox_override("panel", left_style)
	hsplit.add_child(left_panel)

	var left_scroll = ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(left_scroll)

	battle_list = VBoxContainer.new()
	battle_list.add_theme_constant_override("separation", 8)
	left_scroll.add_child(battle_list)

	for i in range(battle_names.size()):
		var btn = Button.new()
		btn.text = battle_names[i]
		btn.add_theme_font_size_override("font_size", 18)
		btn.custom_minimum_size = Vector2(300, 52)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.14, 0.13, 0.17)
		normal_style.corner_radius_top_left = 6
		normal_style.corner_radius_top_right = 6
		normal_style.corner_radius_bottom_left = 6
		normal_style.corner_radius_bottom_right = 6
		normal_style.content_margin_left = 16
		normal_style.content_margin_right = 16
		normal_style.content_margin_top = 8
		normal_style.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", normal_style)

		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(0.20, 0.18, 0.24)
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style = normal_style.duplicate()
		pressed_style.bg_color = Color(0.35, 0.25, 0.12)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.70))

		btn.pressed.connect(_on_battle_selected.bind(i))
		battle_list.add_child(btn)

	# Right panel - details
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_style = StyleBoxFlat.new()
	right_style.bg_color = Color(0.10, 0.09, 0.12)
	right_style.corner_radius_top_left = 8
	right_style.corner_radius_top_right = 8
	right_style.corner_radius_bottom_left = 8
	right_style.corner_radius_bottom_right = 8
	right_style.content_margin_left = 20
	right_style.content_margin_right = 20
	right_style.content_margin_top = 16
	right_style.content_margin_bottom = 16
	right_panel.add_theme_stylebox_override("panel", right_style)
	right_panel.clip_contents = true
	hsplit.add_child(right_panel)

	var right_scroll = ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.clip_contents = true
	right_panel.add_child(right_scroll)

	detail_panel = VBoxContainer.new()
	detail_panel.add_theme_constant_override("separation", 14)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.custom_minimum_size = Vector2(0, 0)
	right_scroll.add_child(detail_panel)

	# Placeholder
	var placeholder = Label.new()
	placeholder.text = "← Select a battle to view details"
	placeholder.add_theme_font_size_override("font_size", 20)
	placeholder.add_theme_color_override("font_color", Color(0.5, 0.45, 0.40))
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(placeholder)

	# Bottom bar with start button
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root_vbox.add_child(bottom)

	start_button = Button.new()
	start_button.text = "  START BATTLE  "
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.custom_minimum_size = Vector2(240, 50)
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)

	var start_style = StyleBoxFlat.new()
	start_style.bg_color = Color(0.60, 0.35, 0.08)
	start_style.corner_radius_top_left = 8
	start_style.corner_radius_top_right = 8
	start_style.corner_radius_bottom_left = 8
	start_style.corner_radius_bottom_right = 8
	start_style.content_margin_left = 24
	start_style.content_margin_right = 24
	start_style.content_margin_top = 10
	start_style.content_margin_bottom = 10
	start_button.add_theme_stylebox_override("normal", start_style)

	var start_hover = start_style.duplicate()
	start_hover.bg_color = Color(0.75, 0.45, 0.10)
	start_button.add_theme_stylebox_override("hover", start_hover)

	var start_disabled = start_style.duplicate()
	start_disabled.bg_color = Color(0.20, 0.18, 0.16)
	start_button.add_theme_stylebox_override("disabled", start_disabled)

	start_button.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	start_button.add_theme_color_override("font_disabled_color", Color(0.4, 0.38, 0.35))

	bottom.add_child(start_button)


func _on_battle_selected(index: int) -> void:
	selected_battle_index = index
	start_button.disabled = false

	# Highlight selected button
	for i in range(battle_list.get_child_count()):
		var btn = battle_list.get_child(i)
		if i == index:
			var sel_style = StyleBoxFlat.new()
			sel_style.bg_color = Color(0.50, 0.30, 0.08)
			sel_style.corner_radius_top_left = 6
			sel_style.corner_radius_top_right = 6
			sel_style.corner_radius_bottom_left = 6
			sel_style.corner_radius_bottom_right = 6
			sel_style.content_margin_left = 16
			sel_style.content_margin_right = 16
			sel_style.content_margin_top = 8
			sel_style.content_margin_bottom = 8
			sel_style.border_width_left = 3
			sel_style.border_color = Color(0.85, 0.60, 0.15)
			btn.add_theme_stylebox_override("normal", sel_style)
			btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.65))
		else:
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.14, 0.13, 0.17)
			normal_style.corner_radius_top_left = 6
			normal_style.corner_radius_top_right = 6
			normal_style.corner_radius_bottom_left = 6
			normal_style.corner_radius_bottom_right = 6
			normal_style.content_margin_left = 16
			normal_style.content_margin_right = 16
			normal_style.content_margin_top = 8
			normal_style.content_margin_bottom = 8
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))

	_show_battle_details(index)


func _show_battle_details(index: int) -> void:
	# Clear existing
	for child in detail_panel.get_children():
		child.queue_free()

	var battle: BattleData.BattleConfig = all_battles[index]

	# Title
	var title = Label.new()
	title.text = battle.battle_name
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 0.20))
	detail_panel.add_child(title)

	# Description
	var desc = Label.new()
	desc.text = battle_descriptions[index]
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(desc)

	# Separator
	detail_panel.add_child(HSeparator.new())

	# Player 1
	_add_player_section(detail_panel, battle.player1)

	# Separator
	detail_panel.add_child(HSeparator.new())

	# Player 2
	_add_player_section(detail_panel, battle.player2)

	# Special Rules
	if battle.special_rules.size() > 0:
		detail_panel.add_child(HSeparator.new())
		var sr_title = Label.new()
		sr_title.text = "SPECIAL RULES"
		sr_title.add_theme_font_size_override("font_size", 18)
		sr_title.add_theme_color_override("font_color", Color(0.90, 0.70, 0.25))
		detail_panel.add_child(sr_title)

		for rule in battle.special_rules:
			var rule_box = VBoxContainer.new()
			rule_box.add_theme_constant_override("separation", 2)

			var rule_name = Label.new()
			rule_name.text = rule["name"]
			rule_name.add_theme_font_size_override("font_size", 15)
			rule_name.add_theme_color_override("font_color", Color(0.95, 0.80, 0.50))
			rule_box.add_child(rule_name)

			var rule_text = Label.new()
			rule_text.text = rule["text"]
			rule_text.add_theme_font_size_override("font_size", 13)
			rule_text.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
			rule_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rule_box.add_child(rule_text)

			detail_panel.add_child(rule_box)


func _add_player_section(parent: VBoxContainer, player: BattleData.PlayerSetup) -> void:
	# Player header with tags
	var header_box = HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 12)

	var player_label = Label.new()
	player_label.text = player.player_name.to_upper() + " PLAYER"
	player_label.add_theme_font_size_override("font_size", 20)
	player_label.add_theme_color_override("font_color", Color(0.90, 0.85, 0.75))
	header_box.add_child(player_label)

	# Tags
	var tags = []
	if player.first_setup:
		tags.append("First Set-Up")
	if player.first_turn:
		tags.append("First Turn")
	if player.has_initiative:
		tags.append("Initiative")

	for tag_text in tags:
		var tag = Label.new()
		tag.text = " " + tag_text + " "
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
		header_box.add_child(tag)

	parent.add_child(header_box)

	# Stats line
	var stats = Label.new()
	stats.text = "Rally Limit: %d  |  Skirmish Factor: %d  |  Edge: %d" % [player.rally_limit, player.skirmish_factor, player.edge]
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55))
	parent.add_child(stats)

	# Wings
	for wing in player.wings:
		var wing_info = Label.new()
		var unit_strs = []
		for u in wing.units:
			var s = UNIT_TYPE_ABBREV[u["type"]] + " x" + str(u["count"])
			if u["leaders"] > 0:
				s += " (" + str(u["leaders"]) + " Ldr)"
			unit_strs.append(s)
		var depth_str = DEPTH_NAMES[wing.depth]
		var off_map_str = " [OFF-MAP]" if wing.off_map else ""
		wing_info.text = wing.wing_name + " (" + wing.color_name + ") - " + depth_str + " - " + ", ".join(unit_strs) + off_map_str
		wing_info.add_theme_font_size_override("font_size", 13)
		if WING_COLORS.has(wing.color_name):
			wing_info.add_theme_color_override("font_color", WING_COLORS[wing.color_name].lightened(0.35))
		else:
			wing_info.add_theme_color_override("font_color", Color(0.80, 0.75, 0.65))
		wing_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(wing_info)

	# Victory conditions
	var vic_label = Label.new()
	vic_label.text = "Victory: " + " OR ".join(player.victory_conditions)
	vic_label.add_theme_font_size_override("font_size", 13)
	vic_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.45))
	vic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(vic_label)


func _on_start_pressed() -> void:
	if selected_battle_index < 0:
		return
	# Store selected battle index in a global/autoload or pass via scene change
	# For now, use meta on the scene tree
	var battle = all_battles[selected_battle_index]
	get_tree().set_meta("selected_battle", battle)
	get_tree().set_meta("selected_battle_index", selected_battle_index)
	get_tree().change_scene_to_file("res://main.tscn")
