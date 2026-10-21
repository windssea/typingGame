class_name GameGlyph
extends RefCounted

# Code-native symbols share rounded strokes and remain crisp at any canvas scale.
static func draw(canvas: CanvasItem, kind: String, at: Vector2, radius: float, tint: Color) -> void:
	if radius<.25:
		return
	var stroke := maxf(2,radius*.16)
	match kind:
		"star", "score", "challenge":
			var points := PackedVector2Array()
			for i in range(10):
				points.append(at+Vector2.from_angle(-PI/2+i*PI/5)*radius*(1 if i%2==0 else .46))
			canvas.draw_colored_polygon(points,tint)
			canvas.draw_line(at+Vector2(-radius*.2,-radius*.35),at+Vector2(-radius*.05,-radius*.6),tint.lightened(.6),stroke,true)
		"health", "accuracy":
			var points := PackedVector2Array([at+Vector2(-.75,-.7)*radius,at+Vector2(.75,-.7)*radius,at+Vector2(.62,.35)*radius,at+Vector2(0,1)*radius,at+Vector2(-.62,.35)*radius,at+Vector2(-.75,-.7)*radius])
			canvas.draw_polyline(points,tint,stroke,true)
			if kind=="accuracy":
				canvas.draw_polyline(PackedVector2Array([at+Vector2(-.34,0)*radius,at+Vector2(-.06,.28)*radius,at+Vector2(.38,-.27)*radius]),tint,stroke,true)
			else:
				canvas.draw_line(at-Vector2(radius*.3,0),at+Vector2(radius*.3,0),tint,stroke,true)
				canvas.draw_line(at-Vector2(0,radius*.3),at+Vector2(0,radius*.3),tint,stroke,true)
		"combo", "skill":
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(.12,-1)*radius,at+Vector2(-.65,.12)*radius,at+Vector2(-.05,.12)*radius,at+Vector2(-.2,1)*radius,at+Vector2(.72,-.25)*radius,at+Vector2(.15,-.25)*radius]),tint)
		"speed":
			canvas.draw_arc(at+Vector2(0,radius*.3),radius,PI,TAU,24,tint,stroke,true)
			canvas.draw_line(at+Vector2(0,radius*.3),at+Vector2(.6,-.5)*radius,tint,stroke,true)
			canvas.draw_circle(at+Vector2(0,radius*.3),stroke,tint)
		"book":
			for side in [-1,1]:
				canvas.draw_polyline(PackedVector2Array([at+Vector2(0,-.65)*radius,at+Vector2(side*.8,-.9)*radius,at+Vector2(side*.8,.7)*radius,at+Vector2(0,.95)*radius,at+Vector2(0,-.65)*radius]),tint,stroke,true)
		"key", "training":
			var rect := Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2)
			canvas.draw_style_box(PlayTheme.game_panel(tint.lightened(.75),tint,6,3),rect)
			canvas.draw_line(at+Vector2(-.4,.15)*radius,at+Vector2(-.4,.45)*radius,tint,stroke,true)
			canvas.draw_line(at+Vector2(-.4,.45)*radius,at+Vector2(.4,.45)*radius,tint,stroke,true)
		"sound":
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-.8,-.3)*radius,at+Vector2(-.3,-.3)*radius,at+Vector2(.2,-.75)*radius,at+Vector2(.2,.75)*radius,at+Vector2(-.3,.3)*radius,at+Vector2(-.8,.3)*radius]),tint)
			canvas.draw_arc(at+Vector2(.15,0)*radius,radius*.7,-1,1,16,tint,stroke,true)
		"pause":
			for x in [-.35,.35]:
				canvas.draw_line(at+Vector2(x,-.7)*radius,at+Vector2(x,.7)*radius,tint,stroke*2,true)
		_:
			canvas.draw_circle(at,radius*.75,tint)
