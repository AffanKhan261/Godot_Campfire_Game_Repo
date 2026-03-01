extends Node2D

const slime_speed = 60

var slime_direction = 1

@onready var right = $Right
@onready var left = $Left
@onready var sprite = $AnimatedSprite2D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if right.is_colliding():
		slime_direction = -1
		sprite.flip_h = false
	if left.is_colliding():
		slime_direction = 1
		sprite.flip_h = true
	position.x += slime_direction*slime_speed*delta
