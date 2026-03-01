extends Area2D
@onready var label: Label = $Label

func _ready():
	label.visible = false

func _on_body_entered(body: Node2D) -> void:
	label.visible = true


func _on_body_exited(body: Node2D) -> void:
	label.visible = false
