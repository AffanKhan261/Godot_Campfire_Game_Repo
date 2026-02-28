extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var facing := 1 # 1 = right, -1 = left

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement
	var direction := Input.get_axis("move_left", "move_right")

	if direction != 0:
		velocity.x = direction * SPEED
		facing = sign(direction) # remember which way we're facing
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Flip sprite (Godot 4: flip_h flips horizontally)
	animated_sprite.flip_h = (facing == -1)

	# Animations
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("walk")
	else:
		# Optional: if you have these animations
		if velocity.y < 0:
			if animated_sprite.sprite_frames.has_animation("jump"):
				animated_sprite.play("jump")
		else:
			if animated_sprite.sprite_frames.has_animation("fall"):
				animated_sprite.play("fall")

	move_and_slide()
