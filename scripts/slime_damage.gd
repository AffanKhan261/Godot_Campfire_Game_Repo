extends Area2D

@onready var timer = $Timer

func _on_body_entered(body: Node2D) -> void:
	GlobalVar.HEALTH -= 200
