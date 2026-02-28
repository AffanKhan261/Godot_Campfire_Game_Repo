extends Area2D

var magma_damage_check = true

func _on_body_entered(body: Node2D) -> void:
	magma_damage_check = true
	while GlobalVar.HEALTH > 0 and magma_damage_check == true:
		GlobalVar.HEALTH -= 100
		print(GlobalVar.HEALTH)
		GlobalVar.damage_anim_enabler = true
		await get_tree().create_timer(0.25).timeout
		GlobalVar.damage_anim_enabler = false
	print("out of loop check")



func _on_body_exited(body: Node2D) -> void:
	magma_damage_check = false
