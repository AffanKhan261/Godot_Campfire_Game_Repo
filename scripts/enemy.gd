extends CharacterBody2D

const SPEED = 60.0
const GRAVITY = 980.0

@export var max_health: int = 50
@export var damage_to_player: int = 100
var health: int = 50
var direction = 1

# Updated names to match your Slime image (No underscores)
@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Apply Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# Wall Detection Logic
	if direction == 1 and (ray_cast_right.is_colliding() or is_on_wall()):
		direction = -1
		animated_sprite.flip_h = true
	elif direction == -1 and (ray_cast_left.is_colliding() or is_on_wall()):
		direction = 1
		animated_sprite.flip_h = false
	
	velocity.x = direction * SPEED
	move_and_slide()

# --- DAMAGE LOGIC ---
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()

func _on_hurt_box_area_entered(area: Area2D) -> void:
	# Detect Axe or Fireblast
	if area.is_in_group("player_attack") or area.name == "Fireblast":
		var dmg = 100 if area.name == "Fireblast" else 25
		take_damage(dmg)

func _on_hit_box_body_entered(body: Node2D) -> void:
	# Check if the thing we hit is the player
	if body.has_method("take_damage"):
		# Don't deal damage during magma mode
		if GlobalVar.is_magma:
			return
		print("Enemy hit the player!") # Debug check
		GlobalVar.HEALTH -= 300
		_trigger_player_hurt_anim()

func _trigger_player_hurt_anim() -> void:
	GlobalVar.damage_anim_enabler = true
	await get_tree().create_timer(0.25).timeout
	GlobalVar.damage_anim_enabler = false
