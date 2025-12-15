extends Node2D

var main = null

var hp=1
var attack=1
var defence=1

var sybol:String = ""
var id=0
var type=0
var horzid=0
var vertid=0
var color=0
var moved = false

func _ready() -> void:
	pass

func _to_string() -> String:
	return self.sybol + "abcdefgh"[vertid] + str(horzid + 1)

func init_props(id, tp, c, v, h, main_ref = null):
	self.id=id
	self.type=tp
	self.color=c
	self.main = main_ref
	$Sprite2D.frame=self.type+self.color*6
	placeAtCell(v,h)
	moved = false
	
func placeAtCell(v, h):
	self.horzid=h
	self.vertid=v
	# 1. Конвертуємо шахові координати (h=0 - низ) в TileMap (y=0 - верх)
	# Формула: tilemap_y = 7 - chess_h
	var tilemap_coords = Vector2i(v, 7 - h)
	
	# 2. Використовуємо TileMap, щоб отримати ЦЕНТР клітинки в пікселях
	if main and main.tilemapBoard:
		self.global_position = main.tilemapBoard.to_global(main.tilemapBoard.map_to_local(tilemap_coords))
	else:
		print("Помилка: не можу знайти TileMap у 'main'!")
	
	moved = true


func canMove2Cell(v,h):
	var dx = v - vertid
	var dy = h - horzid
	
	#Задаємо межі дошки
	if v < 0 or v > 7 or h < 0 or h > 7:
		return false
	
	#Перевірка на наявність фігури
	var target = main.get_piece_at(v,h)
	if target and target.color == color:
		return false
	
	match type:
		0: # Король
			if abs(dx) <= 1 and abs(dy) <= 1:
				return true
			if abs(dx) == 2 and dy == 0 and !moved:
				var rook_x = 7 if dx > 0 else 0
				var rook = main.get_piece_at(rook_x, horzid)
				if rook != null and rook.type == 4 and rook.color == color and !rook.moved:
					return pathIsClear(rook_x, horzid)
			return false
		1: # Ферзь
			if abs(dx) == abs(dy) or dx == 0 or dy == 0:
				return pathIsClear(v, h)
			return false
		2: # Слон
			if abs(dx) != abs(dy):
				return false
			return pathIsClear(v, h) and abs(dx) <= 8 and abs(dy) <= 8
		3: # Конь
			return (abs(dx) == 1 and abs(dy) == 2) or (abs(dx) == 2 and abs(dy) == 1)
		4: # Ладья
			if dx != 0 and dy != 0:
				return false
			return pathIsClear(v, h)
		5: # Пишак
			return Can2MovePawn(v, h)
		_:
			return false


func pathIsClear(v,h):
	var step_x = sign(v - vertid)
	var step_y = sign(h - horzid)
	
	var x = vertid + step_x
	var y = horzid + step_y
	
	while x != v or y != h:
		var p = main.get_piece_at(x, y)
		if p != null:
			return false
		if step_x != 0:
			x += step_x
		if step_y != 0:
			y += step_y
	return true

func Can2MovePawn(v, h):

	var direction = 0
	if color == 0:
		direction = 1
	else:
		direction = -1

	var start_row = 0
	if color == 0:
		start_row = 1
	else:
		start_row = 6

	var dx = v - vertid
	var dy = h - horzid
	var target = main.get_piece_at(v, h)
	
	# Хід уперед
	if dx == 0:
		if dy == direction and target == null:
			return true
		if horzid == start_row and dy == 2 * direction and target == null and main.get_piece_at(v, horzid + direction) == null:
			return true
	# Взяття по діагоналі
	elif abs(dx) == 1 and dy == direction and target and target.color != color:
		return true
	
	return false

func is_attacking_square(target_v, target_h) -> bool:
	var dx = target_v - vertid
	var dy = target_h - horzid
	
	if vertid < 0 or horzid < 0:
		return false

	
	# Якщо це та сама клітинка, де ми стоїмо - це не атака
	if dx == 0 and dy == 0:
		return false
		
	match type:
		0: # Король (б'є на 1 клітинку довкола)
			return abs(dx) <= 1 and abs(dy) <= 1
			
		1: # Ферзь (лінії + діагоналі)
			if abs(dx) == abs(dy) or dx == 0 or dy == 0:
				return pathIsClear(target_v, target_h)
			return false
			
		2: # Слон (тільки діагоналі)
			if abs(dx) == abs(dy):
				return pathIsClear(target_v, target_h)
			return false
			
		3: # Кінь (Г-подібно) - йому байдуже на перешкоди
			return (abs(dx) == 1 and abs(dy) == 2) or (abs(dx) == 2 and abs(dy) == 1)
			
		4: # Ладья (тільки прямі лінії)
			if dx == 0 or dy == 0:
				return pathIsClear(target_v, target_h)
			return false
			
		5: # Пішак
			var direction = 1 if color == 0 else -1
			
			if dy == direction and abs(dx) == 1:
				return true
			return false
	return false
