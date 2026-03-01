extends Area2D

@onready var animplayer = $"../AnimationPlayer"

var whitegate_anim_enabler = false
func _on_body_entered(body: Node2D) -> void:
	if whitegate_anim_enabler == false:
		$AnimatedSprite2D.play()
		whitegate_anim_enabler = true
		await get_tree().create_timer(3).timeout
		animplayer.play("fall")
		await get_tree().create_timer(0.4).timeout
		get_tree().change_scene_to_file("res://scenes/control.tscn")
	else:
		pass
