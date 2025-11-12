extends Node2D

var main = null

var hp=1
var attack=1
var defence=1

var id=0
var type=0
var horzid=0
var vertid=0
var color=0

func _ready() -> void:
	pass

func init_props(id, tp, c, v, h, main_ref = null):
	self.id=id
	self.type=tp
	self.color=c
	self.main = main_ref
	$Sprite2D.frame=self.type+self.color*6
	placeAtCell(v,h)
	
func placeAtCell(v, h):
	self.horzid=h
	self.vertid=v
	self.position.x = 50+60*self.vertid
	self.position.y = 550-60*self.horzid
	
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
			return abs(dx) <= 1 and abs(dy) <= 1
		1: # Ферзь
			if abs(dx) == abs(dy) or dx == 0 or dy == 0:
				return pathIsClear(v, h)
			return false
		2: # Слон
			if abs(dx) != abs(dy):
				return false
			return pathIsClear(v, h)
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

func canAttack2Pice():
	pass
