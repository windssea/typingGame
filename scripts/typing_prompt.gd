class_name TypingPrompt
extends RefCounted

const FONT = preload("res://assets/ui-heading.ttf")
static var measurements: Dictionary = {}

# One measured layout serves the fixed input dock and every world-space label.
# Text never inherits camera shake, hit squash or a particle transform.
static func measure(word: String, maximum: float, preferred := 34, minimum := 25) -> Dictionary:
	var key := str([word,maximum,preferred,minimum])
	if measurements.has(key):
		return measurements[key]
	var font_size := preferred
	while font_size>minimum and FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>maximum-32:
		font_size -= 1
	var rows: Array[Dictionary] = []
	var start := 0
	var widest := 0.0
	while start<word.length():
		var end := start+1
		while end<word.length() and FONT.get_string_size(word.substr(start,end-start+1),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=maximum-32:
			end += 1
		if end<word.length():
			var space := word.rfind(" ",end-1)
			if space>start:
				end = space+1
		var value := word.substr(start,end-start)
		var width := FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		rows.append({"text":value,"start":start,"width":width})
		widest = maxf(widest,width)
		start = end
	var line_height := ceilf(font_size*1.3)
	var result := {"font":font_size,"rows":rows,"line_height":line_height,"size":Vector2(maxf(64,widest+32),rows.size()*line_height+16)}
	if measurements.size()>=512:
		measurements.erase(measurements.keys()[0])
	measurements[key] = result
	return result

static func paint(canvas: CanvasItem, word: String, typed: int, rect: Rect2, layout: Dictionary, active: bool, error := false, centered := true) -> void:
	var font_size: int = layout.font
	for i in range(layout.rows.size()):
		var row: Dictionary = layout.rows[i]
		var point := rect.position+Vector2((rect.size.x-row.width)*.5 if centered else 16,8+font_size+i*layout.line_height)
		var count := clampi(typed-int(row.start),0,str(row.text).length())
		var prefix := FONT.get_string_size(str(row.text).substr(0,count),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var next_width := FONT.get_string_size(str(row.text).substr(count,1),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var current: bool = active and typed>=int(row.start) and typed<int(row.start)+str(row.text).length()
		if current:
			var key_rect := Rect2(point+Vector2(prefix-2,-font_size+2),Vector2(maxf(13,next_width)+4,font_size+7))
			canvas.draw_style_box(PlayTheme.surface(Color("ffe093") if not error else Color("ffc5b5"),Color.TRANSPARENT,5),key_rect)
		canvas.draw_string(FONT,point,row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,PlayTheme.TEXT)
		if count>0:
			canvas.draw_string(FONT,point,str(row.text).substr(0,count),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("147c72"))
		if current:
			canvas.draw_line(point+Vector2(prefix,7),point+Vector2(prefix+maxf(13,next_width),7),Color("a76613") if not error else Color("ae4138"),3,true)
			if word.substr(typed,1)==" ":
				canvas.draw_line(point+Vector2(prefix+3,0),point+Vector2(prefix+maxf(13,next_width)-3,0),PlayTheme.TEXT,2,true)

static func place(preferred_center: Vector2, extent: Vector2, bounds: Rect2, occupied: Array[Rect2], actors: Array[Rect2], previous := Vector2.ZERO) -> Rect2:
	var base := preferred_center-extent*.5
	var best := Rect2(base,extent)
	var best_score := INF
	var offsets: Array[Vector2] = [previous,Vector2.ZERO]
	for dy in [0.0,-extent.y-12,extent.y+12,-2*(extent.y+12),2*(extent.y+12),-3*(extent.y+12),3*(extent.y+12)]:
		for dx in [0.0,-extent.x-14,extent.x+14,-extent.x*.5,extent.x*.5]:
			offsets.append(Vector2(dx,dy))
	for shift in offsets:
		var rect := Rect2((base+shift).clamp(bounds.position,bounds.end-extent),extent)
		var score := rect.position.distance_squared_to(base)*.002
		for blocked in occupied:
			if rect.grow(6).intersects(blocked):
				score += rect.grow(6).intersection(blocked).get_area()*80+10000
		for actor in actors:
			if rect.grow(3).intersects(actor):
				score += rect.grow(3).intersection(actor).get_area()*4+1000
		if score<best_score:
			best = rect
			best_score = score
		if score<.001:
			break
	# Dense encounters may have no free local slot: try the open field before
	# accepting an overlap, while keeping the selected target's first choice.
	if best_score>=10000:
		var y := bounds.position.y
		while y+extent.y<=bounds.end.y:
			for x in [bounds.position.x,bounds.get_center().x-extent.x*.5,bounds.end.x-extent.x]:
				var rect := Rect2(Vector2(x,y),extent)
				var score := rect.position.distance_squared_to(base)*.002
				for blocked in occupied:
					if rect.grow(6).intersects(blocked):
						score += rect.grow(6).intersection(blocked).get_area()*80+10000
				for actor in actors:
					if rect.grow(3).intersects(actor):
						score += rect.grow(3).intersection(actor).get_area()*4+1000
				if score<best_score:
					best = rect
					best_score = score
			y += extent.y+12
	return best
