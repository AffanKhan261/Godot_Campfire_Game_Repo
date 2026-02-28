extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const SPEED := 300.0
const DASH_SPEED := 520.0
const DASH_ACCEL := 2200.0
const WALK_ACCEL := 1800.0
const FRICTION := 2200.0

const JUMP_VELOCITY := -400.0
const DOUBLE_JUMP_VELOCITY := -380.0
const MAX_JUMPS := 2

# Wall jump
const WALL_JUMP_PUSH := 420.0     # horizontal push away from wall
const WALL_JUMP_VELOCITY := -420.0
const WALL_STICK_TIME := 0.12     # grace time after touching a wall
var wall_stick_timer := 0.0

var jumps_left := MAX_JUMPS

# Smooth facing/flip
var facing := 1
var facing_blend := 1.0
const FACING_SMOOTH := 18.0

# Phase mode
const WALL_LAYER_BIT := 0 # Usually Layer 1 is index 0. Check your TileMap Collision Layer!
var is_phasing := false


func _physics_process(delta: float) -> void:
	# 1. PHASE TOGGLE (Runs only the moment Q is pressed)
	if Input.is_action_just_pressed("phase_mode"):
		print("Should be phasing")
		is_phasing = !is_phasing
		
		if is_phasing:
			set_collision_mask_value(1, false) 
			modulate.a = 0.5                  
			# Your World layer is Z Index 1. 
			# We set player to 0 to be BEHIND walls but in FRONT of background.
			z_index = 0                       
		else:
			set_collision_mask_value(1, true)  
			modulate.a = 1.0                   
			# Set player to 2 to be clearly in FRONT of the World layer.
			z_index = 2                # Move in FRONT of the TileMap

	# 2. GRAVITY & VERTICAL MOVEMENT
	if not is_phasing:
		# Normal Gravity
		if not is_on_floor():
			velocity += get_gravity() * delta
		
		# Reset jumps on floor
		if is_on_floor():
			jumps_left = MAX_JUMPS
	else:
		# "Noclip" Vertical Movement: Use Jump key to go up, otherwise stay still
		var v_dir := 0.0
		if Input.is_action_pressed("jump"):
			v_dir = -1.0
		# If you want a 'down' key, you can add: v_dir = Input.get_axis("jump", "ui_down")
		
		velocity.y = move_toward(velocity.y, v_dir * SPEED, DASH_ACCEL * delta)

	# 3. WALL CONTACT GRACE TIMER
	if not is_on_floor() and is_on_wall_only():
		wall_stick_timer = WALL_STICK_TIME
	else:
		wall_stick_timer = maxf(0.0, wall_stick_timer - delta)

	# 4. HORIZONTAL MOVEMENT
	var direction := Input.get_axis("move_left", "move_right")
	var wants_dash := Input.is_action_pressed("speed_dash")
	var target_speed := (DASH_SPEED if wants_dash else SPEED)
	var target_vx := direction * target_speed

	if direction != 0:
		var accel := (DASH_ACCEL if wants_dash else WALK_ACCEL)
		velocity.x = move_toward(velocity.x, target_vx, accel * delta)
		facing = int(sign(direction))
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# 5. JUMP / DOUBLE JUMP / WALL JUMP (Only allowed when NOT phasing)
	if not is_phasing and Input.is_action_just_pressed("jump"):
		if not is_on_floor() and (is_on_wall_only() or wall_stick_timer > 0.0):
			var n := get_wall_normal()
			velocity.y = WALL_JUMP_VELOCITY
			velocity.x = n.x * WALL_JUMP_PUSH
			jumps_left = MAX_JUMPS - 1
			if absf(velocity.x) > 0.01:
				facing = int(sign(velocity.x))
			wall_stick_timer = 0.0
		elif jumps_left > 0:
			if jumps_left == MAX_JUMPS:
				velocity.y = JUMP_VELOCITY
			else:
				velocity.y = DOUBLE_JUMP_VELOCITY
			jumps_left -= 1

	# 6. VISUALS (Smooth Flip & Animations)
	facing_blend = lerp(facing_blend, float(facing), 1.0 - exp(-FACING_SMOOTH * delta))
	animated_sprite.flip_h = (facing_blend < 0.0)

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

	# 7. EXECUTE MOVEMENT
	move_and_slide()
