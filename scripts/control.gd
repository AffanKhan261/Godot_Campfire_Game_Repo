extends Control

const SCROLL_SPEED = 60.0  # pixels per second, increase to scroll faster

@onready var v_box: VBoxContainer = $ScrollContainer/VBoxContainer

func _ready() -> void:
	# Start the credits below the screen
	v_box.position.y = get_viewport_rect().size.y

func _process(delta: float) -> void:
	# Scroll upward
	v_box.position.y -= SCROLL_SPEED * delta

	# Once all credits have scrolled off the top, go back to main menu
	if v_box.position.y + v_box.size.y < 0:
		get_tree().quit()

	# Allow player to skip credits
	if Input.is_action_just_pressed("exit"):
		get_tree().quit()
