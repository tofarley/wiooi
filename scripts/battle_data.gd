extends RefCounted
class_name BattleData

# Unit types matching the rulebook
enum UType { HOPLITE, HEAVY_INFANTRY, LIGHT_INFANTRY, LIGHT_HORSE }

# Wing depth
enum Depth { SINGLE, DOUBLE, TRIPLE }

# Horizontal placement
enum HPlacement { CENTER, LEFT_OF_CENTER, RIGHT_OF_CENTER, LEFT_OF_WING, RIGHT_OF_WING, CUSTOM }

class WingSetup:
	var wing_name: String
	var color_name: String  # for display/identification
	var depth: int  # Depth enum
	var placement: int  # HPlacement enum
	var placement_ref: String = ""  # name of wing to place relative to, or "dotted_line"
	var units: Array = []  # Array of {type: UType, count: int, leaders: int}
	var edge_distance: int = 6  # squares from edge (default)
	var off_map: bool = false
	var special_notes: String = ""

class PlayerSetup:
	var player_name: String
	var edge: int  # 1 or 2
	var rally_limit: int
	var skirmish_factor: int
	var first_setup: bool = false
	var first_turn: bool = false
	var has_initiative: bool = false
	var wings: Array = []  # Array of WingSetup
	var victory_conditions: Array = []  # Array of strings
	var extra_markers: Dictionary = {}  # marker_name -> count

class BattleConfig:
	var battle_name: String
	var year: String
	var description: String
	var player1: PlayerSetup  # typically Greek/Spartan/Boeotian/Argive
	var player2: PlayerSetup  # typically Persian/Athenian
	var special_rules: Array = []  # Array of {name: String, text: String}

static func get_all_battles() -> Array:
	return [
		_marathon(),
		_plataea(),
		_tanagra(),
		_olpae(),
		_delium(),
		_mantinea(),
		_test_battle(),
	]

static func get_battle_names() -> Array:
	return [
		"Marathon 490 BCE",
		"Plataea 479 BCE",
		"Tanagra 457 BCE",
		"Olpae 426 BCE",
		"Delium 424 BCE",
		"Mantinea 418 BCE",
		"TEST - Contact",
	]

static func get_battle_descriptions() -> Array:
	return [
		"Greek hoplites face the larger Persian army on the plains of Marathon. The Greeks thin their center to match Persian frontage, betting everything on strong wings.",
		"The decisive battle ending the second Persian invasion. Spartans and Athenians face Persians and Greek collaborators in parallel engagements.",
		"First Peloponnesian War clash. Sparta and allies meet a larger Athenian force, but Thessalian cavalry may betray Athens mid-battle.",
		"Demosthenes redeems himself with a cunning ambush against a larger Spartan-led force at Olpae in Acarnania.",
		"Boeotian hoplites, led by an extra-deep Theban formation, surprise-attack the Athenians. Cavalry may appear from the flanks.",
		"The largest hoplite battle of the Peloponnesian War. Spartans and Tegeans face the Argive coalition with cavalry on both flanks.",
		"DEBUG: Small forces starting in contact. For testing combat, rally, and rout.",
	]

static func get_battle_player_names() -> Array:
	return [
		["Greek", "Persian"],
		["Greek", "Persian"],
		["Spartan", "Athenian"],
		["Spartan", "Athenian"],
		["Boeotian", "Athenian"],
		["Spartan", "Argive"],
		["Red Army", "Blue Army"],
	]

# ============ MARATHON 490 BCE ============
static func _marathon() -> BattleConfig:
	var b = BattleConfig.new()
	b.battle_name = "Marathon 490 BCE"
	b.year = "490 BCE"
	b.description = "The first great clash between Greece and Persia."

	# GREEK PLAYER
	var p1 = PlayerSetup.new()
	p1.player_name = "Greek"
	p1.edge = 1
	p1.rally_limit = 4
	p1.skirmish_factor = 0
	p1.first_setup = false
	p1.first_turn = true
	p1.has_initiative = true

	var w1 = WingSetup.new()
	w1.wing_name = "Center Wing"
	w1.color_name = "Red"
	w1.depth = Depth.SINGLE
	w1.placement = HPlacement.CENTER
	w1.units = [{"type": UType.HOPLITE, "count": 8, "leaders": 1}]
	p1.wings.append(w1)

	var w2 = WingSetup.new()
	w2.wing_name = "Left Wing"
	w2.color_name = "Pink"
	w2.depth = Depth.DOUBLE
	w2.placement = HPlacement.LEFT_OF_WING
	w2.placement_ref = "Center Wing"
	w2.units = [{"type": UType.HOPLITE, "count": 6, "leaders": 1}]
	p1.wings.append(w2)

	var w3 = WingSetup.new()
	w3.wing_name = "Right Wing"
	w3.color_name = "Orange"
	w3.depth = Depth.DOUBLE
	w3.placement = HPlacement.RIGHT_OF_WING
	w3.placement_ref = "Center Wing"
	w3.units = [{"type": UType.HOPLITE, "count": 6, "leaders": 2}]
	p1.wings.append(w3)

	p1.victory_conditions = ["24 VP and 5 more than Persian", "Reduce Persian Rally Limit to zero"]
	b.player1 = p1

	# PERSIAN PLAYER
	var p2 = PlayerSetup.new()
	p2.player_name = "Persian"
	p2.edge = 2
	p2.rally_limit = 2
	p2.skirmish_factor = 3
	p2.first_setup = true
	p2.first_turn = false
	p2.has_initiative = false

	var w4 = WingSetup.new()
	w4.wing_name = "Center Wing"
	w4.color_name = "Blue"
	w4.depth = Depth.DOUBLE
	w4.placement = HPlacement.CENTER
	w4.units = [
		{"type": UType.HEAVY_INFANTRY, "count": 4, "leaders": 2},
		{"type": UType.LIGHT_INFANTRY, "count": 12, "leaders": 0},
	]
	p2.wings.append(w4)

	var w5 = WingSetup.new()
	w5.wing_name = "Left Wing"
	w5.color_name = "Purple"
	w5.depth = Depth.DOUBLE
	w5.placement = HPlacement.LEFT_OF_WING
	w5.placement_ref = "Center Wing"
	w5.units = [{"type": UType.LIGHT_INFANTRY, "count": 6, "leaders": 0}]
	p2.wings.append(w5)

	var w6 = WingSetup.new()
	w6.wing_name = "Right Wing"
	w6.color_name = "Green"
	w6.depth = Depth.DOUBLE
	w6.placement = HPlacement.RIGHT_OF_WING
	w6.placement_ref = "Center Wing"
	w6.units = [{"type": UType.LIGHT_INFANTRY, "count": 6, "leaders": 0}]
	p2.wings.append(w6)

	p2.victory_conditions = ["28 VP", "Reduce Greek Rally Limit to zero"]
	b.player2 = p2

	b.special_rules = [
		{"name": "1,600 Yard Dash", "text": "The first time the Greek Player uses Strategos + Move, all Exhausted Greek Units attempt to Rally and all Wings perform two Move Phases in a row, ignoring enemy Skirmish Zones. Greeks forfeit this if any Units begin the Command Phase adjacent to a Persian Unit."},
	]
	return b

# ============ PLATAEA 479 BCE ============
static func _plataea() -> BattleConfig:
	var b = BattleConfig.new()
	b.battle_name = "Plataea 479 BCE"
	b.year = "479 BCE"
	b.description = "The decisive battle ending the second Persian invasion of Greece."

	var p1 = PlayerSetup.new()
	p1.player_name = "Greek"
	p1.edge = 1
	p1.rally_limit = 3
	p1.skirmish_factor = 1
	p1.first_setup = false
	p1.first_turn = false
	p1.has_initiative = true

	var w1 = WingSetup.new()
	w1.wing_name = "Spartan Wing"
	w1.color_name = "Orange"
	w1.depth = Depth.DOUBLE
	w1.placement = HPlacement.CUSTOM
	w1.special_notes = "Anywhere on the right side of the dotted line"
	w1.units = [
		{"type": UType.HOPLITE, "count": 8, "leaders": 2},
		{"type": UType.LIGHT_INFANTRY, "count": 4, "leaders": 0},
	]
	p1.wings.append(w1)

	var w2 = WingSetup.new()
	w2.wing_name = "Athenian Wing"
	w2.color_name = "Red"
	w2.depth = Depth.DOUBLE
	w2.placement = HPlacement.CUSTOM
	w2.special_notes = "Left of dotted line, 4 squares from dotted line"
	w2.units = [{"type": UType.HOPLITE, "count": 8, "leaders": 1}]
	p1.wings.append(w2)

	p1.victory_conditions = ["20 VP and 5 more than Persian", "Reduce Persian Rally Limit to zero"]
	b.player1 = p1

	var p2 = PlayerSetup.new()
	p2.player_name = "Persian"
	p2.edge = 2
	p2.rally_limit = 3
	p2.skirmish_factor = 4
	p2.first_setup = true
	p2.first_turn = true
	p2.has_initiative = false

	var w3 = WingSetup.new()
	w3.wing_name = "Persian Wing"
	w3.color_name = "Blue"
	w3.depth = Depth.TRIPLE
	w3.placement = HPlacement.CUSTOM
	w3.special_notes = "Left of the dotted line"
	w3.units = [
		{"type": UType.HEAVY_INFANTRY, "count": 4, "leaders": 2},
		{"type": UType.LIGHT_INFANTRY, "count": 14, "leaders": 0},
	]
	p2.wings.append(w3)

	var w4 = WingSetup.new()
	w4.wing_name = "Greek Allies Wing"
	w4.color_name = "Purple"
	w4.depth = Depth.DOUBLE
	w4.placement = HPlacement.CUSTOM
	w4.special_notes = "Right of dotted line, 4 squares from line"
	w4.units = [
		{"type": UType.HOPLITE, "count": 4, "leaders": 1},
		{"type": UType.HEAVY_INFANTRY, "count": 4, "leaders": 0},
	]
	p2.wings.append(w4)

	var w5 = WingSetup.new()
	w5.wing_name = "Cavalry Wing"
	w5.color_name = "Yellow"
	w5.depth = Depth.SINGLE
	w5.placement = HPlacement.CUSTOM
	w5.edge_distance = 2
	w5.special_notes = "2 squares from Edge 2, left of dotted line"
	w5.units = [{"type": UType.LIGHT_HORSE, "count": 4, "leaders": 0}]
	p2.wings.append(w5)

	p2.victory_conditions = ["15 VP and 5 more than Greek", "Reduce Greek Rally Limit to zero"]
	b.player2 = p2

	b.special_rules = [
		{"name": "Parallel Battles", "text": "Neither side may use a Strategos Command. Wings cannot cross the dotted line."},
		{"name": "Wicker Shields", "text": "While the Blue Wing's Skirmish Zone is intact, the Orange Wing cannot use the Bonus Command."},
		{"name": "Spartan Training", "text": "The Orange Wing fights at +1 CC when the Greek Player holds Initiative."},
	]
	return b

# ============ TANAGRA 457 BCE ============
static func _tanagra() -> BattleConfig:
	var b = BattleConfig.new()
	b.battle_name = "Tanagra 457 BCE"
	b.year = "457 BCE"
	b.description = "First Peloponnesian War: Sparta vs Athens with potential cavalry treachery."

	var p1 = PlayerSetup.new()
	p1.player_name = "Spartan"
	p1.edge = 1
	p1.rally_limit = 3
	p1.skirmish_factor = 0
	p1.first_setup = true
	p1.first_turn = false
	p1.has_initiative = true

	var w1 = WingSetup.new()
	w1.wing_name = "Allied Wing"
	w1.color_name = "Red"
	w1.depth = Depth.DOUBLE
	w1.placement = HPlacement.CENTER
	w1.units = [{"type": UType.HOPLITE, "count": 12, "leaders": 1}]
	p1.wings.append(w1)

	var w2 = WingSetup.new()
	w2.wing_name = "Spartan Wing"
	w2.color_name = "Orange"
	w2.depth = Depth.DOUBLE
	w2.placement = HPlacement.RIGHT_OF_WING
	w2.placement_ref = "Allied Wing"
	w2.units = [{"type": UType.HOPLITE, "count": 6, "leaders": 2}]
	p1.wings.append(w2)

	p1.extra_markers = {"O": 3}
	p1.victory_conditions = ["25 VP and 5 more than Athenian", "15 VP if only 1 Treason marker placed", "Reduce Athenian Rally Limit to zero"]
	b.player1 = p1

	var p2 = PlayerSetup.new()
	p2.player_name = "Athenian"
	p2.edge = 2
	p2.rally_limit = 3
	p2.skirmish_factor = 0
	p2.first_setup = false
	p2.first_turn = true
	p2.has_initiative = false

	var w3 = WingSetup.new()
	w3.wing_name = "Right Wing"
	w3.color_name = "Blue"
	w3.depth = Depth.DOUBLE
	w3.placement = HPlacement.CUSTOM
	w3.special_notes = "Right of dotted line"
	w3.units = [{"type": UType.HOPLITE, "count": 10, "leaders": 1}]
	p2.wings.append(w3)

	var w4 = WingSetup.new()
	w4.wing_name = "Left Wing"
	w4.color_name = "Green"
	w4.depth = Depth.DOUBLE
	w4.placement = HPlacement.CUSTOM
	w4.special_notes = "Left of dotted line"
	w4.units = [{"type": UType.HOPLITE, "count": 10, "leaders": 2}]
	p2.wings.append(w4)

	var w5 = WingSetup.new()
	w5.wing_name = "Cavalry Wing"
	w5.color_name = "Yellow"
	w5.depth = Depth.SINGLE
	w5.placement = HPlacement.CUSTOM
	w5.special_notes = "Left of Left Wing or Right of Right Wing"
	w5.units = [{"type": UType.LIGHT_HORSE, "count": 4, "leaders": 0}]
	p2.wings.append(w5)

	p2.extra_markers = {"X": 5}
	p2.victory_conditions = ["16 VP and 5 more than Spartan", "Reduce Spartan Rally Limit to zero"]
	b.player2 = p2

	b.special_rules = [
		{"name": "Spartan Training", "text": "The Orange Wing fights at +1 CC when the Spartan Player holds Initiative."},
		{"name": "Spartan Command", "text": "The Orange and Red Wings are considered one Wing when issuing Commands (but not for Support, Rout Checks, etc.)."},
		{"name": "Cavalry Switcheroo", "text": "Spartan secretly places 1-3 Treason markers in cup. Athenian places 1-5 Loyalty markers. Drawing a second Treason marker causes cavalry defection."},
	]
	return b

# ============ OLPAE 426 BCE ============
static func _olpae() -> BattleConfig:
	var b = BattleConfig.new()
	b.battle_name = "Olpae 426 BCE"
	b.year = "426 BCE"
	b.description = "Demosthenes springs a cunning ambush on the Spartan-led force."

	var p1 = PlayerSetup.new()
	p1.player_name = "Spartan"
	p1.edge = 1
	p1.rally_limit = 4
	p1.skirmish_factor = 2
	p1.first_setup = false
	p1.first_turn = true
	p1.has_initiative = false

	var w1 = WingSetup.new()
	w1.wing_name = "Left Wing"
	w1.color_name = "Orange"
	w1.depth = Depth.DOUBLE
	w1.placement = HPlacement.CUSTOM
	w1.special_notes = "Left of dotted line"
	w1.units = [{"type": UType.HOPLITE, "count": 8, "leaders": 2}]
	p1.wings.append(w1)

	var w2 = WingSetup.new()
	w2.wing_name = "Center Wing"
	w2.color_name = "Red"
	w2.depth = Depth.DOUBLE
	w2.placement = HPlacement.CUSTOM
	w2.special_notes = "Right of dotted line"
	w2.units = [{"type": UType.HOPLITE, "count": 6, "leaders": 1}]
	p1.wings.append(w2)

	var w3 = WingSetup.new()
	w3.wing_name = "Right Wing"
	w3.color_name = "Pink"
	w3.depth = Depth.DOUBLE
	w3.placement = HPlacement.RIGHT_OF_WING
	w3.placement_ref = "Center Wing"
	w3.units = [{"type": UType.HEAVY_INFANTRY, "count": 8, "leaders": 1}]
	p1.wings.append(w3)

	p1.victory_conditions = ["20 VP and 5 more than Athenian", "Reduce Athenian Rally Limit to zero"]
	b.player1 = p1

	var p2 = PlayerSetup.new()
	p2.player_name = "Athenian"
	p2.edge = 2
	p2.rally_limit = 4
	p2.skirmish_factor = 2
	p2.first_setup = true
	p2.first_turn = false
	p2.has_initiative = true

	var w4 = WingSetup.new()
	w4.wing_name = "Right Wing"
	w4.color_name = "Green"
	w4.depth = Depth.DOUBLE
	w4.placement = HPlacement.CUSTOM
	w4.special_notes = "Right of dotted line"
	w4.units = [{"type": UType.HOPLITE, "count": 6, "leaders": 1}]
	p2.wings.append(w4)

	var w5 = WingSetup.new()
	w5.wing_name = "Left Wing"
	w5.color_name = "Blue"
	w5.depth = Depth.DOUBLE
	w5.placement = HPlacement.CUSTOM
	w5.special_notes = "Left of dotted line"
	w5.units = [{"type": UType.HEAVY_INFANTRY, "count": 10, "leaders": 2}]
	p2.wings.append(w5)

	var w6 = WingSetup.new()
	w6.wing_name = "Ambush Wing"
	w6.color_name = "Purple"
	w6.depth = Depth.SINGLE
	w6.placement = HPlacement.CUSTOM
	w6.off_map = true
	w6.special_notes = "Off-map; enters via Ambush special rule. Remove Brittle Units before drawing."
	w6.units = [{"type": UType.HOPLITE, "count": 4, "leaders": 1}]
	p2.wings.append(w6)

	p2.extra_markers = {"X": 5, "O": 3}
	p2.victory_conditions = ["20 VP and 5 more than Spartan", "Reduce Spartan Rally Limit to zero"]
	b.player2 = p2

	b.special_rules = [
		{"name": "Spartan Training", "text": "The Orange Wing fights at +1 CC when the Spartan Player holds Initiative."},
		{"name": "Ambush Wing", "text": "Remove both Brittle Units from Purple mix before drawing. If Strategos is used, Ambush Wing does not take part."},
		{"name": "Ambush", "text": "Place 8 Ambush markers in cup. Each Athenian Initiative Phase (if adjacent to enemy, before first Initiative declaration), draw one marker. On first Initiative declaration, Ambush Wing enters adjacent to enemy Orange Wing in its rear at +1 CC for first turn."},
	]
	return b

# ============ DELIUM 424 BCE ============
static func _delium() -> BattleConfig:
	var b = BattleConfig.new()
	b.battle_name = "Delium 424 BCE"
	b.year = "424 BCE"
	b.description = "The Theban deep formation surprise-attacks the Athenians, with cavalry reinforcements."

	var p1 = PlayerSetup.new()
	p1.player_name = "Boeotian"
	p1.edge = 1
	p1.rally_limit = 4
	p1.skirmish_factor = 3
	p1.first_setup = false
	p1.first_turn = true
	p1.has_initiative = true

	var w1 = WingSetup.new()
	w1.wing_name = "Center Wing"
	w1.color_name = "Pink"
	w1.depth = Depth.DOUBLE
	w1.placement = HPlacement.CENTER
	w1.units = [{"type": UType.HOPLITE, "count": 8, "leaders": 1}]
	p1.wings.append(w1)

	var w2 = WingSetup.new()
	w2.wing_name = "Right Wing"
	w2.color_name = "Orange"
	w2.depth = Depth.TRIPLE
	w2.placement = HPlacement.RIGHT_OF_WING
	w2.placement_ref = "Center Wing"
	w2.special_notes = "Thebans - remove Brittle Units before drawing"
	w2.units = [{"type": UType.HOPLITE, "count": 9, "leaders": 2}]
	p1.wings.append(w2)

	var w3 = WingSetup.new()
	w3.wing_name = "Left Wing"
	w3.color_name = "Red"
	w3.depth = Depth.DOUBLE
	w3.placement = HPlacement.LEFT_OF_WING
	w3.placement_ref = "Center Wing"
	w3.units = [{"type": UType.HOPLITE, "count": 6, "leaders": 1}]
	p1.wings.append(w3)

	var w_cav = WingSetup.new()
	w_cav.wing_name = "Cavalry Wing"
	w_cav.color_name = "Yellow"
	w_cav.depth = Depth.SINGLE
	w_cav.placement = HPlacement.CUSTOM
	w_cav.off_map = true
	w_cav.special_notes = "Off-map; enters via Cavalry Ambush"
	w_cav.units = [{"type": UType.LIGHT_HORSE, "count": 6, "leaders": 0}]
	p1.wings.append(w_cav)

	p1.victory_conditions = ["20 VP and 5 more than Athenian", "Reduce Athenian Rally Limit to zero"]
	b.player1 = p1

	var p2 = PlayerSetup.new()
	p2.player_name = "Athenian"
	p2.edge = 2
	p2.rally_limit = 3
	p2.skirmish_factor = 0
	p2.first_setup = true
	p2.first_turn = false
	p2.has_initiative = false

	var w4 = WingSetup.new()
	w4.wing_name = "Left Wing"
	w4.color_name = "Purple"
	w4.depth = Depth.DOUBLE
	w4.placement = HPlacement.CUSTOM
	w4.special_notes = "Left of dotted line"
	w4.units = [{"type": UType.HOPLITE, "count": 6, "leaders": 1}]
	p2.wings.append(w4)

	var w5 = WingSetup.new()
	w5.wing_name = "Center Wing"
	w5.color_name = "Blue"
	w5.depth = Depth.DOUBLE
	w5.placement = HPlacement.CUSTOM
	w5.special_notes = "Right of dotted line"
	w5.units = [{"type": UType.HOPLITE, "count": 8, "leaders": 1}]
	p2.wings.append(w5)

	var w6 = WingSetup.new()
	w6.wing_name = "Right Wing"
	w6.color_name = "Green"
	w6.depth = Depth.DOUBLE
	w6.placement = HPlacement.RIGHT_OF_WING
	w6.placement_ref = "Center Wing"
	w6.units = [{"type": UType.HOPLITE, "count": 6, "leaders": 1}]
	p2.wings.append(w6)

	p2.extra_markers = {"X": 5, "O": 3}
	p2.victory_conditions = ["25 VP and 5 more than Boeotian", "Reduce Boeotian Rally Limit to zero"]
	# Athenians start with 11 VP from Defiance
	b.player2 = p2

	b.special_rules = [
		{"name": "Thebans", "text": "Remove Brittle Units from Orange mix. Any Unit in the contiguous formation may absorb Exhaustion (except when Flanked). Rally rolls of 1 don't Eliminate. Ignore Skirmish Zones. If all 9 Orange Units are Fresh in 3x3 square, +1 CC."},
		{"name": "Defiance", "text": "Athenians begin with 11 VP. Defiance markers drawn reduce/increase Athenian VP over the course of the battle."},
		{"name": "Cavalry Ambush", "text": "First time Boeotian declares Initiative, Yellow Wing enters from any non-numbered edge, moving 8 squares. Always fights at +1 CC."},
	]
	return b

# ============ MANTINEA 418 BCE ============
static func _mantinea() -> BattleConfig:
	var b = BattleConfig.new()
	b.battle_name = "Mantinea 418 BCE"
	b.year = "418 BCE"
	b.description = "The largest hoplite battle of the Peloponnesian War."

	var p1 = PlayerSetup.new()
	p1.player_name = "Spartan"
	p1.edge = 1
	p1.rally_limit = 4
	p1.skirmish_factor = 2
	p1.first_setup = true
	p1.first_turn = false
	p1.has_initiative = true

	var w1 = WingSetup.new()
	w1.wing_name = "Center Wing"
	w1.color_name = "Orange"
	w1.depth = Depth.DOUBLE
	w1.placement = HPlacement.CENTER
	w1.units = [{"type": UType.HOPLITE, "count": 12, "leaders": 2}]
	p1.wings.append(w1)

	var w2 = WingSetup.new()
	w2.wing_name = "Left Wing"
	w2.color_name = "Pink"
	w2.depth = Depth.DOUBLE
	w2.placement = HPlacement.LEFT_OF_WING
	w2.placement_ref = "Center Wing"
	w2.units = [{"type": UType.HOPLITE, "count": 6, "leaders": 1}]
	p1.wings.append(w2)

	var w3 = WingSetup.new()
	w3.wing_name = "Right Wing"
	w3.color_name = "Red"
	w3.depth = Depth.DOUBLE
	w3.placement = HPlacement.RIGHT_OF_WING
	w3.placement_ref = "Center Wing"
	w3.units = [{"type": UType.HOPLITE, "count": 10, "leaders": 1}]
	p1.wings.append(w3)

	var w_cav1 = WingSetup.new()
	w_cav1.wing_name = "Cavalry Wing"
	w_cav1.color_name = "Yellow"
	w_cav1.depth = Depth.SINGLE
	w_cav1.placement = HPlacement.CUSTOM
	w_cav1.special_notes = "Left of Left Wing (LH x2) and Right of Right Wing (LH x2)"
	w_cav1.units = [{"type": UType.LIGHT_HORSE, "count": 4, "leaders": 0}]
	p1.wings.append(w_cav1)

	p1.victory_conditions = ["25 VP", "Reduce Argive Rally Limit to zero"]
	b.player1 = p1

	var p2 = PlayerSetup.new()
	p2.player_name = "Argive"
	p2.edge = 2
	p2.rally_limit = 3
	p2.skirmish_factor = 2
	p2.first_setup = false
	p2.first_turn = true
	p2.has_initiative = false

	var w4 = WingSetup.new()
	w4.wing_name = "Center Wing"
	w4.color_name = "Blue"
	w4.depth = Depth.DOUBLE
	w4.placement = HPlacement.CENTER
	w4.units = [{"type": UType.HOPLITE, "count": 12, "leaders": 1}]
	p2.wings.append(w4)

	var w5 = WingSetup.new()
	w5.wing_name = "Left Wing"
	w5.color_name = "Purple"
	w5.depth = Depth.DOUBLE
	w5.placement = HPlacement.LEFT_OF_WING
	w5.placement_ref = "Center Wing"
	w5.units = [{"type": UType.HOPLITE, "count": 6, "leaders": 1}]
	p2.wings.append(w5)

	var w6 = WingSetup.new()
	w6.wing_name = "Right Wing"
	w6.color_name = "Green"
	w6.depth = Depth.DOUBLE
	w6.placement = HPlacement.RIGHT_OF_WING
	w6.placement_ref = "Center Wing"
	w6.units = [{"type": UType.HOPLITE, "count": 8, "leaders": 1}]
	p2.wings.append(w6)

	var w_cav2 = WingSetup.new()
	w_cav2.wing_name = "Cavalry Wing"
	w_cav2.color_name = "Brown"
	w_cav2.depth = Depth.SINGLE
	w_cav2.placement = HPlacement.CUSTOM
	w_cav2.special_notes = "Left of Left Wing (LH x2) and Right of Right Wing (LH x2)"
	w_cav2.units = [{"type": UType.LIGHT_HORSE, "count": 4, "leaders": 0}]
	p2.wings.append(w_cav2)

	p2.victory_conditions = ["21 VP and 5 more than Spartan", "Reduce Spartan Rally Limit to zero"]
	b.player2 = p2

	b.special_rules = [
		{"name": "Spartan Training", "text": "All Spartan Hoplite Units fight at +1 CC when the Spartan Player holds Initiative."},
	]
	return b


# ============ TEST BATTLE - CONTACT ============
static func _test_battle() -> BattleConfig:
	var b = BattleConfig.new()
	b.battle_name = "TEST - Contact"
	b.year = "DEBUG"
	b.description = "Small forces starting adjacent for testing combat and rally."

	var p1 = PlayerSetup.new()
	p1.player_name = "Red Army"
	p1.edge = 1
	p1.rally_limit = 4
	p1.skirmish_factor = 0
	p1.first_setup = true
	p1.first_turn = true
	p1.has_initiative = true

	var w1 = WingSetup.new()
	w1.wing_name = "Main Wing"
	w1.color_name = "Red"
	w1.depth = Depth.SINGLE
	w1.placement = HPlacement.CENTER
	w1.edge_distance = 10
	w1.units = [
		{"type": UType.HOPLITE, "count": 4, "leaders": 1},
		{"type": UType.HEAVY_INFANTRY, "count": 1, "leaders": 0},
	]
	p1.wings.append(w1)

	p1.victory_conditions = ["10 VP", "Reduce enemy Rally Limit to zero"]
	b.player1 = p1

	var p2 = PlayerSetup.new()
	p2.player_name = "Blue Army"
	p2.edge = 2
	p2.rally_limit = 4
	p2.skirmish_factor = 0
	p2.first_setup = false
	p2.first_turn = false
	p2.has_initiative = false

	var w2 = WingSetup.new()
	w2.wing_name = "Main Wing"
	w2.color_name = "Blue"
	w2.depth = Depth.SINGLE
	w2.placement = HPlacement.CENTER
	w2.edge_distance = 10
	w2.units = [
		{"type": UType.HOPLITE, "count": 4, "leaders": 1},
		{"type": UType.LIGHT_INFANTRY, "count": 1, "leaders": 0},
	]
	p2.wings.append(w2)

	p2.victory_conditions = ["10 VP", "Reduce enemy Rally Limit to zero"]
	b.player2 = p2

	b.special_rules = []
	return b
