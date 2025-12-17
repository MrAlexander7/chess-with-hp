extends Node2D
var pieces=[]
var move_history = []
var current_turn = 0
var white_is_bot = false
var black_is_bot = false

var activePiece=null
var b = false
@onready var debugLog = $DebugLog
@onready var tilemapBoard = $Board
@onready var pause_menu = $PauseLayer
@onready var promotion_menu = $PromotionLayer/PromotionMenu
var pending_promotion_choice = -1

func _ready() -> void:
	#createPiece(0,0,4,0)
	#createPiece(0,1,4,7)
	parseChessString("rnbqkbnr/pppppppp/________/________/________/________/PPPPPPPP/RNBQKBNR")
	#parseChessString("___r____/ppp__kp_/_____n__/____p___/_PP_P__P/__K_Pb__/P_______/_____R__")
	#parseChessString("________/P_______/________/________/________/________/________/K____k__")
	
	white_is_bot = GameSettings.white_is_bot
	black_is_bot = GameSettings.black_is_bot
	
	debugLog.text = "Режим: Білі=%s, Чорні=%s" % [white_is_bot, black_is_bot]
	
	if promotion_menu:
		promotion_menu.visible = false
		# Підключаємо сигнали кнопок (IDs: 1=Queen, 2=Bishop, 3=Knight, 4=Rook)
		$PromotionLayer/PromotionMenu/HBoxContainer/QueenBtn.pressed.connect(func(): _on_promotion_selected(1))
		$PromotionLayer/PromotionMenu/HBoxContainer/BishopBtn.pressed.connect(func(): _on_promotion_selected(2))
		$PromotionLayer/PromotionMenu/HBoxContainer/KnightBtn.pressed.connect(func(): _on_promotion_selected(3))
		$PromotionLayer/PromotionMenu/HBoxContainer/RookBtn.pressed.connect(func(): _on_promotion_selected(4))
	
	if white_is_bot and current_turn == 0:
		$Timer.start()
	pass

func _on_promotion_selected(type_id):
	pending_promotion_choice = type_id
	promotion_menu.visible = false

func parseChessString(s):
	var allTypes="KQBNRP"
	#rnbqkbnr/pppppppp/________/________/________/________/PPPPPPPP/RNBQKBNR  - почтакова позиція
	var v=0
	var h=7
	for c:String in s:
		if c!="/":
			if c in allTypes:
				var id = allTypes.find(c)
				createPiece(id,0,v,h).symbol = c
			else:
				if c.to_upper() in allTypes:
					var id = allTypes.find(c.to_upper())
					createPiece(id,1,v,h).symbol = c
			v+=1
			if v>7:
				v=0
				h-=1

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		# 1. Отримуємо позицію миші в глобальних координатах
		var mouse_pos_global = get_global_mouse_position()
		
		# 2. Конвертуємо глобальну позицію в локальну позицію TileMap
		var mouse_pos_local = tilemapBoard.to_local(mouse_pos_global)
		
		# 3. Отримуємо координати клітинки TileMap
		var tilemap_coords = tilemapBoard.local_to_map(mouse_pos_local)
		
		# 4. Перевіряємо, чи ми клікнули в межах дошки
		if tilemap_coords.x < 0 or tilemap_coords.x > 7 or tilemap_coords.y < 0 or tilemap_coords.y > 7:
			activatePiece(null) # Клік за межами, знімаємо виділення
			debugLog.text = ""
			return
			
		# 5. КОНВЕРТУЄМО КООРДИНАТИ TILEMAP У ШАХОВІ КООРДИНАТИ
		# TileMap (0,0) = A8. Шахи (0,7) = A8
		# TileMap (0,7) = A1. Шахи (0,0) = A1
		# Формула: chess_h = 7 - tilemap_y
		var cellCoord = Vector2i(tilemap_coords.x, 7 - tilemap_coords.y)
		
		update_debug_info(cellCoord.x, cellCoord.y)
		
		#var enemy_color = 1 if current_turn == 0 else 0
		#if is_square_under_attack(cellCoord.x, cellCoord.y, enemy_color):
			#print("ОБЕРЕЖНО! Клітинка ", cellCoord, " під ударом ворога!")
		#else:
			#print("Клітинка ", cellCoord, " у безпеці.")
		
		if activePiece == null:
			# Якщо фігура не активна, шукаємо фігуру на клітинці, куди клікнули
			var p = get_piece_at(cellCoord.x, cellCoord.y)
			if p != null:
				if p.color != current_turn:
					debugLog.text = "Зараз хід іншого гравця!"
					return # Ігноруємо клік
				activatePiece(p)
		else:
			# Якщо фігура активна, перевіряємо, чи може вона сюди піти
			if activePiece.canMove2Cell(cellCoord.x, cellCoord.y):
				
				var start_x = activePiece.vertid
				var start_y = activePiece.horzid
				
				if is_move_safe(activePiece, cellCoord.x, cellCoord.y):
					
					var is_castling_move = false
					if activePiece.type == 0 and abs(cellCoord.x - activePiece.vertid) == 2:
						
						if can_castle_safely(activePiece, cellCoord.x, cellCoord.y):
							is_castling_move = true
							
							var rook_x = 7 if (cellCoord.x - activePiece.vertid) > 0 else 0
							var rook = get_piece_at(rook_x, activePiece.horzid)
							if rook:
								var new_rook_x = 5 if rook_x == 7 else 3
								rook.placeAtCell(new_rook_x, activePiece.horzid)
						else:
							debugLog.text("Рокировка заборонена правилами!")
							activePiece.placeAtCell(activePiece.vertid, activePiece.horzid)
							activatePiece(null)
							return
							# Перевірка на взяття фігури
					var target_piece = get_piece_at(cellCoord.x, cellCoord.y)
					if target_piece != null:
						# canMove2Cell вже перевірила, що це фігура ворога
						removePiece(target_piece)
					
					# Переміщуємо фігуру
					activePiece.placeAtCell(cellCoord.x, cellCoord.y)
					if activePiece.type == 5:
						await handle_pawn_promotion(activePiece)
					
					activatePiece(null)
					check_for_check_status()
					change_turn()
				else: 
					debugLog.text = "Хід заборонено! Ваш Король під ударом!"
			else:
				# Перевіримо, чи є на цій клітинці інша НАША фігура.
				var target_piece = get_piece_at(cellCoord.x, cellCoord.y)
				# Якщо на клітинці є фігура, І її колір = кольору активної фігури
				if target_piece != null and target_piece.color == activePiece.color:
					activatePiece(target_piece)
				else:
					activatePiece(null)

func activatePiece(p):
	activePiece=p

#func findCellAtCoords(cx, cy):
	##v = (cx-50)//60
	##cy-550 = -60*h
	#var v = (cx-50)/60
	#var h = (550-cy)/60
	#return Vector2(round(v),round(h))
	#
	#
#func findPieceAtCoords(cx, cy):
	#var res = null
	#
	#for p in pieces:
		#var dx = cx-p.position.x
		#var dy = cy-p.position.y
		#if abs(dx)<25 and abs(dy)<25:
			#res=p;
			#break
	#
	#return res

func createPiece(tp, cl, v, h):
	var p = preload("res://scene/piece.tscn").instantiate()
	p.init_props(0, tp, cl, v, h, self)
	add_child(p)
	pieces.append(p)
	return p
	
func removePiece(p):
	p.queue_free()
	pieces.erase(p)


func get_piece_at(v, h):
	for p in pieces:
		if p.vertid == v and p.horzid == h:
			return p
	return null



func change_turn(b = false):
	if current_turn == 0:
		current_turn = 1 # Тепер чорні
		debugLog.text = "Хід чорних"
	else:
		current_turn = 0 # Тепер білі
		debugLog.text = "Хід білих"
	check_game_over_status()
	
	var current_player_is_bot = false
	if current_turn == 0 and white_is_bot:
		current_player_is_bot = true
	elif current_turn == 1 and black_is_bot:
		current_player_is_bot = true
	if current_player_is_bot:
		if $Timer.is_stopped():
			$Timer.start()
	else:
		$Timer.stop()


func is_square_under_attack(v, h, enemy_color) -> bool:
	for p in pieces:
		if p != null and p.color == enemy_color:
			if p.is_attacking_square(v, h):
				return true
	return false


func update_debug_info(v, h):
	var info = "Клітинка: (%d, %d)\n" % [v, h]
	
	# Хто стоїть на клітинці?
	var p = get_piece_at(v, h)
	if p:
		var color_name = "Білий" if p.color == 0 else "Чорний"
		var type_names = ["Король", "Ферзь", "Слон", "Кінь", "Тура", "Пішак"]
		info += "Фігура: %s %s\n" % [color_name, type_names[p.type]]
	else:
		info += "Фігура: Пусто\n"
	
	info += "-----------------\n"
	
	# ХТО АТАКУЄ ЦЮ КЛІТИНКУ?
	# Перевіряємо, чи атакують цю клітинку БІЛІ (color 0)
	var attacked_by_white = is_square_under_attack(v, h, 0)
	# Перевіряємо, чи атакують цю клітинку ЧОРНІ (color 1)
	var attacked_by_black = is_square_under_attack(v, h, 1)
	
	info += "Під ударом Білих: %s\n" % str(attacked_by_white)
	info += "Під ударом Чорних: %s\n" % str(attacked_by_black)
	
	debugLog.text = info


func is_move_safe(piece, target_v, target_h) -> bool:
	if target_v == piece.vertid and target_h == piece.horzid:
		return false
	
	#Запам'ятаєм де хто
	var old_v = piece.vertid
	var old_h = piece.horzid
	var target_piece = get_piece_at(target_v, target_h)
	
	#Зробимо віртуальний хід
	piece.vertid = target_v
	piece.horzid = target_h
	
	#У разі наявності фігури там тимчасово ховаєм
	if target_piece:
		target_piece.vertid = -100
		target_piece.horzid = -100
	
	#Пошук кординат нашого короля
	var king_coords = find_king_coords(piece.color)
	
	#Перевірка на атаку короля
	var enemy_color = 1 if piece.color == 0 else 0
	var safe = ! is_square_under_attack(king_coords.x,king_coords.y,enemy_color)
	
	#Повертаєм назад
	piece.vertid = old_v
	piece.horzid = old_h
	if target_piece:
		target_piece.vertid = target_v
		target_piece.horzid = target_h
	return safe

func find_king_coords(c) -> Vector2i:
	for p in pieces:
		if p.type == 0 and p.color == c: # 0 - це ID Короля
			return Vector2i(p.vertid, p.horzid)
	return Vector2i(0,0) # На випадок помилки

func check_for_check_status():
	reset_kings_color()
	
	#Перевірка Білого короля на атаку чорними
	var w_king_pos = find_king_coords(0)
	if is_square_under_attack(w_king_pos.x, w_king_pos.y, 1):
		debugLog.text = "Шах Білому королю"
		highlight_king(0,Color.RED)
	
	#Перевірка Чорного короля на атаку білими
	var b_king_pos = find_king_coords(1)
	if is_square_under_attack(b_king_pos.x, b_king_pos.y, 0):
		debugLog.text = "Шах Чорному королю"
		highlight_king(1,Color.RED)

func highlight_king(k_color, color_modulate):
	for p in pieces:
		if p.type == 0 and p.color == k_color:
			p.get_node("Sprite2D").modulate = color_modulate

func reset_kings_color():
	highlight_king(0, Color.WHITE)
	highlight_king(1, Color.WHITE)


func has_any_valid_moves(player_color):
	for p in pieces:
		if p != null and p.color == player_color:
			for x in range(8):
				for y in range(8):
					if p.canMove2Cell(x,y):
						if is_move_safe(p,x,y):
							return true
	return false

func check_game_over_status():
	var king_pos = find_king_coords(current_turn)
	var enemy_color = 1 if current_turn == 0 else 0
	var is_in_check = is_square_under_attack(king_pos.x, king_pos.y, enemy_color)
	var can_move = has_any_valid_moves(current_turn)
	
	if is_in_check and ! can_move:
		debugLog.text = "Мат гра закінченна"
		restart_game()
	
	elif ! is_in_check and ! can_move:
		debugLog.text = "Пат нічия"
		restart_game()

func restart_game(t = 5.0):
	debugLog.text = "Перезагрузка гри через 5 секунд"
	await get_tree().create_timer(t).timeout
	get_tree().reload_current_scene()

func can_castle_safely(king_piece, target_v, target_h) -> bool:
	var enemy_color = 1 if king_piece.color == 0 else 0
	
	if is_square_under_attack(king_piece.vertid, king_piece.horzid, enemy_color):
		debugLog.text = "Рокировка неможлива: Королю Шах!"
		return false
	
	var direction = 1 if target_v > king_piece.vertid else -1
	var middle_v = king_piece.vertid + direction
	
	if is_square_under_attack(king_piece.vertid, king_piece.horzid, enemy_color):
		debugLog.text = "Рокировка неможлива: Проміжна клітинка під ударом!"
		return false
	
	return true

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"): # За замовчуванням це ESC
		toggle_pause()

func toggle_pause():
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused # Ставимо двигун на паузу/знімаємо
	pause_menu.visible = is_paused # Показуємо/ховаємо меню

func _on_main_resume_pressed() -> void:
	toggle_pause()
	pass # Replace with function body.


func _on_main_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
	pass # Replace with function body.


func _on_button_pressed() -> void:
	restart_game(0.5)
	pass # Replace with function body.


func _on_ai_move_pressed() -> void:
	var posible_move = [];
	b = true
	for p in pieces:
		if p.color == current_turn:
			for v in range(8):
				for h in range(8):
					if p.canMove2Cell(v,h):
						if is_move_safe(p,v,h):
							posible_move.append({"p": p, "v": v, "h": h})
	debugLog.text = str(len(posible_move))
	#print(posible_move)
	if len(posible_move) == 0:
		return
	
	var move = posible_move.pick_random()
	
	var target_piece = get_piece_at(move.v, move.h)
	if target_piece != null:
		removePiece(target_piece)
	
	move.p.placeAtCell(move.v, move.h)
	if move.p.type == 5:
		await handle_pawn_promotion(move.p)
	activatePiece(null)
	check_for_check_status()
	check_draw()
	change_turn(b)
	pass # Replace with function body.


func _on_timer_timeout() -> void:
	_on_ai_move_pressed()
	pass # Replace with function body.


func _on_timer_up_pressed() -> void:
	$Timer.wait_time /= 2
	pass # Replace with function body.


func _on_timer_down_pressed() -> void:
	$Timer.wait_time *= 2
	pass # Replace with function body.


func check_draw():
	#for p in pieces:
	if len(pieces) == 2:
		debugLog.text = "draw"
		restart_game()
	pass

func record_move(piece, from_v, from_h, to_v, to_h, action_type, target_piece = null):
	var entry = {
		"turn_number": move_history.size + 1,
		"color": piece.color,
		"piece_type": piece.type,
		"from": Vector2i(from_v, from_h),
		"to": Vector2i(to_v, to_h),
		"action": action_type,
		"target_type": target_piece.type if target_piece else -1
	}
	move_history.append(entry)
	debugLog.text = "Історія: %s" % entry

func handle_pawn_promotion(pawn):
	var target_row = 7 if pawn.color == 0 else 0
	if pawn.type != 5 or pawn.horzid != target_row:
		return
	var new_type = 1
	
	var is_current_player_bot = false
	if pawn.color == 0:
		is_current_player_bot = white_is_bot
	else:
		is_current_player_bot = black_is_bot
		
	if is_current_player_bot:
		var options = [1, 2, 3, 4] 
		new_type = options.pick_random()
		debugLog.text = "Бот перетворив пішака на ID: " + str(new_type)
	else:
		if promotion_menu:
			promotion_menu.visible = true
			pending_promotion_choice = -1
			while pending_promotion_choice == -1:
				await get_tree().create_timer(0.1).timeout
			new_type = pending_promotion_choice
		else:
			print("ПОМИЛКА: Немає PromotionMenu у сцені!")
	pawn.promote_to(new_type)
