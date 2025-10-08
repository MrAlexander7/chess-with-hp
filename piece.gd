extends Node2D

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


func init_props(id, tp, c, v, h):
	self.id=id
	self.type=tp
	self.color=c
	$Sprite2D.frame=self.type+self.color*6
	placeAtCell(v,h)
	
func placeAtCell(v, h):
	self.horzid=h
	self.vertid=v
	self.position.x = 50+60*self.vertid
	self.position.y = 550-60*self.horzid
	
func canMove2Cell(v,h):
	
	
	
	if v < 0 or v > 7 or h < 0 or h > 7:
		return false
	
	return true
	
	
