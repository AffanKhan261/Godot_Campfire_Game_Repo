extends Area2D

var lightgate_anim_enabler = false
func _on_body_entered(body: Node2D) -> void:
	if GlobalVar.orb_count >= 6 and lightgate_anim_enabler == false:
		pass
		$AnimatedSprite2D.play()
		lightgate_anim_enabler = true
	else:
		pass
