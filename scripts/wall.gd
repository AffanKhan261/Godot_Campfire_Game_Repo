extends StaticBody2D

func open_wall() -> void:
	# Hide the wall visually and disable its collision
	visible = false
	$CollisionShape2D.set_deferred("disabled", true)
