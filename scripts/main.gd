extends Node2D
var pieces=[]
var current_turn = 0

var activePiece=null

@onready var tilemapBoard = $Board

func _ready() -> void:
	#createPiece(0,0,4,0)
	#createPiece(0,1,4,7)
	parseChessString("rnbqkbnr/pppppppp/________/________/________/________/PPPPPPPP/RNBQKBNR")
	pass

func parseChessString(s):
	var allTypes="KQBNRP"
	#rnbqkbnr/pppppppp/________/________/________/________/PPPPPPPP/RNBQKBNR  - почтакова позиція
	var v=0
	var h=7
	for c:String in s:
		if c!="/":
			if c in allTypes:
				var id = allTypes.find(c)
				createPiece(id,0,v,h)
			else:
				if c.to_upper() in allTypes:
					var id = allTypes.find(c.to_upper())
					createPiece(id,1,v,h)			
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
			return
			
		# 5. КОНВЕРТУЄМО КООРДИНАТИ TILEMAP У ШАХОВІ КООРДИНАТИ
		# TileMap (0,0) = A8. Шахи (0,7) = A8
		# TileMap (0,7) = A1. Шахи (0,0) = A1
		# Формула: chess_h = 7 - tilemap_y
		var cellCoord = Vector2i(tilemap_coords.x, 7 - tilemap_coords.y)
		
		var enemy_color = 1 if current_turn == 0 else 0
		if is_square_under_attack(cellCoord.x, cellCoord.y, enemy_color):
			print("ОБЕРЕЖНО! Клітинка ", cellCoord, " під ударом ворога!")
		else:
			print("Клітинка ", cellCoord, " у безпеці.")
		
		if activePiece == null:
			# Якщо фігура не активна, шукаємо фігуру на клітинці, куди клікнули
			var p = get_piece_at(cellCoord.x, cellCoord.y)
			if p != null:
				if p.color != current_turn:
					print("Зараз хід іншого гравця!")
					return # Ігноруємо клік
				activatePiece(p)
		else:
			# Якщо фігура активна, перевіряємо, чи може вона сюди піти
			if activePiece.canMove2Cell(cellCoord.x, cellCoord.y):
				
				# Перевірка на взяття фігури
				var target_piece = get_piece_at(cellCoord.x, cellCoord.y)
				if target_piece != null:
					# canMove2Cell вже перевірила, що це фігура ворога
					removePiece(target_piece)
					
				# Переміщуємо фігуру
				activePiece.placeAtCell(cellCoord.x, cellCoord.y)
				activatePiece(null)
				change_turn()
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
	
func removePiece(p):
	p.queue_free()
	pieces.erase(p)


func get_piece_at(v, h):
	for p in pieces:
		if p.vertid == v and p.horzid == h:
			return p
	return null


func change_turn():
	if current_turn == 0:
		current_turn = 1 # Тепер чорні
		print("Хід чорних")
	else:
		current_turn = 0 # Тепер білі
		print("Хід білих")


func is_square_under_attack(v, h, enemy_color) -> bool:
	for p in pieces:
		if p != null and p.color == enemy_color:
			if p.is_attacking_square(v, h):
				return true
	return false
