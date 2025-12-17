extends Control

func _on_main_menu_play_pressed() -> void:
	# Налаштовуємо режим:
	GameSettings.white_is_bot = false
	GameSettings.black_is_bot = true
	
	get_tree().change_scene_to_file("res://scene/main.tscn")


func _on_main_menu_exit_pressed() -> void:
	get_tree().quit()


# Кнопка "Бот проти Бота"
func _on_main_menu_botvs_bot_pressed() -> void:
	# Налаштовуємо режим:
	GameSettings.white_is_bot = true
	GameSettings.black_is_bot = true
	
	get_tree().change_scene_to_file("res://scene/main.tscn")
