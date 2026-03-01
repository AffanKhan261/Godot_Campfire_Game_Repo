extends Area2D

var redgate_anim_enabler = false
func _on_body_entered(body: Node2D) -> void:
	if GlobalVar.orb_count >= 10 and redgate_anim_enabler == false:
		$AnimatedSprite2D.play()
		redgate_anim_enabler = true
		await get_tree().create_timer(3).timeout
		get_tree().change_scene_to_file("res://scenes/level_4.tscn")
	else:
		pass
