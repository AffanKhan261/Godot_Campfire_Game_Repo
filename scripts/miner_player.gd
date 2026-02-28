extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea2D
@onready var attack_shape: CollisionShape2D = $AttackArea2D/CollisionShape2D

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

# How long the hitbox is active (damage window)
@export var attack_active_time: float = 0.12

# How long we stay in "attacking" state (animation lock window)
@export var attack_total_time: float = 0.30

@export var attack_cooldown: float = 0.25

var is_attacking: bool = false
var attack_cooldown_timer: float = 0.0

# ---------------- FACING (smooth) ----------------
var facing: int = 1
var facing_blend: float = 1.0
const FACING_SMOOTH: float = 18.0

# Reset jumps only when LANDING
var was_on_floor: bool = false

func _ready() -> void:
	was_on_floor = is_on_floor()

	# Tag hitbox so boss can detect it via area.is_in_group("player_attack")
	attack_area.add_to_group("player_attack")

	# IMPORTANT: attack rectangle OFF by default
	attack_area.monitoring = false
	attack_shape.disabled = true

func _physics_process(delta: float) -> void:
	_update_dash_timers(delta)
	_update_attack_timers(delta)

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
	# Don't override the attack animation while attacking
	if is_attacking:
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

func get_facing() -> int:
	return facing
