extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if GlobalVar.is_magma == false:
		GlobalVar.HEALTH = 0
	else:
		pass
