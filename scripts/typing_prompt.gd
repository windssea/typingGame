class_name TypingPrompt
extends RefCounted

const FONT = preload("res://assets/ui-heading.ttf")
const PLAQUE = preload("res://assets/generated/v20/ui-word-plaque.png")
const THEMES = preload("res://assets/generated/v20/ui-themed-plaques.png")
const THEME_INDEX := {"castle":0,"royal":0,"dojo":0,"rain":1,"aliens":1,"bubbles":2,"submarine":2,"balloons":3,"moles":4,"racing":5,"fighter":6,"restaurant":7,"sprint":8}
const THEME_REGIONS := [Rect2(14,239,401,143),Rect2(433,237,388,146),Rect2(842,240,397,142),Rect2(16,552,394,141),Rect2(426,551,402,143),Rect2(841,552,398,141),Rect2(14,865,396,139),Rect2(430,867,394,138),Rect2(841,866,398,139)]
const KEYCAP = preload("res://assets/generated/v20/ui-keycap.png")
static var measurements: Dictionary = {}
static var ink_measurements: Dictionary = {}
const MIN_CARD_WIDTH := 184.0
const MIN_CARD_HEIGHT := 88.0
const CARD_PADDING := 24.0

# Source-space slices and destination-space bevels are separate: a one-letter
# key keeps the same slim edge as a long phrase, without stretching the corners.
static func material_frame(canvas: CanvasItem, rect: Rect2, keycap := false, active := true, error := false, phase := 0.0, theme := "") -> void:
	var texture: Texture2D = KEYCAP if keycap else PLAQUE
	var source := Rect2(38,45,1186,1165) if keycap else Rect2(0,88,2172,492)
	var themed := not keycap and THEME_INDEX.has(theme)
	if themed:
		texture = THEMES
		source = THEME_REGIONS[THEME_INDEX[theme]]
	var x_margin := 180 if keycap else 38 if themed else 156
	var top_margin := 180 if keycap else 23 if themed else 82
	var bottom_margin := 210 if keycap else 22 if themed else 70
	var sx := [source.position.x,source.position.x+x_margin,source.end.x-x_margin,source.end.x]
	var sy := [source.position.y,source.position.y+top_margin,source.end.y-bottom_margin,source.end.y]
	var edge := minf(14.0 if keycap else 12.0,minf(rect.size.x,rect.size.y)*.22)
	var dx := [rect.position.x,rect.position.x+edge,rect.end.x-edge,rect.end.x]
	var dy := [rect.position.y,rect.position.y+edge,rect.end.y-edge,rect.end.y]
	var tint := Color.WHITE if active else Color(.69,.84,.89,.96)
	if error: tint = Color(1,.64,.58)
	# An opaque enamel/wood/paper undercoat keeps world lighting from leaking
	# through the atlas alpha into the text. The painted material stays above it.
	var undercoat := Color("fff0ce") if keycap or theme=="restaurant" else Color("167a90") if theme in ["balloons","submarine","bubbles","sprint"] else Color("244252")
	canvas.draw_rect(rect.grow(-4),undercoat)
	for y in range(3):
		for x in range(3):
			canvas.draw_texture_rect_region(texture,Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y]),Rect2(sx[x],sy[y],sx[x+1]-sx[x],sy[y+1]-sy[y]),tint)
	if active and not keycap:
		# Animated glint stays on the bevel, never over a letter's strokes.
		var travel := fposmod(phase*.16,1.0)
		var start := rect.position+Vector2(edge+travel*maxf(1,rect.size.x-edge*2-18),3)
		canvas.draw_line(start,start+Vector2(18,0),Color(1,.95,.7,.42),1.5,true)

static func glyph(canvas: CanvasItem, value: String, baseline: Vector2, font_size: int, tint: Color, glow := 0.0, dark := false) -> void:
	var ink := Color("19364c")
	if glow>0:
		canvas.draw_string_outline(FONT,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,5,Color(1,.77,.3,glow*.16))
	canvas.draw_string_outline(FONT,baseline+Vector2(0,2),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color(.025,.12,.20,.8 if not dark else .22))
	canvas.draw_string_outline(FONT,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2 if not dark else 1,ink if not dark else Color("fff5d1"))
	canvas.draw_string(FONT,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

static func key(canvas: CanvasItem, rect: Rect2, value: String, font_size: int, active := true, error := false, phase := 0.0) -> void:
	material_frame(canvas,rect,true,active,error,phase)
	var layout:=key_layout(rect,value,font_size)
	glyph(canvas,value,layout.baseline,layout.font,Color("18384f") if active else Color("355365"),0,true)

# Font ascent/descent describes an entire line, not the visible letter. In a
# CJK-capable font that left a, c and punctuation sitting on the key's bottom lip.
static func ink_bounds(value: String, font_size: int) -> Rect2:
	var cache_key:=str([value,font_size])
	if ink_measurements.has(cache_key): return ink_measurements[cache_key]
	var server:=TextServerManager.get_primary_interface()
	var bounds:=Rect2()
	var visible:=false
	for i in range(value.length()):
		var pen:=FONT.get_string_size(value.substr(0,i),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		for rid in FONT.get_rids():
			var index:=server.font_get_glyph_index(rid,font_size,value.unicode_at(i),0)
			if index==0: continue
			var extent:=server.font_get_glyph_size(rid,Vector2i(font_size,0),index)
			if extent.x>0 and extent.y>0:
				var region:=Rect2(Vector2(pen,0)+server.font_get_glyph_offset(rid,Vector2i(font_size,0),index),extent)
				bounds=bounds.merge(region) if visible else region
				visible=true
			break
	if not visible: bounds=Rect2(Vector2(0,-font_size*.5),Vector2(FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,font_size))
	if ink_measurements.size()>=512: ink_measurements.erase(ink_measurements.keys()[0])
	ink_measurements[cache_key]=bounds
	return bounds

static func key_layout(rect: Rect2, value: String, preferred: int) -> Dictionary:
	var font_size:=preferred
	var bounds:=ink_bounds(value,font_size)
	while font_size>12 and (bounds.size.x>rect.size.x-20 or bounds.size.y>rect.size.y-18):
		font_size-=1;bounds=ink_bounds(value,font_size)
	# Exclude the four-pixel cyan base from the raised cream face.
	var face:=Rect2(rect.position,rect.size-Vector2(0,4))
	return {"font":font_size,"baseline":face.get_center()-bounds.get_center(),"ink":bounds,"face":face}

# One measured layout serves the fixed input dock and every world-space label.
# Text never inherits camera shake, hit squash or a particle transform.
static func measure(word: String, maximum: float, preferred := 34, minimum := 25) -> Dictionary:
	var key := str([word,maximum,preferred,minimum])
	if measurements.has(key):
		return measurements[key]
	var font_size := preferred
	while font_size>minimum and FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>maximum-CARD_PADDING*2:
		font_size -= 1
	var rows: Array[Dictionary] = []
	var start := 0
	var widest := 0.0
	while start<word.length():
		var end := start+1
		while end<word.length() and FONT.get_string_size(word.substr(start,end-start+1),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=maximum-CARD_PADDING*2:
			end += 1
		if end<word.length():
			var space := word.rfind(" ",end-1)
			if space>start:
				end = space+1
		var value := word.substr(start,end-start)
		var width := FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		rows.append({"text":value,"start":start,"width":width,"ink":ink_bounds(value,font_size)})
		widest = maxf(widest,width)
		start = end
	var line_height := ceilf(font_size*1.3)
	var ink:=Rect2()
	for i in range(rows.size()):
		var row_ink: Rect2=rows[i].ink
		row_ink.position.y+=i*line_height
		ink=ink.merge(row_ink) if i>0 else row_ink
	# Short combinations must remain horizontal plaques, even for narrow glyphs
	# such as jf / ill. Size comes from the font scale, never selection or input.
	var floor_width:=minf(maximum,maxf(MIN_CARD_WIDTH,font_size*3.2))
	var result := {"font":font_size,"rows":rows,"line_height":line_height,"ink":ink,"size":Vector2(maxf(floor_width,widest+CARD_PADDING*2),maxf(MIN_CARD_HEIGHT,rows.size()*line_height+24))}
	if measurements.size()>=512:
		measurements.erase(measurements.keys()[0])
	measurements[key] = result
	return result

static func paint(canvas: CanvasItem, word: String, typed: int, rect: Rect2, layout: Dictionary, active: bool, error := false, centered := true, phase := 0.0, pulse := 0.0, reduced := false, theme := "") -> void:
	material_frame(canvas,rect,false,active,error,0.0 if reduced else phase,theme)
	var light := theme in ["balloons","restaurant","sprint"]
	var font_size: int = layout.font
	var breath := .5 if reduced else .5+.5*sin(phase*3.4)
	for i in range(layout.rows.size()):
		var row: Dictionary = layout.rows[i]
		var row_ink: Rect2=row.ink
		var total_ink: Rect2=layout.ink
		var point := rect.position+Vector2(rect.size.x*.5-row_ink.get_center().x if centered else CARD_PADDING,(rect.size.y-total_ink.size.y)*.5-total_ink.position.y+i*layout.line_height)
		var count := clampi(typed-int(row.start),0,str(row.text).length())
		var prefix := FONT.get_string_size(str(row.text).substr(0,count),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var next_width := FONT.get_string_size(str(row.text).substr(count,1),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var current: bool = active and typed>=int(row.start) and typed<int(row.start)+str(row.text).length()
		var character:=str(row.text).substr(count,1)
		var character_ink:=ink_bounds(character,font_size)
		if character==" ": character_ink=Rect2(Vector2(0,-font_size*.45),Vector2(maxf(13,next_width),font_size*.55))
		if current:
			var key_rect:=Rect2(point+Vector2(prefix,0)+character_ink.position-Vector2(7,8),character_ink.size+Vector2(14,20))
			material_frame(canvas,key_rect,true,true,error,phase)
		glyph(canvas,row.text,point,font_size,(Color("17394e") if active else Color("355363")) if light else (Color("f5eedb") if active else Color("d3e3e7")),0,light)
		if count>0:
			glyph(canvas,str(row.text).substr(0,count),point,font_size,Color("126d60") if light else Color("8cf4ce"),minf(1,pulse*5),light)
		if current:
			glyph(canvas,character,point+Vector2(prefix,0),font_size,Color("81362e") if error else Color("17384e"),.3+breath*.5,true)
			var underline := Color("ff9683") if error else Color("ffdf89")
			underline.a = .7+breath*.3
			var underline_y:=character_ink.end.y+6
			canvas.draw_line(point+Vector2(prefix,underline_y),point+Vector2(prefix+maxf(13,next_width),underline_y),underline,2,true)
			if word.substr(typed,1)==" ":
				var bar_y:=character_ink.get_center().y
				canvas.draw_line(point+Vector2(prefix+3,bar_y),point+Vector2(prefix+maxf(13,next_width)-3,bar_y),Color("17384e"),2,true)

static func place(preferred_center: Vector2, extent: Vector2, bounds: Rect2, occupied: Array[Rect2], actors: Array[Rect2], previous := Vector2.ZERO) -> Rect2:
	var base := preferred_center-extent*.5
	var best := Rect2(base,extent)
	var best_score := INF
	var previous_position := base+previous
	var offsets: Array[Vector2] = [previous,Vector2.ZERO]
	# Small clearances must be considered before moving a whole label height.
	# A two-pixel actor overlap should not detach its word by a hundred pixels.
	for dy in [0.0,-12.0,12.0,-24.0,24.0,-40.0,40.0,-extent.y-12,extent.y+12,-2*(extent.y+12),2*(extent.y+12),-3*(extent.y+12),3*(extent.y+12)]:
		for dx in [0.0,-extent.x-14,extent.x+14,-extent.x*.5,extent.x*.5]:
			offsets.append(Vector2(dx,dy))
	for shift in offsets:
		var rect := Rect2((base+shift).clamp(bounds.position,bounds.end-extent),extent)
		var score := rect.position.distance_squared_to(base)*.0002+rect.position.distance_squared_to(previous_position)*.05
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
				var score := rect.position.distance_squared_to(base)*.0002+rect.position.distance_squared_to(previous_position)*.05
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
