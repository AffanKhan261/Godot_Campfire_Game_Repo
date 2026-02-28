extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK_MELEE, ATTACK_RANGED, STAGGER, DEAD }

@export var speed: float = 90.0
@export var gravity: float = 1200.0
@export var max_health: int = 300
@export var melee_range: float = 80.0
@export var ranged_range: float = 320.0

# Boss damage tuning (placeholder values)
@export var contact_damage: int = 10

var health: int
var state: State = State.IDLE
var player: CharacterBody2D = null

@onready var attack_cooldown: Timer = $AttackCooldown
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Optional nodes (only if you have them in the scene)
@onready var hurt_box: Area2D = get_node_or_null("HurtBox")
@onready var hit_box: Area2D = get_node_or_null("HitBox")

func _ready() -> void:
	health = max_health
	_play_idle()

	# HitBox should NOT be active all the time (only during attacks)
	if hit_box:
		hit_box.monitoring = false

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			_play_idle()

		State.CHASE:
			_do_chase(delta)

		State.ATTACK_MELEE, State.ATTACK_RANGED, State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)

	move_and_slide()

func _do_chase(_delta: float) -> void:
	if player == null:
		state = State.IDLE
		return

	var dx: float = player.global_position.x - global_position.x
	var dir: float = signf(dx)

	velocity.x = dir * speed
	anim.flip_h = dir < 0.0

	if absf(velocity.x) > 1.0:
		_play_walk()
	else:
		_play_idle()

	var dist: float = absf(dx)
	if attack_cooldown.is_stopped():
		if dist <= melee_range:
			_start_melee_attack()
		elif dist <= ranged_range:
			_start_ranged_attack()

func _start_melee_attack() -> void:
	state = State.ATTACK_MELEE
	attack_cooldown.start(1.2)
	anim.play("punch")

	# Optional: enable hitbox briefly (very rough placeholder timing)
	if hit_box:
		hit_box.monitoring = true
		await get_tree().create_timer(0.2).timeout
		hit_box.monitoring = false

func _start_ranged_attack() -> void:
	state = State.ATTACK_RANGED
	attack_cooldown.start(1.6)
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
	if state in [State.ATTACK_MELEE, State.ATTACK_RANGED, State.STAGGER]:
		state = State.CHASE if player != null else State.IDLE

func _play_idle() -> void:
	if anim.animation != "idle":
		anim.play("idle")

func _play_walk() -> void:
	if anim.animation != "walk":
		anim.play("walk")

# Called when something enters the boss HurtBox (player attack goes here later)
func _on_hurt_box_area_entered(area: Area2D) -> void:
	# Placeholder: when you implement player attacks, check groups/layers here.
	# For now, ignore unless you deliberately add attackers to a group.
	if not area.is_in_group("player_attack"):
		return

	_take_damage(25)

# Called when the boss HitBox hits the player
func _on_hit_box_body_entered(body: Node2D) -> void:
	if body == player:
		# Placeholder: call your player's damage method if you have one.
		# Example later: body.take_damage(contact_damage)
		print("Boss hit player for %d" % contact_damage)

func _take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	health = max(health - amount, 0)

	if health == 0:
		state = State.DEAD
		anim.play("hurt") # you can replace with a death anim later
		if hit_box:
			hit_box.monitoring = false
		set_physics_process(false)
		return

	state = State.STAGGER
	anim.play("hurt")
