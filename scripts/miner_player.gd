extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var jumps_left := GlobalVar.MAX_JUMPS

# Smooth facing/flip
var facing := 1
var facing_blend := 1.0
var FACING_SMOOTH := 18.0

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Reset jumps on floor
	if is_on_floor():
		jumps_left = GlobalVar.MAX_JUMPS

	# Wall contact grace timer (only while in air)
	if not is_on_floor() and is_on_wall_only():
		GlobalVar.WALL_STICK_TIMER = GlobalVar.WALL_STICK_TIME
	else:
		GlobalVar.WALL_STICK_TIMER = maxf(0.0, GlobalVar.WALL_STICK_TIMER - delta)

	# Input
	var direction := Input.get_axis("move_left", "move_right")
	var wants_dash := Input.is_action_pressed("speed_dash")

	# Horizontal movement
	var target_speed := (GlobalVar.DASH_SPEED if wants_dash else GlobalVar.SPEED)
	var target_vx := direction * target_speed

	if direction != 0:
		var accel := (GlobalVar.DASH_ACCEL if wants_dash else GlobalVar.WALK_ACCEL)
		velocity.x = move_toward(velocity.x, target_vx, accel * delta)
		facing = int(sign(direction))
	else:
		velocity.x = move_toward(velocity.x, 0.0, GlobalVar.FRICTION * delta)

	# Jump / double jump / wall jump
	if Input.is_action_just_pressed("jump"):
		# Wall jump has priority if we're touching a wall (or within grace window) and not on floor
		if not is_on_floor() and (is_on_wall_only() or GlobalVar.WALL_STICK_TIMER > 0.0):
			var n := get_wall_normal() # normal points away from the wall
			velocity.y = GlobalVar.WALL_JUMP_VELOCITY
			velocity.x = n.x * GlobalVar.WALL_JUMP_PUSH

			# After wall jumping, allow 1 more jump in the air (feels good)
			jumps_left = GlobalVar.MAX_JUMPS - 1

			# Update facing to the direction we're launched
			if absf(velocity.x) > 0.01:
				facing = int(sign(velocity.x))

			GlobalVar.WALL_STICK_TIMER = 0.0
		elif jumps_left > 0:
			# Normal jump / double jump
			if jumps_left == GlobalVar.MAX_JUMPS:
				velocity.y = GlobalVar.JUMP_VELOCITY
			else:
				velocity.y = GlobalVar.DOUBLE_JUMP_VELOCITY
			jumps_left -= 1

	# Smooth flip
	facing_blend = lerp(facing_blend, float(facing), 1.0 - exp(-FACING_SMOOTH * delta))
	animated_sprite.flip_h = (facing_blend < 0.0)

	# Animations
	if is_on_floor():
		if abs(velocity.x) < 5.0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("walk")
	else:
		if velocity.y < 0 and animated_sprite.sprite_frames.has_animation("jump"):
			animated_sprite.play("jump")
		elif velocity.y >= 0 and animated_sprite.sprite_frames.has_animation("fall"):
			animated_sprite.play("fall")

	move_and_slide()
