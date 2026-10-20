class_name SoftStroke
extends RefCounted

static func line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width := 2.0) -> void:
	canvas.draw_line(a,b,color,width,true)
	canvas.draw_circle(a,width*.5,color,true,-1,true)
	canvas.draw_circle(b,width*.5,color,true,-1,true)

static func arc(canvas: CanvasItem, center: Vector2, radius: float, start: float, end: float, color: Color, width := 2.0) -> void:
	if absf(end-start)<.005 or radius<1:
		return
	var points := PackedVector2Array()
	var count := maxi(24,ceili(absf(end-start)*radius/3))
	for i in range(count+1):
		points.append(center+Vector2.from_angle(lerpf(start,end,float(i)/count))*radius)
	canvas.draw_polyline(points,color,width,true)
	canvas.draw_circle(points[0],width*.5,color,true,-1,true)
	canvas.draw_circle(points[-1],width*.5,color,true,-1,true)
