extends Area2D

var lightgate_anim_enabler = false
func _on_body_entered(body: Node2D) -> void:
	if GlobalVar.orb_count >= 6 and lightgate_anim_enabler == false:
		$AnimatedSprite2D.play()
		lightgate_anim_enabler = true
		await get_tree().create_timer(3).timeout
		get_tree().change_scene_to_file("res://scenes/level_2.tscn")
	else:
		pass
