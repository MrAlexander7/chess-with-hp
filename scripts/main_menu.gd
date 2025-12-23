extends Control

@onready var info_panel = $InfoPanel
@onready var button_manager = $Button_Manager
@onready var choose_play_mode = $ChoosePlayMode
func _ready() -> void:
	if GameSettings.is_first_play:
		info_panel.visible = true
		button_manager.visible = false
	else:
		info_panel.visible = false
		button_manager.visible = true

func _on_main_menu_play_pressed() -> void:
	## Налаштовуємо режим:
	#GameSettings.white_is_bot = false
	#GameSettings.black_is_bot = true
	
	button_manager.visible = false
	choose_play_mode.visible = true
	
	#get_tree().change_scene_to_file("res://scene/main.tscn")


func _on_main_menu_exit_pressed() -> void:
	get_tree().quit()


# Кнопка "Бот проти Бота"
func _on_main_menu_botvs_bot_pressed() -> void:
	# Налаштовуємо режим:
	GameSettings.white_is_bot = true
	GameSettings.black_is_bot = true
	
	get_tree().change_scene_to_file("res://scene/main.tscn")


func _on_ok_pressed() -> void:
	info_panel.visible = false
	button_manager.visible = true
	GameSettings.is_first_play = false
	pass # Replace with function body.


func _on_playervs_player_pressed() -> void:
	GameSettings.white_is_bot = false
	GameSettings.black_is_bot = false
	
	get_tree().change_scene_to_file("res://scene/main.tscn")
	pass # Replace with function body.


func _on_playervs_bot_pressed() -> void:
	GameSettings.white_is_bot = false
	GameSettings.black_is_bot = true
	
	get_tree().change_scene_to_file("res://scene/main.tscn")
	pass # Replace with function body.


func _on_botvs_bot_pressed() -> void:
	GameSettings.white_is_bot = true
	GameSettings.black_is_bot = true
	
	get_tree().change_scene_to_file("res://scene/main.tscn")
	pass # Replace with function body.
