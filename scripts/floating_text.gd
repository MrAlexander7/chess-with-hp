extends Node2D

@onready var label = $Label

func start_anim(value, type = "HP"):
	label.text = str(value)
	
	match type:
		"HP":
			label.modulate = Color(1, 0, 0) # Червоний (Здоров'я)
		"ARMOR":
			label.modulate = Color(0, 0.5, 1) # Синій (Броня)
		"CRIT":
			label.modulate = Color(1, 0.8, 0) # Золотий (Ваншот/Крит)
			label.scale = Vector2(1.5, 1.5) # Трохи більший
	
	position.x += randf_range(-30, 30)
	
	# 2. Анімація польоту
	var tween = create_tween()
	tween.set_parallel(true) # Робити все одночасно
	# Летимо вгору на 80 пікселів
	tween.tween_property(self, "position:y", position.y - 80, 1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Зникаємо (прозорість в 0)
	tween.tween_property(self, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()
