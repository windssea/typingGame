class_name GeneratedArt
extends RefCounted

# Each arena owns its resources. No image decoding or texture lookup in _draw().
var background: Texture2D
var sprites: Dictionary = {}
static var pending: Dictionary = {}
const POLISHED := {"tower_fire":"tower-fire","tower_ice":"tower-ice","tower_storm":"tower-storm","keep":"castle-keep","pad":"tower-pad"}

static func warm_props(mode: String) -> void:
	if ContentPackLoader.enabled(): return
	if mode!="castle": return
	for filename in POLISHED.values():
		var path: String="res://assets/generated/v17/"+filename+".png"
		if ResourceLoader.exists(path) and not pending.has(path):
			if ResourceLoader.load_threaded_request(path)==OK: pending[path]=true

static func load_texture(path: String) -> Texture2D:
	if pending.has(path):
		pending.erase(path)
		return ResourceLoader.load_threaded_get(path)
	return load(path)

static func background_path(mode: String) -> String:
	if mode=="rain": return "res://assets/generated/v20/rain-background.png"
	if mode in ["royal","submarine","restaurant","sprint"]: return "res://assets/generated/v18/"+mode+"-background.png"
	if mode=="castle": return "res://assets/generated/v17/castle-field.png"
	var filename := "balloons-background-v2" if mode == "balloons" else mode+"-background"
	if mode=="dojo":
		filename = "skybridge-background-v13"
	return "res://assets/generated/"+filename+".png"

func setup(mode: String) -> void:
	background = load_texture(background_path(mode))
	if mode in AdventureRun.MODES:
		for id in {"royal":["knight","goblin"],"submarine":["sub"],"restaurant":["chef"]}[mode]:
			sprites[id] = load_texture("res://assets/generated/v18/"+id+".png")
		if mode=="restaurant":
			sprites.dessert=load_texture("res://assets/generated/v22/comfort-tart.png")
			var kitchen: Texture2D=load_texture("res://assets/generated/v20/kitchen-props.png")
			for row in range(3):
				for col in range(3):
					var prop:=AtlasTexture.new();prop.atlas=kitchen
					prop.region=Rect2(Vector2(col,row)*kitchen.get_size()/3,kitchen.get_size()/3)
					prop.filter_clip=true;sprites["prep%d_%d"%[row,col]]=prop
			for prefix in ["food","customer"]:
				for i in range(3): sprites[prefix+str(i)]=load_texture("res://assets/generated/v18/"+prefix+str(i)+".png")
		return
	var family := "castle" if mode == "castle" else ("arcade" if mode in ArcadeRun.MODES else "learning")
	var atlas_path := "res://assets/generated/"+family+"-sprites.png"
	if family=="learning":
		atlas_path = "res://assets/generated/learning-sprites-v10.png"
	if not ResourceLoader.exists(atlas_path) or not FileAccess.file_exists("res://assets/generated/regions.json"):
		return
	var atlas: Texture2D = load(atlas_path)
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/regions.json"))
	if not regions.has(family):
		return
	for id in regions[family]:
		var coords: Array = regions[family][id]
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(coords[0],coords[1],coords[2],coords[3])
		texture.filter_clip = true
		sprites[id] = texture
	if mode=="rain":
		var head:=AtlasTexture.new();head.atlas=atlas
		head.region=Rect2(676,168,328,308);head.filter_clip=true
		sprites.meteor_head=head
	if mode=="castle":
		for id in POLISHED:
			sprites[id] = GeneratedArt.load_texture("res://assets/generated/v17/"+POLISHED[id]+".png")
	if mode=="rain": sprites.cannon=load_texture("res://assets/generated/v18/cannon.png")

func draw_sprite(canvas: CanvasItem, id: String, center: Vector2, bounds: Vector2, tint := Color.WHITE) -> void:
	if not sprites.has(id):
		return
	var texture: Texture2D = sprites[id]
	var dimensions := texture.get_size()
	var fitted := dimensions*minf(bounds.x/dimensions.x,bounds.y/dimensions.y)
	canvas.draw_texture_rect(texture,Rect2(center-fitted/2,fitted),false,tint)

func draw_grounded(canvas: CanvasItem, id: String, foot: Vector2, bounds: Vector2, stretch := Vector2.ONE, tint := Color.WHITE) -> void:
	if not sprites.has(id): return
	var image: Texture2D = sprites[id]
	var fitted: Vector2 = image.get_size()*minf(bounds.x/image.get_width(),bounds.y/image.get_height())*stretch
	var anchor:=Vector2(.5,.975 if id.begins_with("tower_") else .96875 if id=="keep" else .9375)
	canvas.draw_texture_rect(image,Rect2(foot-fitted*anchor,fitted),false,tint)
