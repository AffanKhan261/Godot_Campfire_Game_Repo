extends CharacterBody2D

@export var speed: float = 100.0
@export var health: int = 50
@export var damage_to_player: int = 15

var direction: int = 1 # 1 for right, -1 for left

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_detector: RayCast2D = $WallDetector

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Movement
	velocity.x = direction * speed
	
	# Wall detection / Flipping
	if is_on_wall() or wall_detector.is_colliding():
		_flip()
		
	move_and_slide()
	sprite.play("idle") # Using idle since you mentioned that's all it has

func _flip() -> void:
	direction *= -1
	sprite.flip_h = (direction > 0)
	# Flip the raycast too so it looks the right way
	wall_detector.target_position.x *= -1

# --- RECEIVING DAMAGE ---
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free() # Enemy dies

# --- DAMAGING THE PLAYER ---
func _on_hit_box_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage_to_player)

# --- DETECTING PLAYER ATTACKS ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	# Detect regular Axe attack
	if area.is_in_group("player_attack"):
		var dmg = 25
		if area.get_parent().has_method("get_damage"):
			dmg = area.get_parent().get_damage()
		take_damage(dmg)
	
	# Detect Fireblast
	if area.name == "Fireblast":
		take_damage(100) # Superpower damage


func _on_hit_box_area_entered(area: Area2D) -> void:
	pass # Replace with function body.
