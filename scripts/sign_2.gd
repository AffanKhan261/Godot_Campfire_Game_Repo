extends Area2D


func _on_sign_body_entered(body: Node2D) -> void:
	$Label.visible = true

func _on_sign_body_exited(body: Node2D) -> void:
	$Label.visible = false
