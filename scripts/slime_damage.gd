extends Area2D

@onready var timer = $Timer

func _on_body_entered(body: Node2D) -> void:
	GlobalVar.HEALTH -= 200
	print(GlobalVar.HEALTH)
	GlobalVar.damage_anim_enabler = true
	await get_tree().create_timer(0.25).timeout
	GlobalVar.damage_anim_enabler = false
