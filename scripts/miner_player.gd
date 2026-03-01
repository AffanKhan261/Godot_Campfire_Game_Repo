extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea2D
@onready var attack_shape: CollisionShape2D = $AttackArea2D/CollisionShape2D
@onready var fireblast_area: Area2D = $Fireblast
@onready var fireblast_shape: CollisionShape2D = $Fireblast/fireblast_shape
@onready var fireblast_anim: AnimatedSprite2D = $Fireblast/fireblast_anim




# ---------------- MOVE ----------------
const SPEED: float = 250.0
const WALK_ACCEL: float = 1800.0
const FRICTION: float = 2200.0

# ---------------- JUMP ----------------
const JUMP_VELOCITY: float = -400.0
const DOUBLE_JUMP_VELOCITY: float = -380.0
const MAX_JUMPS: int = 2
var JUMPS_LEFT: int = MAX_JUMPS

# ---------------- WALL JUMP -----------
const WALL_JUMP_PUSH: float = 420.0
const WALL_JUMP_VELOCITY: float = -420.0
const WALL_STICK_TIME: float = 0.12
var WALL_STICK_TIMER: float = 0.0

# ---------------- DASH (tap dash, action = speed_dash) ----------------
const DASH_SPEED: float = 600.0
const DASH_TIME: float = 0.18
const DASH_COOLDOWN: float = 0.5
const DASH_CANCELS_VERTICAL: bool = true
const DASH_KEEP_MOMENTUM: bool = true

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: int = 1 # -1 left, +1 right

# ---------------- ATTACK (action = attack, keybind F) ----------------
@export var attack_damage: int = 25
@export var attack_active_time: float = 0.12
@export var attack_total_time: float = 0.30
@export var attack_cooldown: float = 0.25

var is_attacking: bool = false
var attack_cooldown_timer: float = 0.0

# ---------------- HEALTH / DEATH ----------------
@export var max_health: int = 100
var health: int = 0

@export var invulnerable_time: float = 0.35
var _invuln_timer: float = 0.0

var is_dead: bool = false

# ---------------- TRANSFORMATION ----------------
var is_transitioning: bool = false # New: Tracks the "transform" animation
var magma_timer: float = 0.0
var magma_cooldown: float = 0.0


const MAGMA_DURATION: float = 10.0
const MAGMA_COOLDOWN_TIME: float = 10.0


# ---------------- FACING (smooth) ----------------
var facing: int = 1
var facing_blend: float = 1.0
const FACING_SMOOTH: float = 18.0

# Reset jumps only when LANDING
var was_on_floor: bool = false

func _ready() -> void:
	fireblast_area.monitoring = false
	fireblast_shape.disabled = true
	fireblast_area.visible = false
	
	fireblast_area.add_to_group("player_attack")
	
	was_on_floor = is_on_floor()

	health = max_health

	# Tag hitbox so boss can detect it via area.is_in_group("player_attack")
	attack_area.add_to_group("player_attack")

	# IMPORTANT: attack rectangle OFF by default
	attack_area.monitoring = false
	attack_shape.disabled = true

func _physics_process(delta: float) -> void:
	if is_dead:
		# Let death animation play, no movement/inputs
		move_and_slide()
		return

	# Handle Magma Timers
	if magma_cooldown > 0:
		magma_cooldown -= delta
	
	if GlobalVar.is_magma or is_transitioning:
	# If something else lowered our health, force it back up
		if GlobalVar.HEALTH < max_health: 
			GlobalVar.HEALTH = max_health
	
	if GlobalVar.is_magma and not is_transitioning:
		magma_timer -= delta
		if magma_timer <= 0:
			GlobalVar.is_magma = false
			magma_cooldown = MAGMA_COOLDOWN_TIME

	# Magma Input Logic
	if Input.is_action_just_pressed("magma_player"):
		if not GlobalVar.is_magma and not is_transitioning and magma_cooldown <= 0:
			is_transitioning = true
			animated_sprite.play("transform") # 'transform' with an S
			
			if not animated_sprite.animation_finished.is_connected(_on_tranform_done):
				animated_sprite.animation_finished.connect(_on_tranform_done, CONNECT_ONE_SHOT)
		
		elif GlobalVar.is_magma:
			# Manual exit
			GlobalVar.is_magma = false
			magma_cooldown = MAGMA_COOLDOWN_TIME
	
	# Fireblast Input
	if Input.is_action_just_pressed("fireblast") and GlobalVar.is_magma:
		animated_sprite.play("blast_position")
		_perform_fireblast()

	_update_dash_timers(delta)
	_update_attack_timers(delta)
	_update_invuln(delta)

	# Attack input (Input Map action name: "attack" bound to F)
	if Input.is_action_just_pressed("attack"):
		_try_attack()

	# Dash input
	if Input.is_action_just_pressed("speed_dash"):
		_try_start_dash()


	# Gravity (disabled during dash)
	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta

	# Wall contact grace timer (only while in air, and not dashing)
	if not is_on_floor() and not is_dashing and is_on_wall_only():
		WALL_STICK_TIMER = WALL_STICK_TIME
	else:
		WALL_STICK_TIMER = maxf(0.0, WALL_STICK_TIMER - delta)

	# Jump / double jump / wall jump
	if not is_dashing:
		_handle_jump()

	# Horizontal movement
	if is_dashing:
		_perform_dash_motion()
	elif not is_attacking:
		_handle_horizontal_movement(delta)
	else:
		# lock/slow movement during attack
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# Smooth flip
	_update_facing_and_flip(delta)

	# Animations
	_update_animations()

	move_and_slide()

	# ONLY reset jumps when you LAND on the ground
	_post_move_floor_reset()

func _start_transformation_sequence() -> void:
	is_transitioning = true
	animated_sprite.play("transform") # Spelled with 's' as requested
	
	# Wait for the animation to finish
	if not animated_sprite.animation_finished.is_connected(_on_transform_finished):
		animated_sprite.animation_finished.connect(_on_transform_finished, CONNECT_ONE_SHOT)

func _on_transform_finished() -> void:
	if is_transitioning:
		is_transitioning = false
		GlobalVar.is_magma = true
		magma_timer = MAGMA_DURATION

func _perform_fireblast() -> void:
	# 1. Visual Flip: Flip the entire area so the animation faces the right way
	# We use scale.x because flipping the sprite alone won't flip the hitbox shape
	fireblast_area.scale.x = float(facing)

	# 2. Play the animation
	fireblast_anim.play("FireBlast")

	# 3. Enable the blast
	fireblast_area.visible = true
	fireblast_area.monitoring = true
	fireblast_shape.disabled = false

	# 4. Position: Ensure it spawns in front of the player
	# absf ensures we always start with a positive offset, then multiply by facing
	fireblast_area.position.x = absf(fireblast_area.position.x) * float(facing)

	# 5. Timer to turn it off
	get_tree().create_timer(0.3).timeout.connect(func():
		fireblast_area.monitoring = false
		fireblast_shape.disabled = true
		fireblast_area.visible = false
	)

# ---------------- DAMAGE / DEATH ----------------
func take_damage(amount: int) -> void:
	# 1. Check if the player is dead
	if is_dead:
		return
	
	# 2. Check if the player is in Magma Mode or currently Transforming
	if GlobalVar.is_magma == true or is_transitioning == true:
		print("SKIBIDI OHIO")
		return # This stops the rest of the function from running!
		
	# 3. Check for standard invulnerability frames
	if _invuln_timer > 0.0:
		return

	# 4. If none of the above are true, actually take damage
	health = max(health - amount, 0)
	_invuln_timer = invulnerable_time

	if health <= 0:
		_die()



	# Optional: small knockback feel (tweak/remove if you want)
	# velocity.x = -float(facing) * 120.0



	# If you have a hurt animation, you can play it here safely:
	# if animated_sprite.sprite_frames.has_animation("hurt"):
	# 	animated_sprite.play("hurt")

func _die() -> void:
	is_dead = true
	is_attacking = false
	is_dashing = false

	# Turn off the attack hitbox so you can't damage while dead
	attack_area.monitoring = false
	attack_shape.disabled = true

	# Stop movement
	velocity = Vector2.ZERO

	# Play death animation if present
	if animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		# fallback
		animated_sprite.play("idle")

func _update_invuln(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer -= delta

# ---------------- ATTACK ----------------
func get_damage() -> int:
	return attack_damage

func _try_attack() -> void:
	if is_attacking:
		return
	if attack_cooldown_timer > 0.0:
		return
	if is_dashing:
		return
	if not animated_sprite.sprite_frames.has_animation("attack"):
		return

	is_attacking = true
	attack_cooldown_timer = attack_cooldown
	animated_sprite.play("attack")

	# Put hitbox on the correct side (in front of player)
	attack_area.position.x = absf(attack_area.position.x) * float(get_facing())

	# Enable hitbox ONLY during active frames
	attack_area.monitoring = true
	attack_shape.disabled = false

	get_tree().create_timer(attack_active_time).timeout.connect(func() -> void:
		attack_shape.disabled = true
		attack_area.monitoring = false
	)

	# End attack state after total time (so animations can resume)
	get_tree().create_timer(attack_total_time).timeout.connect(func() -> void:
		is_attacking = false
	)

func _update_attack_timers(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

# ---------------- FLOOR RESET ----------------
func _post_move_floor_reset() -> void:
	var on_floor_now: bool = is_on_floor()
	if on_floor_now and not was_on_floor:
		JUMPS_LEFT = MAX_JUMPS
	was_on_floor = on_floor_now

# ---------------- HORIZONTAL MOVEMENT ----------------
func _handle_horizontal_movement(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var target_vx: float = direction * SPEED

	if absf(direction) > 0.01:
		velocity.x = move_toward(velocity.x, target_vx, WALK_ACCEL * delta)
		facing = -1 if direction < 0.0 else 1
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

# ---------------- JUMP LOGIC ----------------
func _handle_jump() -> void:
	if not Input.is_action_just_pressed("jump"):
		return

	# Wall jump priority
	if not is_on_floor() and (is_on_wall_only() or WALL_STICK_TIMER > 0.0):
		var n: Vector2 = get_wall_normal()
		velocity.y = WALL_JUMP_VELOCITY
		velocity.x = n.x * WALL_JUMP_PUSH

		if absf(velocity.x) > 0.01:
			facing = -1 if velocity.x < 0.0 else 1

		WALL_STICK_TIMER = 0.0
		return

	# Normal jump / double jump
	if JUMPS_LEFT > 0:
		if JUMPS_LEFT == MAX_JUMPS:
			velocity.y = JUMP_VELOCITY
		else:
			velocity.y = DOUBLE_JUMP_VELOCITY
		JUMPS_LEFT -= 1

# ---------------- DASH ----------------
func _try_start_dash() -> void:
	if is_dashing or dash_cooldown_timer > 0.0:
		return
	if is_attacking:
		return

	var input_dir: float = Input.get_axis("move_left", "move_right")

	# Choose dash direction: input if held, otherwise facing
	if absf(input_dir) < 0.01:
		dash_dir = -1 if facing < 0 else 1
	else:
		dash_dir = -1 if input_dir < 0.0 else 1

	is_dashing = true
	dash_timer = DASH_TIME
	dash_cooldown_timer = DASH_COOLDOWN

	if DASH_CANCELS_VERTICAL:
		velocity.y = 0.0

	velocity.x = float(dash_dir) * DASH_SPEED

func _perform_dash_motion() -> void:
	velocity.x = float(dash_dir) * DASH_SPEED

func _end_dash() -> void:
	is_dashing = false
	if not DASH_KEEP_MOMENTUM:
		velocity.x = 0.0

func _update_dash_timers(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			_end_dash()

# ---------------- FACING / FLIP ----------------
func _update_facing_and_flip(delta: float) -> void:
	if is_dashing:
		facing = dash_dir

	facing_blend = lerp(facing_blend, float(facing), 1.0 - exp(-FACING_SMOOTH * delta))
	animated_sprite.flip_h = (facing_blend < 0.0)

# ---------------- ANIMATIONS ----------------
func _update_animations() -> void:



	if GlobalVar.HEALTH > 0:
		if GlobalVar.damage_anim_enabler == false:
			
			# 1. PRIORITY: The actual transformation animation
			if is_transitioning:
				return # Let the 'transform' animation play uninterrupted

			# 2. PRIORITY: Magma Mode (Spelled 'tranform')
			if GlobalVar.is_magma:
				if not is_on_floor():
					animated_sprite.play("tranform_jump")
				elif absf(velocity.x) > 10.0:
					animated_sprite.play("tranform_walk")
				else:
					animated_sprite.play("tranform_idle")
				return
			
			# 3. Normal Player animations...
			if is_attacking:
				return


			# Death has priority
			if is_dead:
				return

			# Use "walk" for dash
			if is_dashing:
				if animated_sprite.animation != "walk":
					animated_sprite.play("walk")
				return

			if is_on_floor():
				if absf(velocity.x) < 5.0:
					if animated_sprite.animation != "idle":
						animated_sprite.play("idle")
				else:
					if animated_sprite.animation != "walk":
						animated_sprite.play("walk")
			else:
				if velocity.y < 0.0 and animated_sprite.sprite_frames.has_animation("jump"):
					if animated_sprite.animation != "jump":
						animated_sprite.play("jump")
				elif velocity.y >= 0.0 and animated_sprite.sprite_frames.has_animation("fall"):
					if animated_sprite.animation != "fall":
						animated_sprite.play("fall")
		else:
			animated_sprite.play("damage")
	else:
		animated_sprite.play("death")
		is_dead = true
		await get_tree().create_timer(1.575).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func get_facing() -> int:
	return facing

func _on_tranform_done() -> void:
	if is_transitioning:
		is_transitioning = false
		GlobalVar.is_magma = true
		magma_timer = MAGMA_DURATION
