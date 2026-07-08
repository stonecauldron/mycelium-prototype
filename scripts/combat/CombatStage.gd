extends Node2D

const FLOOR_SURFACE_Y := 880.0

@onready var player_army: Army = $World/PlayerArmy
@onready var enemy_army: Army = $World/EnemyArmy


func _ready() -> void:
	player_army.begin_march()
