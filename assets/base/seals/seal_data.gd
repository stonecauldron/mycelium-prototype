class_name SealData
extends Resource

enum UnitFilter {
	NONE,
	JUVENILE,
	NO_MUTATION,
	FRONTMOST_SQUAD,
	REARMOST_SQUAD,
	FAVOURITE_BUFF,
	HAS_MUTATION,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## When true, at most one copy can be owned; excluded from future offers once owned.
@export var is_unique: bool = false

## Biomass granted at day start per owned copy.
@export var biomass_per_day: int = 0
## When true, each owned copy halves fresh plant cost (floor division, minimum 1).
@export var plant_cost_halve: bool = false
## When true, each owned copy halves fertilizer shop/plot cost (floor division, minimum 1).
@export var fertilizer_cost_halve: bool = false
## When true, each owned copy halves mutation shop/plot cost (floor division, minimum 1).
@export var mutation_cost_halve: bool = false
## Subtracted from spore growth days per owned copy.
@export var greenhouse_day_reduction: int = 0
## Added to max fertilizer stacks per owned copy (base stacks are 1).
@export var fertilizer_stack_bonus: int = 0
## Added to max mutation slots per owned copy (base slots are 1).
@export var mutation_slot_bonus: int = 0

@export var melee_damage_flat: int = 0
@export var ranged_damage_flat: int = 0
@export var max_hp_flat: int = 0
@export var spd_flat: int = 0

## When true, first hatch of the day stamps favourite_child_buff on those units.
@export var stamps_favourite_child: bool = false

## Multiplier applied when multiplier_filter matches (1.0 = unused).
@export var atk_multiplier: float = 1.0
@export var hp_multiplier: float = 1.0
@export var multiplier_filter: UnitFilter = UnitFilter.NONE
