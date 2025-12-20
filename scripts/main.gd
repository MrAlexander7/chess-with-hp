extends Node2D
var pieces=[]
var move_history = []
const PIECE_VALUES = {
	0: 100, 
	1: 9, 
	2: 3, 
	3: 3, 
	4: 5, 
	5: 1
}
var current_turn = 0
var white_is_bot = false
var black_is_bot = false
var last_attacked_piece = null

var activePiece=null
var b = false
@onready var debugLog = $DebugLog
@onready var tilemapBoard = $Board
@onready var highlight_map = $HighlightMap
@onready var pause_menu = $PauseLayer
@onready var status_label = $HUD/SidePanel/GameStatusLabel
@onready var unit_name_label = $HUD/SidePanel/GameStatusLabel/UnitNameLabel
@onready var unit_stats_label = $HUD/SidePanel/GameStatusLabel/UnitStatsLabel
@onready var promotion_container = $HUD/SidePanel/PromotionContainer

# Кнопки лежать всередині PromotionContainer
@onready var btn_queen = $HUD/SidePanel/PromotionContainer/QueenBtn
@onready var btn_rook = $HUD/SidePanel/PromotionContainer/RookBtn
@onready var btn_bishop = $HUD/SidePanel/PromotionContainer/BishopBtn
@onready var btn_knight = $HUD/SidePanel/PromotionContainer/KnightBtn
var pending_promotion_choice = -1

func _ready() -> void:
	#createPiece(0,0,4,0)
	#createPiece(0,1,4,7)
	parseChessString("rnbqkbnr/pppppppp/________/________/________/________/PPPPPPPP/RNBQKBNR")
	#parseChessString("___r____/ppp__kp_/_____n__/____p___/_PP_P__P/__K_Pb__/P_______/_____R__")
	#parseChessString("________/P_______/________/________/________/________/________/K____k__")
	
	if GameSettings:
		white_is_bot = GameSettings.white_is_bot
		black_is_bot = GameSettings.black_is_bot
	
	debugLog.text = "Режим: Білі=%s, Чорні=%s" % [white_is_bot, black_is_bot]
	
	if promotion_container:
		promotion_container.visible = false
		btn_queen.pressed.connect(func(): _on_promotion_selected(1))
		btn_bishop.pressed.connect(func(): _on_promotion_selected(2))
		btn_knight.pressed.connect(func(): _on_promotion_selected(3))
		btn_rook.pressed.connect(func(): _on_promotion_selected(4))
	
	update_game_status_ui("The game has started! White's move")
	update_unit_ui(null)
	
	if white_is_bot and current_turn == 0:
		$Timer.start()
	pass

func _on_promotion_selected(type_id):
	pending_promotion_choice = type_id
	promotion_container.visible = false
	if activePiece:
		update_unit_ui(activePiece)

func update_game_status_ui(text: String):
	if status_label:
		status_label.text = text

func update_unit_ui(piece):
	
	if piece == null:
		unit_name_label.text = "Choise piece"
		unit_stats_label.text = ""
		return
	
	var type_names = {
		0: "King",
		1: "Queen",
		2: "Bishop",
		3: "Knight",
		4: "Rook",
		5: "Pawn"
	}
	var color_name = "White" if piece.color == 0 else "Black"
	var p_name = type_names.get(piece.type, "Unknown")
	unit_name_label.text = "%s %s" % [color_name, p_name]
	
	var stats_text = "[img=42x42]res://img/icon_hp.png[/img] HP: %d\n" % piece.current_hp
	stats_text += "[img=42x42]res://img/icon_attack.png[/img] Attack: %d\n" % piece.attack
	stats_text += "[img=42x42]res://img/icon_defense.png[/img] Defense: %d\n" % piece.defense
	
	# Додаткова інфа
	if piece.moved:
		stats_text += "\n(Already went)"
	
	unit_stats_label.text = stats_text

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
				update_unit_ui(p)
				if p.color != current_turn:
					update_game_status_ui("It's another player's turn!")
					debugLog.text = "It's another player's turn!"
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
							update_game_status_ui("Castling is prohibited by the rules!")
							#debugLog.text("Рокировка заборонена правилами!")
							activePiece.placeAtCell(activePiece.vertid, activePiece.horzid)
							activatePiece(null)
							return
							# Перевірка на взяття фігури
					var target_piece = get_piece_at(cellCoord.x, cellCoord.y)
					var is_royal_punishment = false
					if target_piece != null and target_piece.color != activePiece.color:
						highlight_attack(target_piece)
						#await get_tree().create_timer(0.3).timeout 
						var attack_tween = activePiece.placeAtCell(cellCoord.x, cellCoord.y, true, true)
						if attack_tween: 
							await attack_tween.finished
						var damage_to_deal = activePiece.attack
						if activePiece.type == 0:
							var king_attackers = get_attackers_of_square(activePiece.vertid, activePiece.horzid, target_piece.color)
							if target_piece in king_attackers:
								damage_to_deal = 9999 # Смертельна шкода
								is_royal_punishment = true
								update_game_status_ui("ROYAL PUNISHMENT! VANSHOT!")
								debugLog.text = "КОРОЛІВСЬКА КАРА! ВАНШОТ!"
						if is_royal_punishment:
							var is_dead = target_piece.take_attack(damage_to_deal, "HP") 
							spawn_damage_text(target_piece.global_position, damage_to_deal, "CRIT")
							if is_dead:
								#txt.position = target_piece.position
								#txt.start_anim(damage_to_deal)
								removePiece(target_piece)
								activePiece.placeAtCell(cellCoord.x, cellCoord.y, false, false)
								finish_move(activePiece)
							else:
								await _return_piece_home(activePiece, start_x, start_y)
								finish_move(activePiece)
								
						elif target_piece.moved and target_piece.defense > 0:
							debugLog.text = "Атака по броні"
							
							var current_def = target_piece.defense
							var damage_to_armor = min(current_def, damage_to_deal) # Броня бере на себе скільки може
							var damage_to_hp = max(0, damage_to_deal - current_def)
							
							target_piece.take_attack(damage_to_deal, "ARMOR")
							spawn_damage_text(target_piece.global_position, damage_to_armor, "ARMOR")
							
							var is_dead = false
							if damage_to_hp > 0:
								is_dead = target_piece.take_attack(damage_to_hp, "HP")
								spawn_damage_text(target_piece.global_position, damage_to_hp, "HP")
							if is_dead:
								removePiece(target_piece)
								activePiece.placeAtCell(cellCoord.x, cellCoord.y, false, false)
								finish_move(activePiece)
							else:
								var push_v = target_piece.prev_vertid
								var push_h = target_piece.prev_horzid
								var obstruction = get_piece_at(push_v, push_h)
								if obstruction == null:
									debugLog.text = "Ворог відкинутий"
									target_piece.placeAtCell(push_v, push_h)
									await _return_piece_home(activePiece, start_x, start_y)
									finish_move(activePiece)
								else:
									debugLog.text = "Не має куда відкинути ворога"
									is_dead = target_piece.take_attack(damage_to_hp, "HP")
									spawn_damage_text(target_piece.global_position, damage_to_hp, "HP")
									if is_dead:
										removePiece(target_piece)
										# Займаємо клітинку
										activePiece.placeAtCell(cellCoord.x, cellCoord.y, false, false)
										if activePiece.type == 5: 
											await handle_pawn_promotion(activePiece)
										finish_move(activePiece)
									else:
										debugLog.text = "Ворог отримав поранення, але стоїть."
										await _return_piece_home(activePiece, start_x, start_y)
										finish_move(activePiece)
						else:
							var is_dead = target_piece.take_attack(damage_to_deal, "HP")
							spawn_damage_text(target_piece.global_position, damage_to_deal, "HP")
							if is_dead:
								removePiece(target_piece)
								activePiece.placeAtCell(cellCoord.x, cellCoord.y, false, false)
								if activePiece.type == 5: 
									await handle_pawn_promotion(activePiece)
								finish_move(activePiece)
							else:
								await _return_piece_home(activePiece, start_x, start_y)
								finish_move(activePiece)
					# Переміщуємо фігуру
					elif target_piece == null:
						activePiece.placeAtCell(cellCoord.x, cellCoord.y)
						if activePiece.type == 5:
							await handle_pawn_promotion(activePiece)
						finish_move(activePiece)
				else: 
					update_game_status_ui("Move not allowed! Your King is in check!")
					debugLog.text = "Хід заборонено! Ваш Король під ударом!"
			else:
				# Перевіримо, чи є на цій клітинці інша НАША фігура.
				var target_piece = get_piece_at(cellCoord.x, cellCoord.y)
				# Якщо на клітинці є фігура, І її колір = кольору активної фігури
				if target_piece != null and target_piece.color == activePiece.color:
					activatePiece(target_piece)
				else:
					activatePiece(null)

func _return_piece_home(piece, v, h):
	var t = piece.placeAtCell(v, h, true, true)
	if t: 
		await t.finished

func activatePiece(p):
	if activePiece != null and is_instance_valid(activePiece):
			if activePiece.has_node("HighlightRect"):
				activePiece.get_node("HighlightRect").visible = false
	activePiece=p
	if p != null:
		if p.has_node("HighlightRect"):
			var rect = p.get_node("HighlightRect")
			rect.visible = true
			rect.border_color = Color(0, 1, 0, 0.5)
		update_unit_ui(p)
		show_possible_moves(p)
	else:
		update_unit_ui(null)
		clear_highlights()

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

func finish_move(piece):
	piece.moved = true
	update_unit_ui(piece)
	
	highlight_attack(null)
	clear_highlights()
	activatePiece(null)
	
	check_for_check_status()
	change_turn()

func change_turn(b = false):
	if current_turn == 0:
		current_turn = 1 # Тепер чорні
		update_game_status_ui("Black's move")
		debugLog.text = "Хід чорних"
	else:
		current_turn = 0 # Тепер білі
		update_game_status_ui("White's move")
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

func get_attackers_of_square(v, h, enemy_color) -> Array:
	var attackers = []
	for p in pieces:
		if p != null and p.color == enemy_color:
			if p.is_attacking_square(v, h):
				attackers.append(p)
	return attackers

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
	
	info += "-----------------\n"
	
	
	debugLog.text = info


func is_move_safe(piece, target_v, target_h) -> bool:
	if target_v == piece.vertid and target_h == piece.horzid:
		return false
	
	#Запам'ятаєм де хто
	var old_v = piece.vertid
	var old_h = piece.horzid
	var target_piece = get_piece_at(target_v, target_h)
	
	var move_is_effective = true
	
	if target_piece != null:
		var will_die = false
		var will_pushed = false
		
		var calculated_damage = piece.attack
		
		if piece.type == 0:
			var king_attackers = get_attackers_of_square(piece.vertid, piece.horzid, target_piece.color)
			if target_piece in king_attackers:
				calculated_damage = 9999
		
		if target_piece.moved and target_piece.defense >= 0:
			if calculated_damage >= target_piece.current_hp:
				will_die = true
		else:
			if calculated_damage >= target_piece.current_hp:
				will_die = true
				
		if not will_die and not will_pushed:
			move_is_effective = false
	if move_is_effective:
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
		update_game_status_ui("Check to the White King")
		debugLog.text = "Шах Білому королю"
		highlight_king(0,Color.RED)
	
	#Перевірка Чорного короля на атаку білими
	var b_king_pos = find_king_coords(1)
	if is_square_under_attack(b_king_pos.x, b_king_pos.y, 0):
		update_game_status_ui("Check to the Black King")
		debugLog.text = "Шах Чорному королю"
		highlight_king(1,Color.RED)

func highlight_king(k_color, color_modulate):
	for p in pieces:
		if p.type == 0 and p.color == k_color:
			p.get_node("Sprite2D").modulate = color_modulate

func highlight_attack(target_p):
	if last_attacked_piece != null and is_instance_valid(last_attacked_piece):
		if last_attacked_piece.has_node("HighlightRect"):
			last_attacked_piece.get_node("HighlightRect").visible = false
	
	if target_p != null and is_instance_valid(target_p):
		if target_p.has_node("HighlightRect"):
			var rect = target_p.get_node("HighlightRect")
			rect.visible = true
			rect.border_color = Color(1, 0, 0, 0.5) # Червоний напівпрозорий (атака)
		last_attacked_piece = target_p
	else:
		last_attacked_piece = null

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
		update_game_status_ui("Checkmate")
		debugLog.text = "Мат гра закінченна"
		restart_game()
	
	elif ! is_in_check and ! can_move:
		update_game_status_ui("Stalemate")
		debugLog.text = "Пат нічия"
		restart_game()

func restart_game(t = 5.0):
	update_game_status_ui("")
	debugLog.text = "Game will restart in 5 seconds"
	await get_tree().create_timer(t).timeout
	get_tree().reload_current_scene()

func can_castle_safely(king_piece, target_v, target_h) -> bool:
	var enemy_color = 1 if king_piece.color == 0 else 0
	
	if is_square_under_attack(king_piece.vertid, king_piece.horzid, enemy_color):
		update_game_status_ui("Castling is impossible: Check to the King!")
		debugLog.text = "Рокировка неможлива: Королю Шах!"
		return false
	
	var direction = 1 if target_v > king_piece.vertid else -1
	var middle_v = king_piece.vertid + direction
	
	if is_square_under_attack(king_piece.vertid, king_piece.horzid, enemy_color):
		update_game_status_ui("Castling is impossible: The intermediate square is under attack!")
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

func get_move_score(attacker, target_v, target_h):
	var score = 0
	var target = get_piece_at(target_v, target_h)
	
	score += analyze_move_for_mate_or_check(attacker, target_v, target_h)
	
	if target != null:
		var target_value = PIECE_VALUES.get(target.type, 1)
		var estimated_dmg = attacker.attack
		if attacker.type == 0:
			var king_attackers = get_attackers_of_square(attacker.vertid, attacker.horzid, target.color)
			if target in king_attackers:
				estimated_dmg = 9999
				score += 200
		var damage_to_hp = 0
		if target.moved and target.defense > 0:
			damage_to_hp = max(0, estimated_dmg - target.defense)
		else:
			damage_to_hp = estimated_dmg
		if damage_to_hp >= target.current_hp:
			score =+ 100 + (target_value * 20)
		else:
			score += damage_to_hp * 2
			
			if damage_to_hp == 0:
				score -= 10
		if (target_v == 3 or target_v == 4) and (target_h == 3 or target_h == 4):
			score += 5
		var enemy_color = 1 if attacker.color == 0 else 0
		if is_square_under_attack(target_v, target_h, enemy_color):
			var my_value = PIECE_VALUES.get(attacker.type, 1)
			var trade_value = 0
			if target != null:
				target_value = PIECE_VALUES.get(target.type, 1)
			
			if my_value > target_value:
				score -= (my_value - target_value) * 10
	score += randi() % 5
	return score

func analyze_move_for_mate_or_check(attacker, target_v, target_h):
	var bonus_score = 0
	var enemy_color = 0
	if attacker.color == 0:
		enemy_color = 1
	else:
		enemy_color = 0
	
	var old_v = attacker.vertid
	var old_h = attacker.horzid
	var target_piece = get_piece_at(target_v, target_h)
	
	attacker.vertid = target_v
	attacker.horzid = target_h
	
	if target_piece:
		target_piece.vertid = -100
		target_piece.horzid = -100
	
	var king_pos = find_king_coords(enemy_color)
	var is_check = is_square_under_attack(king_pos.x, king_pos.y, attacker.color)
	
	if is_check:
		if !has_any_valid_moves(enemy_color):
			bonus_score = 1000
			debugLog.text = "MAT"
		else:
			bonus_score = 500
	attacker.vertid = old_v
	attacker.horzid = old_h
	if target_piece:
		target_piece.vertid = target_v
		target_piece.horzid = target_h
		
	return bonus_score

func _on_ai_move_pressed() -> void:
	$Timer.stop()
	var posible_move = [];
	b = true
	for p in pieces:
		if p.color == current_turn:
			for v in range(8):
				for h in range(8):
					if p.canMove2Cell(v,h):
						if is_move_safe(p,v,h):
							var score = get_move_score(p, v, h)
							posible_move.append({"p": p, "v": v, "h": h, "score": score})
	debugLog.text = str(len(posible_move))
	print(posible_move)
	if len(posible_move) == 0:
		update_game_status_ui("MAT or PAT. The bot cannot walk.")
		return
	
	posible_move.sort_custom(
		func(a,b):
			return a["score"] > b["score"]
	)
	var top_move_count = min(3, len(posible_move))
	var best_move = posible_move[randi() % top_move_count]
	var attacker = best_move.p
	var target_v = best_move.v
	var target_h = best_move.h
	
	var start_v = attacker.vertid
	var start_h = attacker.horzid
	
	var target_piece = get_piece_at(target_v, target_h)
	var move_successful = true
	if target_piece != null:
		highlight_attack(target_piece)
		#await get_tree().create_timer(0.5).timeout
		
		var attack_tween = attacker.placeAtCell(target_v, target_h, true, true)
		if attack_tween: 
			await attack_tween.finished
		
		var damage_to_deal = attacker.attack
		var is_royal_punishment = false
		if attacker.type == 0:
			var king_attackers = get_attackers_of_square(attacker.vertid, attacker.horzid, target_piece.color)
			if target_piece in king_attackers:
				damage_to_deal = 9999
				is_royal_punishment = true
				debugLog.text = "Бот застосував ВАНШОТ!"
		
		if is_royal_punishment:
			var is_dead = target_piece.take_attack(damage_to_deal, "HP")
			spawn_damage_text(target_piece.global_position, damage_to_deal, "CRIT")
			if is_dead:
				removePiece(target_piece)
				attacker.placeAtCell(target_v, target_h, false, false)
				finish_move(attacker)
				return
			else:
				await _return_piece_home(attacker, start_v, start_h)
				finish_move(attacker)
				return
		elif target_piece.moved and target_piece.defense > 0:
			debugLog.text = "Бот б'є по броні"
			
			var current_def = target_piece.defense
			var damage_to_armor = min(current_def, damage_to_deal) # Броня бере на себе скільки може
			var damage_to_hp = max(0, damage_to_deal - current_def)
			
			target_piece.take_attack(damage_to_deal, "ARMOR")
			spawn_damage_text(target_piece.global_position, damage_to_armor, "ARMOR")
			
			var is_dead = false
			if damage_to_hp > 0:
				is_dead = target_piece.take_attack(damage_to_hp, "HP")
				spawn_damage_text(target_piece.global_position, damage_to_hp, "HP")
			
			if is_dead:
				removePiece(target_piece)
				attacker.placeAtCell(target_v, target_h, false, false)
				if attacker.type == 5: 
					await handle_pawn_promotion(attacker)
				finish_move(attacker)
				return
			else:
				var push_v = target_piece.prev_vertid
				var push_h = target_piece.prev_horzid
				var obstruction = get_piece_at(push_v, push_h)
				
				if obstruction == null:
					target_piece.placeAtCell(push_v, push_h)
					move_successful = false
				else:
					is_dead = target_piece.take_attack(damage_to_hp, "HP")
					spawn_damage_text(target_piece.global_position, damage_to_hp, "HP")
					if is_dead:
						removePiece(target_piece)
						move_successful = true
					else:
						move_successful = false
		else:
			var is_dead = target_piece.take_attack(damage_to_deal, "HP")
			spawn_damage_text(target_piece.global_position, damage_to_deal, "HP")
			if is_dead:
				removePiece(target_piece)
				move_successful = true
			else:
				move_successful = false
	else:
		move_successful = true
	
	highlight_attack(null)
	if move_successful:
		var animated = (target_piece == null) 
		attacker.placeAtCell(target_v, target_h, animated, false)
		if attacker.type == 5:
			await handle_pawn_promotion(attacker)
	else:
		# Повертаємося назад з анімацією
		await _return_piece_home(attacker, start_v, start_h)
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
		if promotion_container:
			update_game_status_ui("Select a transformation!")
			promotion_container.visible = true
			pending_promotion_choice = -1
			
			while pending_promotion_choice == -1:
				await get_tree().create_timer(0.1).timeout
			
			new_type = pending_promotion_choice
			promotion_container.visible = false # Ховаємо після вибору
		else:
			print("ПОМИЛКА: Немає PromotionContainer!")
	pawn.promote_to(new_type)
	update_unit_ui(pawn)

func clear_highlights():
	highlight_map.clear()

func show_possible_moves(piece):
	clear_highlights()
	for v in range(8):
		for h in range(8):
			if piece.canMove2Cell(v, h) and is_move_safe(piece, v, h):
				var tile_pos = Vector2i(v, 7 - h)
				highlight_map.set_cell(tile_pos, 0, Vector2i(0, 0))

func spawn_damage_text(pos: Vector2, amount: int, type: String):
	var txt_scene = preload("res://scene/FloatingText.tscn")
	var txt = txt_scene.instantiate()
	add_child(txt)
	txt.global_position = pos + Vector2(0, -30)
	txt.start_anim(amount, type)
