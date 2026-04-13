extends RefCounted
class_name CombatResolver

# Unit Type Modifier Matrix (UTMM) - from player aid card
# Rows = Attacking unit type, Cols = Defending unit type
# Order: HO, HI, LI, LH
const UTMM = {
	0: {0: 0, 1: -1, 2: -2, 3: 1},   # HO attacking
	1: {0: 1, 1: 1, 2: -1, 3: 1},    # HI attacking
	2: {0: 2, 1: 2, 2: 1, 3: 2},     # LI attacking
	3: {0: 2, 1: 2, 2: 1, 3: 0},     # LH attacking
}

# Combat Results Table (CRT)
# Rows = CC (A+, A, B, C, D), Cols = modified die roll (-2 to 8+)
# Results: "DE" "DX" "AX" "EX" "AA"
const CRT = {
	"A+": {-2: "DE", -1: "DE", 0: "DE", 1: "DX", 2: "DX", 3: "DX", 4: "DX", 5: "EX", 6: "EX", 7: "EX", 8: "AX"},
	"A":  {-2: "DE", -1: "DE", 0: "DX", 1: "DX", 2: "DX", 3: "DX", 4: "EX", 5: "EX", 6: "EX", 7: "AX", 8: "AX"},
	"B":  {-2: "DE", -1: "DX", 0: "DX", 1: "DX", 2: "DX", 3: "EX", 4: "EX", 5: "EX", 6: "AX", 7: "AX", 8: "AX"},
	"C":  {-2: "DX", -1: "DX", 0: "DX", 1: "DX", 2: "EX", 3: "EX", 4: "EX", 5: "AX", 6: "AX", 7: "AX", 8: "AA"},
	"D":  {-2: "DX", -1: "DX", 0: "DX", 1: "EX", 2: "EX", 3: "EX", 4: "AX", 5: "AX", 6: "AX", 7: "AA", 8: "AA"},
}

const CC_ORDER = ["D", "C", "B", "A", "A+"]

static func cc_up(cc: String) -> String:
	var idx = CC_ORDER.find(cc)
	if idx < 0 or idx >= CC_ORDER.size() - 1:
		return cc
	return CC_ORDER[idx + 1]

static func cc_down(cc: String) -> String:
	var idx = CC_ORDER.find(cc)
	if idx <= 0:
		return cc
	return CC_ORDER[idx - 1]

static func modify_cc(base_cc: String, modifier: int) -> String:
	var cc = base_cc
	if modifier > 0:
		for i in range(modifier):
			cc = cc_up(cc)
	elif modifier < 0:
		for i in range(-modifier):
			cc = cc_down(cc)
	return cc

static func get_utmm_drm(attacker_type: int, defender_type: int) -> int:
	if UTMM.has(attacker_type) and UTMM[attacker_type].has(defender_type):
		return UTMM[attacker_type][defender_type]
	return 0

static func resolve_crt(cc: String, modified_roll: int) -> String:
	var clamped = clampi(modified_roll, -2, 8)
	if CRT.has(cc):
		return CRT[cc][clamped]
	return "EX"  # fallback

static func roll_d8() -> int:
	return randi_range(1, 8)
