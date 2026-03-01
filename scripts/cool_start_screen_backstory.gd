extends Node2D
@onready var miner_player: CharacterBody2D = $MinerPlayer
@onready var player_cave_hunter: CharacterBody2D = $Player_Cave_Hunter
@onready var wall: StaticBody2D = $StaticBody2D
@onready var button: Area2D = $Area2D2

var active_player: CharacterBody2D

func _ready():
	button.button_pressed.connect(wall.open_wall)
	button.button_pressed.connect(_on_button_pressed)  # ← NEW
	active_player = miner_player
	_update_active_states()

func _input(event):
	if event.is_action_pressed("swap_player"):
		_toggle_players()

func _toggle_players():
	if active_player == miner_player:
		active_player = player_cave_hunter
	else:
		active_player = miner_player
	_update_active_states()

func _update_active_states():
	miner_player.set_physics_process(miner_player == active_player)
	miner_player.set_process_input(miner_player == active_player)
	
	player_cave_hunter.set_physics_process(player_cave_hunter == active_player)
	player_cave_hunter.set_process_input(player_cave_hunter == active_player)
	
	if has_node("Camera2D"):
		$Camera2D.reparent(active_player)
		$Camera2D.position = Vector2.ZERO

# ← NEW FUNCTION
func _on_button_pressed() -> void:
	# Switch control back to miner player
	active_player = miner_player
	_update_active_states()
	# Hide Player 2 and disable their collision
	player_cave_hunter.visible = false
	player_cave_hunter.set_collision_layer_value(1, false)
	player_cave_hunter.set_collision_mask_value(1, false)
