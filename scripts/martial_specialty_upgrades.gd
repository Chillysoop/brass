extends RefCounted

const PATHS := {
	"reversal_plate": {
		"power": {"label": "Retaliation", "gains": {"damage": 3, "recent_block_damage": 3}},
		"technique": {
			"label": "Fellow Guard",
			"properties": {"ally_guard": 2},
			"gains": {"damage": 1, "guard": 1, "ally_guard": 1, "recent_block_beats": 1},
		},
	},
	"rampart_rush": {
		"power": {
			"label": "Leading Edge",
			"properties": {"guard_break": 2},
			"gains": {"damage": 3, "guard_break": 2, "range": 10.0},
		},
		"technique": {
			"label": "Wide Arc",
			"gains": {"damage": 1, "guard": 1, "sweep_push_radius": 14.0, "sweep_push_force": 65.0},
		},
	},
	"convergence_pulse": {
		"power": {"label": "Density Spike", "gains": {"damage": 3, "convergence_damage_per_pull": 2}},
		"technique": {
			"label": "Wide Orbit",
			"properties": {"convergence_targets": 4},
			"gains": {"damage": 1, "convergence_radius": 20.0, "convergence_force": 36.0},
		},
	},
	"severing_tether": {
		"power": {"label": "Cut Loose", "gains": {"damage": 2, "isolation_damage": 4}},
		"technique": {
			"label": "Long Leash",
			"gains": {"damage": 1, "range": 25.0, "isolation_pull_force": 40.0, "isolation_distance": -5.0},
		},
	},
	"aegis_intercept": {
		"power": {
			"label": "Watchkeeper",
			"properties": {"windup_bonus": 2},
			"gains": {"damage": 3, "guard": 1, "windup_bonus": 2},
		},
		"technique": {
			"label": "Shield Detail",
			"properties": {"support": "party"},
			"gains": {"damage": 1, "guard": 1, "intercept_guard": 2, "intercept_beats": 1},
		},
	},
	"shieldshock": {
		"power": {
			"label": "Concussive",
			"properties": {"guard_break": 1},
			"gains": {"damage": 3, "recent_block_damage": 3, "guard_break": 1},
		},
		"technique": {
			"label": "Rolling Wave",
			"gains": {"damage": 1, "block_wave_damage": 2, "block_wave_radius": 18.0, "recent_block_beats": 1},
		},
	},
	"domino_maul": {
		"power": {
			"label": "Wrecking Head",
			"gains": {"damage": 4, "push": 25.0, "collision_bonus": 2},
		},
		"technique": {
			"label": "Ricochet",
			"properties": {"collision_chain_hops": 2},
			"gains": {"damage": 1, "collision_bonus": 1, "collision_chain_push": 45.0},
		},
	},
	"impact_driver": {
		"power": {"label": "Armor Punch", "gains": {"damage": 4, "guard_break": 3}},
		"technique": {
			"label": "Timely Blow",
			"properties": {"push": 340.0},
			"gains": {"damage": 2, "windup_bonus": 4, "push": 60.0},
		},
	},
	"phalanx_charge": {
		"power": {
			"label": "Running Point",
			"properties": {"lance_travel_bonus": 4},
			"gains": {"damage": 3, "range": 16.0, "lance_travel_bonus": 2},
		},
		"technique": {
			"label": "Broad Sweep",
			"gains": {"damage": 1, "charge_path_damage": 2, "charge_path_radius": 8.0},
		},
	},
	"recoil_thrust": {
		"power": {"label": "Long Point", "gains": {"damage": 3, "range": 16.0, "retreat": 12.0}},
		"technique": {
			"label": "Turnabout",
			"gains": {"damage": 1, "lance_return_bonus": 3, "lance_return_beats": 1},
		},
	},
	"pinpoint_lunge": {
		"power": {"label": "Locked Point", "gains": {"damage": 2, "repeat_target_damage": 4, "range": 8.0}},
		"technique": {
			"label": "Opening Line",
			"properties": {"mark_bonus": 4, "mark_beats": 3},
			"gains": {"damage": 1, "range": 18.0, "mark_bonus": 2},
		},
	},
	"vanishing_cut": {
		"power": {"label": "Finishing Step", "gains": {"damage": 3, "low_hp_bonus": 4}},
		"technique": {
			"label": "Chain Hunt",
			"gains": {"damage": 1, "range": 24.0, "duel_kill_bonus": 4},
		},
	},
}
