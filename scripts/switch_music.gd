extends Area2D

@onready var music1 = $"../AudioStreamPlayer"
@onready var music2 = $"../AudioStreamPlayer2"

func _on_body_entered(body: Node2D) -> void:
	music1.autoplay = false
	music1.stop()
	music2.play()
	music2.autoplay = true
