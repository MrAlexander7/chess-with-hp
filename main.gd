extends Node2D
var pieces=[]

var activePiece=null

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
	if event is InputEventMouseButton:
		if event.pressed:
			#знайти фігуру, на яку натиснули
			if activePiece==null:
				var p = findPieceAtCoords(event.position.x,event.position.y)
				if p!=null:
					#removePiece(p)
					activatePiece(p)
			else:
				var cellCoord = findCellAtCoords(event.position.x,event.position.y)
				print(cellCoord)
				#перевірити координати та можлисть здіснювати ходи
				if activePiece.canMove2Cell(cellCoord.x, cellCoord.y):
					activePiece.placeAtCell(cellCoord.x, cellCoord.y)

func activatePiece(p):
	activePiece=p

func findCellAtCoords(cx, cy):
	#v = (cx-50)//60
	#cy-550 = -60*h
	var v = (cx-50)/60
	var h = (550-cy)/60
	return Vector2(round(v),round(h))
	
	
func findPieceAtCoords(cx, cy):
	var res = null
	
	for p in pieces:
		var dx = cx-p.position.x
		var dy = cy-p.position.y
		if abs(dx)<25 and abs(dy)<25:
			res=p;
			break
	
	return res

func createPiece(tp, cl, v, h):
	var p = preload("res://piece.tscn").instantiate()
	p.init_props(0, tp, cl, v, h)
	add_child(p)
	pieces.append(p)
	
func removePiece(p):
	p.queue_free()
	pieces.erase(p)
