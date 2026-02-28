extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK_MELEE, ATTACK_RANGED, STAGGER, DEAD }

@export var speed: float = 90.0
@export var accel: float = 900.0
@export var gravity: float = 1200.0

@export var max_health: int = 300

# Distances (tune these)
@export var stop_distance: float = 24.0          # How close boss tries to get before stopping
@export var melee_range: float = 70.0            # Must be >= stop_distance so it can actually hit
@export var ranged_range: float = 320.0

# Attack timings
@export var melee_cooldown: float = 1.2
@export var ranged_cooldown: float = 1.6
@export var melee_windup: float = 0.15           # how long before hitbox becomes active
@export var melee_active_time: float = 0.20      # how long hitbox stays active

# Placeholder damage (until you implement player health)
@export var contact_damage: int = 10

var health: int
var state: State = State.IDLE

# Your player is a CharacterBody2D
var player: CharacterBody2D = null

# Facing: -1 = left, +1 = right. Your idle faces LEFT by default.
var facing: float = -1.0

@onready var attack_cooldown: Timer = $AttackCooldown
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Optional nodes (only if you have them)
@onready var hit_box: Area2D = get_node_or_null("HitBox")
@onready var hurt_box: Area2D = get_node_or_null("HurtBox")

func _ready() -> void:
	health = max_health
	_play_idle()

	# Ensure timer is configured correctly
	attack_cooldown.one_shot = true

	# HitBox should only be active during melee frames
	if hit_box:
		hit_box.monitoring = false

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, accel * delta)
			_play_idle()

			# If we already have a target, start chasing
			if player != null:
				state = State.CHASE

		State.CHASE:
			_do_chase(delta)

		State.ATTACK_MELEE, State.ATTACK_RANGED, State.STAGGER:
			# No movement during attacks/stagger
			velocity.x = move_toward(velocity.x, 0.0, accel * delta)

	move_and_slide()

func _do_chase(delta: float) -> void:
	if player == null:
		state = State.IDLE
		return

	var dx: float = player.global_position.x - global_position.x
	var dist: float = absf(dx)

	# Update facing toward player while chasing
	if dist > 1.0:
		facing = signf(dx)

	# Because your art faces LEFT by default:
	# flip_h = true should make it face RIGHT.
	anim.flip_h = facing > 0.0

	# Move smoothly toward the player until "close enough"
	if dist <= stop_distance:
		# close enough: stop
		velocity.x = move_toward(velocity.x, 0.0, accel * delta)
	else:
		var target_vx: float = facing * speed
		velocity.x = move_toward(velocity.x, target_vx, accel * delta)

	# Animations while chasing
	if absf(velocity.x) > 5.0:
		_play_walk()
	else:
		_play_idle()

	# Attack if in range and off cooldown
	if attack_cooldown.is_stopped():
		if dist <= melee_range:
			_start_melee_attack()
		elif dist <= ranged_range:
			_start_ranged_attack()

func _start_melee_attack() -> void:
	state = State.ATTACK_MELEE
	attack_cooldown.start(melee_cooldown)

	# Face-to-face requirement:
	# You asked to attack in the opposite direction that the player is facing.
	# This assumes the player has a property `facing` (float/int: -1 left, +1 right)
	# If it doesn't exist, we fall back to facing the player.
	var desired_facing: float = facing

	# Try to read player's facing safely
	if player != null and player.has_method("get_facing"):
		desired_facing = float(player.call("get_facing")) * -1.0
	elif player != null and "facing" in player:
		desired_facing = float(player.get("facing")) * -1.0

	# If we got a usable value, apply it; otherwise keep current facing-to-player
	if desired_facing != 0.0:
		facing = signf(desired_facing)

	# Update sprite flip for attack direction (idle faces left)
	anim.flip_h = facing > 0.0

	anim.play("punch")

	# Enable hitbox briefly (simple timing-based approach)
	if hit_box:
		hit_box.monitoring = false
		await get_tree().create_timer(melee_windup).timeout
		# Only activate if still in melee attack state
		if state == State.ATTACK_MELEE:
			hit_box.monitoring = true
			await get_tree().create_timer(melee_active_time).timeout
			hit_box.monitoring = false

func _start_ranged_attack() -> void:
	state = State.ATTACK_RANGED
	attack_cooldown.start(ranged_cooldown)

	# Face toward player for ranged by default
	anim.flip_h = facing > 0.0
	anim.play("axe_attack")
	# TODO: spawn projectile later

func _on_attack_cooldown_timeout() -> void:
	if state == State.DEAD:
		return
	state = State.CHASE if player != null else State.IDLE

func _on_player_detector_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player = body
		if state == State.IDLE:
			state = State.CHASE

func _on_player_detector_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		state = State.IDLE

func _on_animated_sprite_2d_animation_finished() -> void:
	# Let animation end, but state is primarily controlled by cooldown.
	# Still, if we're staggered, go back to chase/idle at end of hurt.
	if state == State.STAGGER:
		state = State.CHASE if player != null else State.IDLE

func _play_idle() -> void:
	if anim.animation != "idle":
		anim.play("idle")

func _play_walk() -> void:
	if anim.animation != "walk":
		anim.play("walk")

func _on_hurt_box_area_entered(area: Area2D) -> void:
	# You don't have player attacks yet, so ignore everything unless you later
	# add attacks to a group called "player_attack".
	if not area.is_in_group("player_attack"):
		return
	_take_damage(25)

func _on_hit_box_body_entered(body: Node2D) -> void:
	if body == player:
		# Placeholder until you implement player health
		print("Boss hit player for %d" % contact_damage)

func _take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	health = max(health - amount, 0)

	if health == 0:
		state = State.DEAD
		if hit_box:
			hit_box.monitoring = false
		anim.play("hurt") # replace with death animation if you have one
		return

	state = State.STAGGER
	anim.play("hurt")
