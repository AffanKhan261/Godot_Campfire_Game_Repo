extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK_MELEE, ATTACK_RANGED, STAGGER, DEAD }

@export var speed: float = 200.0
@export var accel: float = 2000.0
@export var gravity: float = 1200.0

@export var max_health: int = 300

# Distances (tune these)
@export var stop_distance: float = 140.0
@export var melee_range: float = 220.0
@export var ranged_range: float = 520.0

# Attack timings
@export var melee_cooldown: float = 1.2
@export var ranged_cooldown: float = 1.6
@export var melee_windup: float = 0.15
@export var melee_active_time: float = 0.20

# Damage (player dies instantly for testing by default below)
@export var contact_damage: int = 999999

# Damage intake tuning (prevents multi-hit spam)
@export var damage_i_frame_time: float = 0.15
var _last_hit_time_by_source: Dictionary = {}

var health: int
var state: State = State.IDLE

var player: CharacterBody2D = null

# Facing: -1 = left, +1 = right. Idle faces LEFT by default.
var facing: float = -1.0

@onready var attack_cooldown: Timer = $AttackCooldown
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@onready var hit_box: Area2D = get_node_or_null("HitBox")
@onready var hurt_box: Area2D = get_node_or_null("HurtBox")

# TEST MODE: if true, touching golem hitbox kills player instantly
@export var instant_kill_on_touch: bool = true

func _ready() -> void:
	health = max_health
	_play_idle()

	attack_cooldown.one_shot = true

	# HurtBox should always be able to receive hits
	if hurt_box:
		hurt_box.monitoring = true

	# HitBox setup
	if hit_box:
		# For attack-timed behavior you normally keep this off.
		# For testing instant death on touch, keep it on.
		hit_box.monitoring = instant_kill_on_touch

		# IMPORTANT: in your .tscn the HitBox/CollisionShape2D is disabled=true.
		# Enable it so body_entered can fire.
		var cs := hit_box.get_node_or_null("CollisionShape2D")
		if cs is CollisionShape2D:
			cs.disabled = false

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, accel * delta)
			_play_idle()

			if player != null:
				state = State.CHASE

		State.CHASE:
			_do_chase(delta)

		State.ATTACK_MELEE, State.ATTACK_RANGED, State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, accel * delta)

	move_and_slide()

# ---------------- CHASE (improved) ----------------
func _do_chase(delta: float) -> void:
	if player == null:
		state = State.IDLE
		return

	var dx: float = player.global_position.x - global_position.x
	var dist: float = absf(dx)

	# Face toward player
	if dist > 2.0:
		facing = signf(dx)
	anim.flip_h = facing > 0.0

	# Attack checks first
	if attack_cooldown.is_stopped():
		if dist <= melee_range:
			_start_melee_attack()
			return
		elif dist <= ranged_range:
			_start_ranged_attack()
			return

	# Movement with smooth slow-down band near stop_distance
	var desired_speed: float = speed
	if dist <= stop_distance:
		desired_speed = 0.0
	elif dist < stop_distance * 1.5:
		var t := (dist - stop_distance) / (stop_distance * 0.5) # 0..1
		desired_speed = lerpf(0.0, speed, clampf(t, 0.0, 1.0))

	var target_vx: float = facing * desired_speed
	velocity.x = move_toward(velocity.x, target_vx, accel * delta)

	if absf(velocity.x) > 5.0:
		_play_walk()
	else:
		_play_idle()

func _start_melee_attack() -> void:
	state = State.ATTACK_MELEE
	attack_cooldown.start(melee_cooldown)

	anim.flip_h = facing > 0.0
	anim.play("punch")

	# If we are instant-kill testing, leave hitbox always on and skip timing logic
	if instant_kill_on_touch:
		return

	# Enable hitbox briefly (timing-based)
	if hit_box:
		hit_box.monitoring = false
		await get_tree().create_timer(melee_windup).timeout
		if state == State.ATTACK_MELEE:
			hit_box.monitoring = true
			await get_tree().create_timer(melee_active_time).timeout
			hit_box.monitoring = false

func _start_ranged_attack() -> void:
	state = State.ATTACK_RANGED
	attack_cooldown.start(ranged_cooldown)

	anim.flip_h = facing > 0.0
	anim.play("axe_attack")
	# TODO projectile

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
	if state == State.STAGGER:
		state = State.CHASE if player != null else State.IDLE

func _play_idle() -> void:
	if anim.animation != "idle":
		anim.play("idle")

func _play_walk() -> void:
	if anim.animation != "walk":
		anim.play("walk")

# --- PLAYER ATTACK HITS BOSS HERE ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	if state == State.DEAD:
		return
	
	# Check if the area is either in the attack group OR is the Fireblast
	if not (area.is_in_group("player_attack") or area.name == "Fireblast"):
		return

	var id := area.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	var last := float(_last_hit_time_by_source.get(id, -9999.0))
	
	if now - last < damage_i_frame_time:
		return
	_last_hit_time_by_source[id] = now

	# Determine damage amount
	var dmg := 25 
	if area.name == "Fireblast":
		dmg = 100 # Give the superpower a higher damage value
	elif area.has_method("get_damage"):
		dmg = int(area.call("get_damage"))
	
	_take_damage(dmg)
# --- GOLEM HITBOX HITS PLAYER HERE ---
func _on_hit_box_body_entered(body: Node2D) -> void:
	print("HITBOX touched:", body.name)

	# TEST: kill player instantly on touch
	if instant_kill_on_touch and body is CharacterBody2D and body.has_method("take_damage"):
		body.call("take_damage", contact_damage)
		return

	# Normal behavior (when you turn off instant_kill_on_touch)
	if body == player and body.has_method("take_damage"):
		body.call("take_damage", contact_damage)

func _take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	health = max(health - amount, 0)
	print("Boss health:", health)

	if health == 0:
		state = State.DEAD
		if hit_box:
			hit_box.monitoring = false
		if hurt_box:
			hurt_box.monitoring = false
		anim.play("hurt") # replace with death animation if you have one
		return

	state = State.STAGGER
	anim.play("hurt")
