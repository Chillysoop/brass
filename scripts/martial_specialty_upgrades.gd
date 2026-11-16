extends RefCounted

const PATHS := {
	"reversal_plate": {
		"power": {
			"label": "Retaliation", "gains": {"damage": 3, "recent_block_damage": 3},
			"stages": [
				{"name": "Shield Edge", "effects": {"guard_break": 3}},
				{"name": "Hard Answer", "effects": {"push": 350.0}},
				{"name": "Ringing Plate", "effects": {"block_wave_damage": 5, "block_wave_radius": 112.0}},
				{"name": "Breakwater", "effects": {"sweep_push_radius": 108.0, "sweep_push_force": 300.0}},
			],
		},
		"technique": {
			"label": "Fellow Guard",
			"properties": {"ally_guard": 2},
			"gains": {"damage": 1, "guard": 1, "ally_guard": 1, "recent_block_beats": 1},
			"stages": [
				{"name": "Shared Stance", "effects": {"harmony_guard": 3}},
				{"name": "Relief Rotation", "effects": {"mark_bonus": 5, "mark_beats": 3, "ally_only_mark": true}},
				{"name": "Last Bastion", "effects": {"bastion_block_threshold": 6, "bastion_party_guard": 5, "bastion_beats": 4}},
				{"name": "Ward Circle", "effects": {"support": "party"}},
			],
		},
	},
	"rampart_rush": {
		"power": {
			"label": "Leading Edge",
			"properties": {"guard_break": 2},
			"gains": {"damage": 3, "guard_break": 2, "range": 10.0},
			"stages": [
				{"name": "Breach the Line", "effects": {"windup_bonus": 5}},
				{"name": "Breaker Run", "effects": {"charge_path_damage": 5, "charge_path_radius": 38.0}},
				{"name": "Closing Shield", "effects": {"displaced_bonus": 6}},
				{"name": "Reverse Bulwark", "effects": {"charge_carry": true}},
			],
		},
		"technique": {
			"label": "Wide Arc",
			"gains": {"damage": 1, "guard": 1, "sweep_push_radius": 14.0, "sweep_push_force": 65.0},
			"stages": [
				{"name": "Escort Rush", "effects": {"ally_guard": 4}},
				{"name": "Signal Advance", "effects": {"mark_bonus": 5, "mark_beats": 4}},
				{"name": "Anchor the Line", "effects": {"support": "party"}},
				{"name": "Curling Advance", "effects": {"flank_charge": true}},
			],
		},
	},
	"convergence_pulse": {
		"power": {
			"label": "Density Spike", "gains": {"damage": 3, "convergence_damage_per_pull": 2},
			"stages": [
				{"name": "Cracked Core", "effects": {"guard_break": 3}},
				{"name": "Crushing Center", "effects": {"splash": 100.0, "splash_damage": 5}},
				{"name": "Shifting Mass", "effects": {"displaced_bonus": 6}},
				{"name": "Core Extraction", "effects": {"pull": 400.0}},
			],
		},
		"technique": {
			"label": "Wide Orbit",
			"properties": {"convergence_targets": 4},
			"gains": {"damage": 1, "convergence_radius": 20.0, "convergence_force": 36.0},
			"stages": [
				{"name": "Orbital Shield", "effects": {"guard": 4}},
				{"name": "Guiding Orbit", "effects": {"mark_bonus": 5, "mark_beats": 4, "ally_only_mark": true}},
				{"name": "Second Orbit", "effects": {"cluster_pull_radius": 185.0, "cluster_pull_force": 280.0}},
				{"name": "Shared Gravity", "effects": {"support": "party", "harmony_guard": 3}},
			],
		},
	},
	"severing_tether": {
		"power": {
			"label": "Cut Loose", "gains": {"damage": 2, "isolation_damage": 4},
			"stages": [
				{"name": "Barbed Hook", "effects": {"guard_break": 3}},
				{"name": "Cut to the Bone", "effects": {"low_hp_bonus": 6}},
				{"name": "Second Snare", "effects": {"repeat_target_damage": 5}},
				{"name": "Stranded Prey", "effects": {"mark_bonus": 7, "mark_beats": 4}},
			],
		},
		"technique": {
			"label": "Long Leash",
			"gains": {"damage": 1, "range": 25.0, "isolation_pull_force": 40.0, "isolation_distance": -5.0},
			"stages": [
				{"name": "Safety Line", "effects": {"ally_guard": 3}},
				{"name": "Spotter's Line", "effects": {"mark_bonus": 4, "mark_beats": 4}},
				{"name": "Give Ground", "effects": {"retreat": 72.0}},
				{"name": "Cast the Net", "effects": {"cluster_pull_radius": 160.0, "cluster_pull_force": 390.0}},
			],
		},
	},
	"aegis_intercept": {
		"power": {
			"label": "Watchkeeper",
			"properties": {"windup_bonus": 2},
			"gains": {"damage": 3, "guard": 1, "windup_bonus": 2},
			"stages": [
				{"name": "Open the Guard", "effects": {"guard_break": 3}},
				{"name": "Answer the Blow", "effects": {"recent_block_damage": 5, "recent_block_beats": 3}},
				{"name": "Watchkeeper's Bell", "effects": {"block_wave_damage": 5, "block_wave_radius": 105.0}},
				{"name": "Clear Approach", "effects": {"sweep_push_radius": 105.0, "sweep_push_force": 335.0}},
			],
		},
		"technique": {
			"label": "Shield Detail",
			"properties": {"support": "party"},
			"gains": {"damage": 1, "guard": 1, "intercept_guard": 2, "intercept_beats": 1},
			"stages": [
				{"name": "Guard in Step", "effects": {"harmony_guard": 3}},
				{"name": "Escort Signal", "effects": {"mark_bonus": 5, "mark_beats": 4, "ally_only_mark": true}},
				{"name": "Take Point", "effects": {"guard_bonus": 5}},
				{"name": "Locked Shields", "effects": {"bastion_block_threshold": 7, "bastion_party_guard": 5, "bastion_beats": 4}},
			],
		},
	},
	"shieldshock": {
		"power": {
			"label": "Concussive",
			"properties": {"guard_break": 1},
			"gains": {"damage": 3, "recent_block_damage": 3, "guard_break": 1},
			"stages": [
				{"name": "Cut the Windup", "effects": {"windup_bonus": 6}},
				{"name": "Rebounding Shield", "effects": {"push": 380.0}},
				{"name": "Brace Aftershock", "effects": {"guard": 5}},
				{"name": "Bell Tower Blow", "effects": {"collision_bonus": 6}},
			],
		},
		"technique": {
			"label": "Rolling Wave",
			"gains": {"damage": 1, "block_wave_damage": 2, "block_wave_radius": 18.0, "recent_block_beats": 1},
			"stages": [
				{"name": "Shield the Wounded", "effects": {"guard": 4, "ally_guard": 3}},
				{"name": "Rolling Formation", "effects": {"harmony_guard": 3}},
				{"name": "Breaking Wave", "effects": {"sweep_push_radius": 120.0, "sweep_push_force": 360.0}},
				{"name": "Citadel Echo", "effects": {"bastion_block_threshold": 7, "bastion_party_guard": 6, "bastion_beats": 4}},
			],
		},
	},
	"domino_maul": {
		"power": {
			"label": "Wrecking Head",
			"gains": {"damage": 4, "push": 25.0, "collision_bonus": 2},
			"stages": [
				{"name": "Split Rivet", "effects": {"guard_break": 4}},
				{"name": "Battering Beat", "effects": {"windup_bonus": 6}},
				{"name": "Falling Debris", "effects": {"splash": 100.0, "splash_damage": 7}},
				{"name": "Demolition Run", "effects": {"displaced_bonus": 8}},
			],
		},
		"technique": {
			"label": "Ricochet",
			"properties": {"collision_chain_hops": 2},
			"gains": {"damage": 1, "collision_bonus": 1, "collision_chain_push": 45.0},
			"stages": [
				{"name": "Aim the Wreckage", "effects": {"mark_bonus": 6, "mark_beats": 4}},
				{"name": "Scatter the Line", "effects": {"sweep_push_radius": 105.0, "sweep_push_force": 350.0}},
				{"name": "Backstep Hammer", "effects": {"retreat": 64.0}},
				{"name": "Brace for Impact", "effects": {"collision_chain_hops": 3, "guard": 4, "support": "party"}},
			],
		},
	},
	"impact_driver": {
		"power": {
			"label": "Armor Punch", "gains": {"damage": 4, "guard_break": 3},
			"stages": [
				{"name": "Braced Piston", "effects": {"guard_bonus": 5}},
				{"name": "Exposed Joint", "effects": {"mark_bonus": 5, "mark_beats": 3}},
				{"name": "Impact Sparks", "effects": {"splash": 92.0, "splash_damage": 7}},
				{"name": "Recoil Piston", "effects": {"retreat": 70.0}},
			],
		},
		"technique": {
			"label": "Timely Blow",
			"properties": {"push": 340.0},
			"gains": {"damage": 2, "windup_bonus": 4, "push": 60.0},
			"stages": [
				{"name": "Covering Impact", "effects": {"ally_guard": 4}},
				{"name": "Unsteady Footing", "effects": {"displaced_bonus": 6}},
				{"name": "Driven Collision", "effects": {"collision_bonus": 6}},
				{"name": "Piston Sweep", "effects": {"sweep_push_radius": 128.0, "sweep_push_force": 430.0}},
			],
		},
	},
	"phalanx_charge": {
		"power": {
			"label": "Running Point",
			"properties": {"lance_travel_bonus": 4},
			"gains": {"damage": 3, "range": 16.0, "lance_travel_bonus": 2},
			"stages": [
				{"name": "Lance Tip", "effects": {"guard_break": 3}},
				{"name": "First to Strike", "effects": {"windup_bonus": 5}},
				{"name": "Shoulder Check", "effects": {"push": 430.0}},
				{"name": "Rally the Charge", "effects": {"lance_return_bonus": 7, "lance_return_beats": 4}},
			],
		},
		"technique": {
			"label": "Broad Sweep",
			"gains": {"damage": 1, "charge_path_damage": 2, "charge_path_radius": 8.0},
			"stages": [
				{"name": "Armored Rider", "effects": {"guard": 4, "ally_guard": 3}},
				{"name": "Banner Charge", "effects": {"mark_bonus": 5, "mark_beats": 4}},
				{"name": "Outflank", "effects": {"flank_charge": true}},
				{"name": "Part the Ranks", "effects": {"sweep_push_radius": 116.0, "sweep_push_force": 360.0}},
			],
		},
	},
	"recoil_thrust": {
		"power": {
			"label": "Long Point", "gains": {"damage": 3, "range": 16.0, "retreat": 12.0},
			"stages": [
				{"name": "Armored Thrust", "effects": {"guard_break": 3}},
				{"name": "Covered Retreat", "effects": {"guard": 4}},
				{"name": "Crossing Points", "effects": {"splash": 94.0, "splash_damage": 6}},
				{"name": "Returning Blade", "effects": {"dash_followup_damage": 7, "dash_followup_beats": 3}},
			],
		},
		"technique": {
			"label": "Turnabout",
			"gains": {"damage": 1, "lance_return_bonus": 3, "lance_return_beats": 1},
			"stages": [
				{"name": "Signal the Turn", "effects": {"mark_bonus": 4, "mark_beats": 3, "ally_only_mark": true}},
				{"name": "Clear a Shot", "effects": {"ranged_followup_bonus": 6, "ranged_followup_beats": 3}},
				{"name": "Clear the Lane", "effects": {"sweep_push_radius": 108.0, "sweep_push_force": 335.0}},
				{"name": "Rear Guard", "effects": {"guard": 5, "support": "party"}},
			],
		},
	},
	"pinpoint_lunge": {
		"power": {
			"label": "Locked Point", "gains": {"damage": 2, "repeat_target_damage": 4, "range": 8.0},
			"stages": [
				{"name": "Through the Seam", "effects": {"guard_break": 3}},
				{"name": "Find the Wound", "effects": {"low_hp_bonus": 5}},
				{"name": "Cutting Curve", "effects": {"charge_path_damage": 5, "charge_path_radius": 38.0}},
				{"name": "Unbroken Pursuit", "effects": {"duel_kill_bonus": 8}},
			],
		},
		"technique": {
			"label": "Opening Line",
			"properties": {"mark_bonus": 4, "mark_beats": 3},
			"gains": {"damage": 1, "range": 18.0, "mark_bonus": 2},
			"stages": [
				{"name": "Covering Lunge", "effects": {"ally_guard": 3}},
				{"name": "Cut and Go", "effects": {"retreat": 58.0}},
				{"name": "Side Slice", "effects": {"splash": 96.0, "splash_damage": 5}},
				{"name": "Open the Circle", "effects": {"sweep_push_radius": 104.0, "sweep_push_force": 410.0}},
			],
		},
	},
	"vanishing_cut": {
		"power": {
			"label": "Finishing Step", "gains": {"damage": 3, "low_hp_bonus": 4},
			"stages": [
				{"name": "Shadow Breach", "effects": {"guard_break": 4}},
				{"name": "Hunt the Wound", "effects": {"repeat_target_damage": 6}},
				{"name": "Twilight Cleave", "effects": {"splash": 100.0, "splash_damage": 8}},
				{"name": "Fatal Afterimage", "effects": {"blink_on_hit_retreat": 92.0, "blink_echo_damage": 10}},
			],
		},
		"technique": {
			"label": "Chain Hunt",
			"gains": {"damage": 1, "range": 24.0, "duel_kill_bonus": 4},
			"stages": [
				{"name": "Shadow Mantle", "effects": {"guard": 4}},
				{"name": "Call the Quarry", "effects": {"mark_bonus": 5, "mark_beats": 4, "ally_only_mark": true}},
				{"name": "Fading Footwork", "effects": {"retreat": 65.0}},
				{"name": "Phantom Pursuit", "effects": {"dash_followup_damage": 7, "dash_followup_beats": 3}},
			],
		},
	},
}
