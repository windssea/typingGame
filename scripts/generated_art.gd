class_name GeneratedArt
extends RefCounted

# Each arena owns its resources. No image decoding or texture lookup in _draw().
var background: Texture2D
var sprites: Dictionary = {}

func setup(mode: String) -> void:
	var filename := "balloons-background-v2" if mode == "balloons" else mode+"-background"
	background = load("res://assets/generated/"+filename+".png")
	var family := "castle" if mode == "castle" else ("arcade" if mode in ArcadeRun.MODES else "learning")
	var atlas_path := "res://assets/generated/"+family+"-sprites.png"
	if not ResourceLoader.exists(atlas_path) or not FileAccess.file_exists("res://assets/generated/regions.json"):
		return
	var atlas: Texture2D = load(atlas_path)
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/regions.json"))
	for id in regions[family]:
		var coords: Array = regions[family][id]
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(coords[0],coords[1],coords[2],coords[3])
		texture.filter_clip = true
		sprites[id] = texture

func draw_sprite(canvas: CanvasItem, id: String, center: Vector2, bounds: Vector2, tint := Color.WHITE) -> void:
	if not sprites.has(id):
		return
	var texture: Texture2D = sprites[id]
	var dimensions := texture.get_size()
	var fitted := dimensions*minf(bounds.x/dimensions.x,bounds.y/dimensions.y)
	canvas.draw_texture_rect(texture,Rect2(center-fitted/2,fitted),false,tint)
