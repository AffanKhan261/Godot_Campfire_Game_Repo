extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings: Panel = $Settings
@onready var HTPpanel: Panel = $Settings/HowToPlay/Panel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	main_buttons.visible = true
	settings.visible = false
	HTPpanel.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	GlobalVar.HEALTH = 1000.0
	get_tree().change_scene_to_file("res://scenes/level_1.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_back_button_pressed() -> void:
	_ready()


func _on_settings_pressed() -> void:
	main_buttons.visible = false
	settings.visible = true


func _on_how_to_play_pressed() -> void:
	HTPpanel.visible = true


func _on_back_htp_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
