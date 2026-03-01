extends Node2D
@onready var miner_player: CharacterBody2D = $MinerPlayer
@onready var player_cave_hunter: CharacterBody2D = $Player_Cave_Hunter

var active_player: CharacterBody2D

func _ready():
	# Set the initial active player
	active_player = miner_player
	_update_active_states()

func _input(event):
	# Check for a specific swap action (define "swap" in Project Settings > Input Map)
	if event.is_action_pressed("swap_player"):
		_toggle_players()

func _toggle_players():
	# Switch the active player reference
	if active_player == miner_player:
		active_player = player_cave_hunter
	else:
		active_player = miner_player
	
	_update_active_states()

func _update_active_states():
	# Disable movement/input for the inactive player
	miner_player.set_physics_process(miner_player == active_player)
	miner_player.set_process_input(miner_player == active_player)
	
	player_cave_hunter.set_physics_process(player_cave_hunter == active_player)
	player_cave_hunter.set_process_input(player_cave_hunter == active_player)
	
	# Optional: Update camera to follow the active player
	if has_node("Camera2D"):
		$Camera2D.reparent(active_player)
		$Camera2D.position = Vector2.ZERO
