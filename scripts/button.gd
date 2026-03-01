extends Area2D

signal button_pressed  # Signal that the wall will listen for

var activated: bool = false

func _on_body_entered(body: Node2D) -> void:
	if activated:
		return
	# Trigger for any player body that enters
	activated = true
	emit_signal("button_pressed")
	# Optional: change button appearance to show it's been pressed
	modulate = Color(0, 1, 0)  # turns green when pressed
